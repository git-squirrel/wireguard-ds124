# 从零编译 WireGuard 内核模块 (DS124 / RTD1619B)

> 适用: Synology DS124, DSM 7.2.2-72806, 内核 5.10.55+
> 以下步骤在 **NAS 本机 Docker 容器 (ARM64)** 内完成，无需额外编译机。

## 一、环境准备

在 NAS 上启动一个 ARM64 Ubuntu 22.04 容器作为编译环境：

```bash
docker run -it --name wireguard-build ubuntu:22.04
```

容器内安装编译依赖：

```bash
apt update && apt install -y git make gcc flex bison bc kmod cpio libelf-dev wget xz-utils curl
```

## 二、获取 spksrc 构建框架

```bash
git clone --depth=1 https://github.com/SynoCommunity/spksrc.git
cd spksrc
```

## 三、安装交叉工具链

> ⚠️ 注意：Synology 官方工具链 `rtd1619b-gcc1220_glibc236_armv8-GPL.txz` 是 **x86_64 主机** 的交叉编译器，
> **无法在 ARM64 容器内直接运行**（Exec format error）。
>
> 因此这里跳过交叉工具链，直接在 ARM64 容器内用 **本机 gcc** 原生编译（本机 gcc 11.4.0 足够）。

```bash
# 工具链目录已存在但无需使用交叉编译器
# 直接进入内核源码构建
```

## 四、下载并解压 Synology 内核源码

```bash
cd /spksrc/kernel/syno-rtd1619b-7.2
make extract
```

这会把内核源码解压到 `work/linux/`（Synology 官方 5.10.x 源码）。

## 五、配置内核

```bash
cd /spksrc/kernel/syno-rtd1619b-7.2

# 打补丁 + 应用 Synology 官方配置 (synoconfigs/rtd1619b)
make kernel_configure
```

### 启用 WireGuard 和 IP6 NAT

```bash
cd work/linux

# 启用 WireGuard 模块
echo "CONFIG_WIREGUARD=m" >> .config
echo "CONFIG_WIREGUARD_DEBUG=y" >> .config

# 启用 IPv6 NAT (wg-quick 的 ip6tables 规则需要)
echo "CONFIG_IP6_NF_NAT=m" >> .config

# 同步配置 (关键: 加上内核 release 的 "+" 后缀, 匹配 NAS 的 5.10.55+)
sed -i 's/^CONFIG_LOCALVERSION=""/CONFIG_LOCALVERSION="+"/' .config
make ARCH=arm64 CROSS_COMPILE= olddefconfig
```

## 六、编译模块

```bash
# 先准备内核构建环境 (生成 modpost 等 host 工具)
# 如果报 python3 缺失: apt install -y python3
make ARCH=arm64 CROSS_COMPILE= modules_prepare

# 编译全部模块 (wireguard 及其依赖 libblake2s/libchacha/libcurve25519 等)
make ARCH=arm64 CROSS_COMPILE= modules
```

### 单独编译 wireguard（可选）

```bash
make ARCH=arm64 CROSS_COMPILE= M=drivers/net/wireguard modules
```

### 编译 ip6table_nat

```bash
make ARCH=arm64 CROSS_COMPILE= M=net/ipv6/netfilter modules
```

## 七、验证 vermagic

模块的 vermagic 必须与 NAS 内核完全一致：`5.10.55+ SMP mod_unload aarch64`

```bash
# 检查 (应输出 5.10.55+)
cat drivers/net/wireguard/wireguard.ko | grep -a vermagic

# 如果显示 5.10.55 (无 +), 说明 LOCALVERSION 未生效:
# 1. 确认 .config 里 CONFIG_LOCALVERSION="+"
# 2. make ARCH=arm64 CROSS_COMPILE= prepare
# 3. 重新 make modules
```

## 八、拷贝到 NAS

```bash
# 在编译容器内
mkdir -p /build
cp drivers/net/wireguard/wireguard.ko /build/
cp lib/crypto/libblake2s.ko /build/
cp lib/crypto/libblake2s-generic.ko /build/
cp lib/crypto/libchacha.ko /build/
cp lib/crypto/libchacha20poly1305.ko /build/
cp lib/crypto/libcurve25519.ko /build/
cp lib/crypto/libcurve25519-generic.ko /build/
cp arch/arm64/crypto/chacha-neon.ko /build/
cp arch/arm64/crypto/poly1305-neon.ko /build/
cp net/ipv6/netfilter/ip6table_nat.ko /build/

# 退出容器, 在 NAS 上
docker cp wireguard-build:/build/. /volume1/docker/wireguard-modules/
```

## 九、加载模块 (NAS)

```bash
cd /volume1/docker/wireguard-modules
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
lsmod | grep wireguard
```

## 十、常见错误

| 错误 | 原因 | 解决 |
|---|---|---|
| `Exec format error` | x86_64 交叉编译器在 ARM64 上运行 | 用容器本机 gcc 原生编译 (CROSS_COMPILE= 留空) |
| `Invalid module format` | vermagic 不匹配 | 确认 CONFIG_LOCALVERSION="+" 且内核 5.10.55+ |
| `Unknown symbol` | 依赖模块未加载或顺序错误 | 按第九节顺序加载 |
| `ip6tables: Table does not exist` | 缺 ip6table_nat | 编译并加载 ip6table_nat.ko |
| `Unable to access interface: No such device` | wg0 被 wg-quick 失败后清理 | 加载全部模块后重启 wg-easy 容器 |

## 环境信息速查

- 容器: ubuntu:22.04 (ARM64)
- 内核源码: spksrc `kernel/syno-rtd1619b-7.2` → `work/linux` (linux-5.10.x)
- 工具链: 无需交叉工具链, 原生 gcc 11.4.0
- 编译命令: `make ARCH=arm64 CROSS_COMPILE= modules`
- vermagic: `5.10.55+ SMP mod_unload aarch64`
