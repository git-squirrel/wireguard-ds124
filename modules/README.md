# modules/ 目录 — 请放入以下编译好的 .ko 文件

从 NAS 编译环境拷贝到本目录后上传 GitHub。
文件来源: `/volume1/docker/wireguard-build/` (或 NAS 上 `/lib/modules/`)

| 文件 | 说明 | 必须 |
|---|---|---|
| wireguard.ko | WireGuard 主模块 | ✅ |
| libblake2s.ko | BLAKE2s 哈希依赖 | ✅ |
| libblake2s-generic.ko | BLAKE2s generic 实现 | ✅ |
| libcurve25519.ko | Curve25519 依赖 | ✅ |
| libcurve25519-generic.ko | Curve25519 generic 实现 | ✅ |
| libchacha.ko | ChaCha 加密依赖 | ✅ |
| libchacha20poly1305.ko | ChaCha20-Poly1305 AEAD 依赖 | ✅ |
| chacha-neon.ko | NEON 加速 (ARM64) | ✅ |
| poly1305-neon.ko | NEON 加速 (ARM64) | ✅ |
| ip6table_nat.ko | IPv6 NAT (wg-quick ip6tables 需要) | ✅ |

验证: `vermagic` 必须是 `5.10.55+ SMP mod_unload aarch64`

```bash
# NAS 上验证
cat /lib/modules/wireguard.ko | grep -a vermagic
```

拷贝命令 (NAS → 本目录):
```bash
cd /volume1/docker/wireguard-build
cp wireguard.ko libblake2s.ko libblake2s-generic.ko \
   libcurve25519.ko libcurve25519-generic.ko libchacha.ko \
   libchacha20poly1305.ko chacha-neon.ko poly1305-neon.ko \
   ip6table_nat.ko /volume1/.../wireguard-ds124/modules/
```
