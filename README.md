# Kimi RealmRouter Configurator (macOS)

一键把已经安装好的 Kimi CLI 配置到 RealmRouter：

- Base URL: `https://realmrouter.cn/v1`
- Model: `moonshotai/Kimi-K2.5`
- Protocol: `openai_responses`

## 使用方法

### 远程一行命令

```bash
curl -fsSL https://raw.githubusercontent.com/hailin998/kimi-realmrouter-config/main/config_kimi_realmrouter.sh | bash
```

运行后终端会提示输入你的 RealmRouter API key，输入回车即可。

### 本地执行

```bash
bash config_kimi_realmrouter.sh
```

## 说明

- 脚本不会安装 Kimi CLI，只负责配置
- API key 会保存到 macOS Keychain，不会明文写进 `~/.kimi/config.toml`
- 配置完成后，重新打开终端执行 `KIMI` 即可
