#!/bin/bash
# ============================================================
# 容器内构建脚本 (在官方 ImageBuilder 容器 /home/build/immortalwrt 执行)
# 包清单 = 唯一权威位置; 增删包只改这里 (与 files/ 叠加层配合)
# ============================================================
set -e
cd /home/build/immortalwrt

PACKAGES="curl openssh-sftp-server"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn luci-i18n-filemanager-zh-cn"
# upnp (本体 + 中文包 + nftables 实现) 与 vlmcsd (KMS 本体 + LuCI + 中文包)
PACKAGES="$PACKAGES luci-app-upnp luci-i18n-upnp-zh-cn miniupnpd-nftables"
PACKAGES="$PACKAGES luci-app-vlmcsd luci-i18n-vlmcsd-zh-cn vlmcsd"
# dae / Tailscale 运行依赖
PACKAGES="$PACKAGES kmod-sched-core kmod-sched-bpf kmod-veth kmod-tun kmod-xdp-sockets-diag"
PACKAGES="$PACKAGES tailscale"
# 注: tailscale 包提供 init/配置/uci 集成; 实际二进制由 files/usr/sbin/ 覆盖为官方静态 v1.102.4
# XDP 全量工具面 (native 与 generic/skb 两种挂法均覆盖; 试装件见 files/root/xdp/)
PACKAGES="$PACKAGES ip-full bpftool-minimal xdp-loader xdp-filter xdpdump"

if [ "${ENABLE_DOCKER:-no}" = "yes" ]; then
  # 引擎 + CLI + compose (containerd/runc/iptables-nft/kmod 依赖自动解析)
  PACKAGES="$PACKAGES docker dockerd docker-compose"
  # docker 桥接过滤必需; dockerd 包依赖里没有它, 需显式加:
  PACKAGES="$PACKAGES kmod-br-netfilter"
fi

echo "================================================"
echo "PROFILE          = $PROFILE"
echo "ROOTFS_PARTSIZE  = $ROOTFS_PARTSIZE"
echo "ENABLE_DOCKER    = ${ENABLE_DOCKER:-no}"
echo "PACKAGES         = $PACKAGES"
echo "--- repositories (官方 feed) ---"
cat repositories
echo "================================================"

make image \
  PROFILE="$PROFILE" \
  PACKAGES="$PACKAGES" \
  FILES="/home/build/immortalwrt/files" \
  ROOTFS_PARTSIZE="$ROOTFS_PARTSIZE"

echo "BUILD_OK"
