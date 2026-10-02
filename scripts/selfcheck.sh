#!/bin/bash
# ============================================================
# 构建后自检 (在 runner 上执行, cwd = 仓库根)
#   1) manifest 断言: 无 argon; 关键包在列 (docker 按开关条件断言)
#   2) 解包 squashfs: 比对烘入件 sha256; 检查首启脚本 / rc.d / 无 config.dae
#   3) XDP 试装件: /root/xdp/ (xdp_pass.c + ELF .o + README)
# ============================================================
set -euo pipefail
cd bin/targets/rockchip/armv8
IMG=$(ls *squashfs-sysupgrade.img.gz | head -1)
[ -n "$IMG" ] || { echo "❌ 未找到 squashfs-sysupgrade 镜像"; ls -la; exit 1; }
MAN=$(ls *.manifest | head -1)
echo "IMG = $IMG"
echo "MAN = $MAN"

echo "== [1] manifest 断言 =="
if grep -qi "argon" "$MAN"; then echo "❌ manifest 残留 argon:"; grep -i argon "$MAN"; exit 1; fi
echo "✓ 无 argon"
for p in vlmcsd luci-app-upnp miniupnpd-nftables luci-app-vlmcsd luci-i18n-ttyd-zh-cn openssh-sftp-server tailscale ip-full bpftool-minimal xdp-loader xdp-filter xdpdump; do
  grep -q "^${p} " "$MAN" || { echo "❌ 缺包: $p"; exit 1; }
done
echo "✓ 关键包在列 (vlmcsd / upnp / ttyd-zh / sftp-server / tailscale / XDP 工具面)"
if [ "${ENABLE_DOCKER:-no}" = "yes" ]; then
  for p in dockerd docker docker-compose containerd runc iptables-nft kmod-br-netfilter; do
    grep -q "^${p} " "$MAN" || { echo "❌ 缺包 (docker): $p"; exit 1; }
  done
  echo "✓ docker 关键依赖在列 (dockerd/compose/containerd/runc/iptables-nft/br-netfilter)"
fi

echo "== [2] 解包 rootfs 比对 =="
sudo apt-get -qq update >/dev/null 2>&1
sudo apt-get -qq install -y squashfs-tools >/dev/null 2>&1
gzip -dc "$IMG" > /tmp/img.raw || { [ -s /tmp/img.raw ] || exit 1; }
python3 - <<'PY'
import struct
d = open('/tmp/img.raw','rb').read()
cands = []; i = 0
while True:
    i = d.find(b'hsqs', i)
    if i < 0: break
    try:
        major, = struct.unpack_from('<H', d, i+28)
        bs,    = struct.unpack_from('<I', d, i+12)
        used,  = struct.unpack_from('<Q', d, i+40)
        if major == 4 and 4096 <= bs <= 1048576 and 0 < used < 2**31:
            cands.append((i, used, bs))
    except Exception: pass
    i += 4
assert cands, "no squashfs superblock found!"
off, used, bs = cands[-1]
open('/tmp/root.sqfs','wb').write(d[off:off+used])
print("squashfs: offset=%s used=%d (%.1f MiB)" % (off, used, used/1048576))
PY
sudo rm -rf /tmp/ex
sudo unsquashfs -no-progress -q -d /tmp/ex /tmp/root.sqfs

check_sha() { # $1=期望sha  $2=路径
  echo "$1  $2" | sha256sum -c - || { echo "❌ sha 不符: $2"; exit 1; }
}
check_sha cc6c18d47bb9c404fab864cadb983e188766a5187ec706ab6a7fb88257f14d59 /tmp/ex/usr/bin/dae
check_sha 93c3558f592200133b377dd9f96eac9b278b9057f7ae6b8656b15f4fa05506d0 /tmp/ex/usr/sbin/tailscale
check_sha 1ff5174fcbf3abbff85eacc73e6e548b0d094d913a48c1369f60811d1e92eeef /tmp/ex/usr/sbin/tailscaled
check_sha 824fc2e32cef8f14e8f669e7d53ede18870aeeb14983307bb53b3b9dbf4d19b4 /tmp/ex/etc/init.d/dae
echo "✓ 烘入件 sha 全部一致 (dae e3fee8fb / tailscale / tailscaled / dae-init)"

test -x /tmp/ex/etc/uci-defaults/99-custom.sh || { echo "❌ 首启脚本缺失或不可执行"; exit 1; }
grep -q "custom_router_ip" /tmp/ex/etc/uci-defaults/99-custom.sh
echo "✓ 首启脚本在位 (755)"
echo "  管理IP文件: $(cat /tmp/ex/etc/config/custom_router_ip.txt 2>/dev/null)"

ls /tmp/ex/etc/rc.d/ | grep -qi "S99dae" || { echo "❌ rc.d 缺 S99dae (IB 未自动 enable)"; exit 1; }
echo "✓ S99dae 开机自启已就位"

if [ -e /tmp/ex/etc/dae/config.dae ]; then echo "❌ 发现 config.dae (不应存在!)"; exit 1; fi
echo "✓ 无 config.dae (纯二进制版)"

echo "== [3] XDP 试装件 =="
sudo test -f /tmp/ex/root/xdp/xdp_pass.c     || { echo "❌ 缺 xdp_pass.c"; exit 1; }
sudo test -s /tmp/ex/root/xdp/xdp_pass.o     || { echo "❌ 缺 xdp_pass.o (CI clang 编译失败?)"; exit 1; }
[ "$(sudo head -c4 /tmp/ex/root/xdp/xdp_pass.o | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || { echo "❌ xdp_pass.o 非 ELF"; exit 1; }
sudo test -f /tmp/ex/root/xdp/README-xdp.txt || { echo "❌ 缺 README-xdp.txt"; exit 1; }
echo "✓ XDP 试装件在位 (xdp_pass.c + ELF .o + README-xdp.txt)"

echo "SELFCHECK_PASS"
