# dsh-linux-packages

DeepSeek Harness (`dsh`) 桌面端的 Linux 安装包 —— **非官方**，由 `boyunxi` 自行构建。

包体较大（300+ MiB），放在 [Releases](../../releases) 里；仓库本身只放文档和构建脚本。

## 已有包

| 版本 | 格式 | 架构 | 文件 | 大小 | SHA256 |
| --- | --- | --- | --- | --- | --- |
| `0.2.1-alpha.1` | deb | amd64 | `deepseek-harness-0.2.1-alpha.1-linux-amd64.deb` | 328,905,732 B (313 MiB) | `eb382cf7dbbb9024ef1770d522846ab75124c5ce86d4afd4a38103a9d3065069` |
| `0.2.1alpha1-1` | pacman | x86_64 | `deepseek-harness-desktop-0.2.1alpha1-1-x86_64.pkg.tar.zst` | 399,870,321 B (381 MiB) | `cd6a8f64feaf40c25d0d13815723cc98037e2159c9c33a8de97ea199b87abfaa` |

pacman 包在 [dsh-arch-desktop](https://github.com/boyunxi/dsh-arch-desktop)（自建 pacman 仓库，
`Server = https://github.com/boyunxi/dsh-arch-desktop/releases/download/arch`）。

## 来源

由 [deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 源码构建：

```
version    0.2.1-alpha.1
commit     b35ba696b20015c212189243bbf18333d5530449
dirty      false
node       24.18.1（Electron 内嵌）
electron   44.0.0
```

上游**没有** Linux 打包目标，Linux 支持是同仓库的 `feat(desktop): add Linux x64/arm64
packaging targets` 加出来的。踩过的坑（sharp 要按 Electron 头文件重建、policy 键不能在
manifest 里出现、`desktop.entry` 不能写成回调……）记在源码仓库的
`docs/linux-desktop-dev-notes.md`。

## 安装

### Debian / Ubuntu

```sh
sudo apt install ./deepseek-harness-0.2.1-alpha.1-linux-amd64.deb
```

安装到 `/opt/DeepSeek Harness/`（productName 目录，**带空格**），约 1.17 GiB。

`chrome-sandbox` 的 setuid 位由 `postinst` 决定：内核支持非特权 user namespace 就用
`0755`，否则 `4755`。所以正常情况下**不需要** `--no-sandbox`。

### Arch Linux

```sh
sudo pacman -U deepseek-harness-desktop-0.2.1alpha1-1-x86_64.pkg.tar.zst
```

安装到 `/opt/deepseek-harness-desktop/`。

> ⚠️ deb 和 pacman 包装的是**两个不同目录**，所以会共存，但那是两份 1.17 GiB。
> 同一台机器只装一个。

## 构建

见 [scripts/build-deb.sh](scripts/build-deb.sh) 与源码仓库的
`docs/linux-desktop-dev-notes.md` 第八节。要点：

```sh
cd <deepseek-harness>/apps/desktop
env -u ELECTRON_RUN_AS_NODE -u CODEBUDDY_SAFE_DELETE_BULK_STATE_DIR \
    -u CODEBUDDY_TOOL_CALL_ID -u CODEBUDDY_SAFE_DELETE_ENABLED \
  PATH="$HOME/.local/bin:$PATH" \
  sh -c 'set -a; . ./.env.linux; set +a;
    DSH_DESKTOP_TARGET_PLATFORM=linux DSH_DESKTOP_TARGET_ARCH=x64 \
    ./node_modules/.bin/electron-builder --config electron-builder.config.mjs \
      --linux deb --x64 --publish never \
      --config.linux.icon=resources/icon.png \
      --config.extraMetadata.homepage=https://github.com/deepseek-ai/deepseek-harness'
```

三个前提：`. ./.env.linux`（否则 `DSH_DESKTOP_APP_ID` 缺失）、PATH 里要有 `pnpm`、
Arch 上还要 `sudo pacman -S libxcrypt-compat`（fpm 的 ruby 要 `libcrypt.so.1`）。

只出 deb，不出 rpm —— `linux.target` 里的 `rpm` 需要 `rpmbuild`。

## 说明

- 包未签名，也没有经过发行版审核。自己用没问题，别当官方渠道。
- deb 里带 `resources/app-update.yml`，指向 `example.invalid`（构建时的测试占位 origin）。
  内置的 `electron-updater` 会去查更新并失败，不影响使用。想要彻底干净可以解包删掉该文件。
- 上游是 **alpha** 版本，行为可能随版本变化。
