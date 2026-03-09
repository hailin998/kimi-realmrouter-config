param(
    [string]$ApiKey = ''
)

# Configure an existing Kimi CLI installation to use RealmRouter on Windows.
# This script does NOT install Kimi CLI. It only configures it.
#
# Usage (PowerShell):
#   $env:REALMROUTER_API_KEY='sk-xxx'; irm https://raw.githubusercontent.com/hailin998/kimi-realmrouter-config/main/config_kimi_realmrouter.ps1 | iex
# or download then run:
#   powershell -ExecutionPolicy Bypass -File .\config_kimi_realmrouter.ps1 -ApiKey 'sk-xxx'

$ErrorActionPreference = 'Stop'

$modelName = 'moonshotai/Kimi-K2.5'
$baseUrl = 'https://realmrouter.cn/v1'
$providerName = 'realmrouter'
$providerType = 'openai_responses'
$configDir = Join-Path $HOME '.kimi'
$configFile = Join-Path $configDir 'config.toml'
$launcherDir = Join-Path $HOME '.kimi'
$launcherPath = Join-Path $launcherDir 'kimi-rr.ps1'
$cmdShimPath = Join-Path $launcherDir 'kimi-rr.cmd'
$envName = 'KIMI_REALMROUTER_API_KEY'

function Test-KimiInstalled {
    $cmd = Get-Command KIMI -ErrorAction SilentlyContinue
    if ($cmd) { return $true }

    $commonPaths = @(
        (Join-Path $HOME '.local\bin\KIMI.exe'),
        (Join-Path $HOME '.local\bin\KIMI'),
        (Join-Path $HOME 'AppData\Local\Programs\Kimi\KIMI.exe')
    )

    foreach ($p in $commonPaths) {
        if (Test-Path $p) { return $true }
    }

    return $false
}

function Get-KimiCommand {
    $cmd = Get-Command KIMI -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $commonPaths = @(
        (Join-Path $HOME '.local\bin\KIMI.exe'),
        (Join-Path $HOME '.local\bin\KIMI'),
        (Join-Path $HOME 'AppData\Local\Programs\Kimi\KIMI.exe')
    )

    foreach ($p in $commonPaths) {
        if (Test-Path $p) { return $p }
    }

    throw 'Kimi CLI is not installed. Please install Kimi CLI first, then run this script again.'
}

if (-not (Test-KimiInstalled)) {
    throw 'Kimi CLI is not installed. Please install Kimi CLI first, then run this script again.'
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = [System.Environment]::GetEnvironmentVariable('REALMROUTER_API_KEY', 'Process')
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = [System.Environment]::GetEnvironmentVariable('REALMROUTER_API_KEY', 'User')
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = [System.Environment]::GetEnvironmentVariable($envName, 'User')
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = Read-Host 'Enter your RealmRouter API key'
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw 'API key cannot be empty.'
}

Write-Host '[1/4] Storing API key in user environment variable...'
[System.Environment]::SetEnvironmentVariable($envName, $ApiKey, 'User')
Set-Item -Path "Env:$envName" -Value $ApiKey

Write-Host '[2/4] Writing ~/.kimi/config.toml ...'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
$config = @"
default_model = "$modelName"
default_thinking = true
default_yolo = false

[models."$modelName"]
provider = "$providerName"
model = "$modelName"
max_context_size = 262144
capabilities = ["video_in", "image_in", "thinking"]

[providers."$providerName"]
type = "$providerType"
base_url = "$baseUrl"
api_key = ""

[models."kimi-code/kimi-for-coding"]
provider = "managed:kimi-code"
model = "kimi-for-coding"
max_context_size = 262144
capabilities = ["video_in", "image_in", "thinking"]

[providers."managed:kimi-code"]
type = "kimi"
base_url = "https://api.kimi.com/coding/v1"
api_key = ""

[providers."managed:kimi-code".oauth]
storage = "file"
key = "oauth/kimi-code"

[loop_control]
max_steps_per_turn = 100
max_retries_per_step = 3
max_ralph_iterations = 0
reserved_context_size = 50000

[services.moonshot_search]
base_url = "https://api.kimi.com/coding/v1/search"
api_key = ""

[services.moonshot_search.oauth]
storage = "file"
key = "oauth/kimi-code"

[services.moonshot_fetch]
base_url = "https://api.kimi.com/coding/v1/fetch"
api_key = ""

[services.moonshot_fetch.oauth]
storage = "file"
key = "oauth/kimi-code"

[mcp.client]
tool_call_timeout_ms = 60000
"@
Set-Content -Path $configFile -Value $config -Encoding UTF8

Write-Host '[3/4] Writing secure launcher...'
New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
$kimiCommand = Get-KimiCommand
$launcher = @"
`$ErrorActionPreference = 'Stop'
`$env:OPENAI_BASE_URL = '$baseUrl'
`$env:OPENAI_API_KEY = [System.Environment]::GetEnvironmentVariable('$envName','User')
if ([string]::IsNullOrWhiteSpace(`$env:OPENAI_API_KEY)) {
    throw 'Missing API key. Re-run config_kimi_realmrouter.ps1 first.'
}
& '$kimiCommand' `$args
"@
Set-Content -Path $launcherPath -Value $launcher -Encoding UTF8

$cmdShim = @"
@echo off
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.kimi\kimi-rr.ps1" %*
"@
Set-Content -Path $cmdShimPath -Value $cmdShim -Encoding ASCII

Write-Host '[4/4] Verifying configuration...'
$env:OPENAI_BASE_URL = $baseUrl
$env:OPENAI_API_KEY = [System.Environment]::GetEnvironmentVariable($envName,'User')
try {
    $output = & $kimiCommand --print --final-message-only -p '回复：配置校验通过' 2>$null
    if ($output -match '配置校验通过') {
        Write-Host 'Success: Kimi CLI has been configured for RealmRouter.'
        Write-Host $output
    } else {
        Write-Host 'Configuration was written, but online verification did not return the expected text.'
        Write-Host 'Please run the launcher manually and inspect the output.'
    }
} catch {
    Write-Host 'Configuration was written, but online verification failed.'
    Write-Host 'Please run the launcher manually and inspect the output.'
}

Write-Host ''
Write-Host 'Done.'
Write-Host 'Launch with:'
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$launcherPath`""
Write-Host 'or:'
Write-Host "  $cmdShimPath"
