# wireguard-ds124

为 **Synology DS124 (ARM64 / RTD1619B, DSM 7.2.2)** 编译的 **WireGuard 内核模块** 及其依赖模块、一键安装脚本和 wg-easy 部署方案。

## 适配环境

| 项目 | 值 |
|---|---|
| NAS 型号 | Synology DS124（单盘位） |
| CPU | Realtek RTD1619B (ARM64 / aarch64) |
| DSM 版本 | 7.2.2-72806 |
| 内核版本 | Linux 5.10.55+ |
| 模块架构 | aarch64 |
| 交叉工具链 | rtd1619b-gcc1220_glibc236_armv8-GPL.txz (7.2-72806) |
| wg-easy | v15.4.0-beta.1（Docker 部署） |

> ⚠️ 仅适用于 DS124（RTD1619B / 内核 5.10.55）！其他机型/内核版本请勿直接 insmod，可能导致内核崩溃。

## 背景

DS124 出厂内核 **不包含 WireGuard 模块**。直接运行 wg-easy 时会出现：

```
Unable to access interface: Protocol not supported   （无内核模块）
Unable to access interface: No such device           （内核模块加载后 ip6tables NAT 缺失）
```

本仓库提供编译好的 `wireguard.ko` 及全部依赖模块，加载后 wg-easy 即可使用**内核态 WireGuard**（而非 wireguard-go 用户态回退），性能更好、更稳定。

## 文件结构

```
wireguard-ds124/
├── README.md                  # 本文档
├── modules/                   # ★ 编译好的内核模块 (.ko)
│   ├── wireguard.ko
│   ├── libblake2s.ko
│   ├── libblake2s-generic.ko
│   ├── libcurve25519.ko
│   ├── libcurve25519-generic.ko
│   ├── libchacha.ko
│   ├── libchacha20poly1305.ko
│   ├── chacha-neon.ko
│   ├── poly1305-neon.ko
│   └── ip6table_nat.ko
├── scripts/
│   ├── install-wireguard-mod.sh  # 一键安装：拷贝内核模块 + 注册开机自启
│   ├── wireguard-start.sh  # 开机自启脚本，增加60s重试3次，解决内核未启动自启脚本无法生效
└── docs/
    └── BUILD.md               # 从零编译的完整步骤
```

## 快速安装（NAS 上执行）

### 1. 上传模块到 NAS

将 `modules/` 里的 `.ko` 文件上传到 NAS 任意目录（如 `/volume1/docker/wireguard-modules/`），
然后 SSH 登录 NAS（root 或 admin + sudo）：

```bash
# 以 root 身份执行
cd /volume1/docker/wireguard-modules
```

### 2. 一键安装

```bash
chmod +x install-wireguard-mod.sh
./install-wireguard-mod.sh
```

脚本会自动：
1. 将全部 `.ko` 拷贝到 `/lib/modules/`
2. 按依赖顺序加载所有模块
3. 写入 `/usr/local/etc/rc.d/wireguard-start.sh`（DSM 开机自启）
4. 输出 `lsmod | grep wireguard` 验证结果

### 3. 验证

```bash
lsmod | grep wireguard
# 应输出类似：
# wireguard              73728  0
# libchacha20poly1305    16384  1 wireguard
# libcurve25519_generic    40960  1 wireguard
# libblake2s             16384  1 wireguard
# ip6table_nat           16384  0
```

## 模块加载顺序（手动方式）

如果不想用脚本，手动按顺序加载：

```bash
cd /lib/modules
insmod libblake2s.ko
insmod libcurve25519.ko
insmod libcurve25519-generic.ko
insmod libchacha.ko
insmod chacha-neon.ko
insmod poly1305-neon.ko
insmod libchacha20poly1305.ko
insmod libblake2s-generic.ko
insmod ip6table_nat.ko
insmod wireguard.ko
```

> ⚠️ 顺序很重要！wireguard 依赖 libchacha20poly1305 / libcurve25519 / libblake2s 等，必须先加载依赖。

## 常见问题

### Q: `insmod wireguard.ko` 报 Unknown symbol
依赖模块没有先加载，按上面的顺序执行。

### Q: `insmod xxx.ko` 报 Invalid module format
模块 vermagic 与当前内核不匹配。本仓库模块 vermagic 为 `5.10.55+ SMP mod_unload aarch64`，
如果 DSM 升级导致内核版本变化，需要重新编译（见 `docs/BUILD.md`）。

### Q: wg-easy 报 `ip6tables: Table does not exist`
缺少 `ip6table_nat.ko`，本仓库已包含，加载后重启 wg-easy 容器即可。

### Q: wg-easy 报 `Unable to access interface: No such device`
wg0 接口被删除了（wg-quick up 失败时自动清理）。检查 iptables 相关模块是否齐全后重启容器。

## 许可证

- WireGuard 源码：GPL v2（作者 Jason A. Donenfeld）
- 本仓库脚本：MIT
- 内核模块来自 Synology 官方开源内核源码 (linux-5.10.x, GPL)

## 参考链接

- [SynoCommunity/spksrc](https://github.com/SynoCommunity/spksrc)
- [wg-easy](https://github.com/wg-easy/wg-easy)
- [WireGuard](https://www.wireguard.com/)
- Synology 工具链下载: `https://global.synologydownload.com/download/ToolChain/toolchain/7.2-72806/Realtek%20RTD16xxb%20Linux%205.10.55/rtd1619b-gcc1220_glibc236_armv8-GPL.txz`
