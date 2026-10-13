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
# 注: kmod-xdp-sockets-diag 是 dae 包声明的运行依赖 (非 XDP 试验面), 随 dae 保留
PACKAGES="$PACKAGES kmod-sched-core kmod-sched-bpf kmod-veth kmod-tun kmod-xdp-sockets-diag"
PACKAGES="$PACKAGES tailscale"
# 注: tailscale 包提供 init/配置/uci 集成; 实际二进制由 files/usr/sbin/ 覆盖为官方静态 v1.102.4
# 系统监控: btop 全构建常驻 (2026-10-11 定; imm 基础无 htop/btop; libstdcpp 等依赖自动解析)
PACKAGES="$PACKAGES btop"
# 网络诊断: ethtool 全构建常驻 (2026-10-13 定; 网卡/链路/IRQ 合并参数诊断)
PACKAGES="$PACKAGES ethtool"
# XDP 工具面 —— 门控: 仅 native-capable 硬件 (workflow 白名单判定, ENABLE_XDP=yes) 才烘入;
# 默认 no = 纯内核网络栈 (Realtek 口无 native XDP; 试装件在 xdp/, 由 workflow 条件叠加)
if [ "${ENABLE_XDP:-no}" = "yes" ]; then
  PACKAGES="$PACKAGES ip-full bpftool-minimal xdp-loader xdp-filter xdpdump"
fi

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
echo "ENABLE_XDP       = ${ENABLE_XDP:-no}"
echo "PACKAGES         = $PACKAGES"
echo "--- repositories (官方 feed) ---"
cat repositories
echo "================================================"

# 仅产 squashfs 版 (2026-10-11 定稿): 关闭 ext4 镜像目标, 省一半产物空间
sed -i 's/^CONFIG_TARGET_ROOTFS_EXT4FS=y/# CONFIG_TARGET_ROOTFS_EXT4FS is not set/' .config
grep -n "EXT4FS" .config || echo "(未找到 EXT4FS 行, 以下方兜底删除为准)"

make image \
  PROFILE="$PROFILE" \
  PACKAGES="$PACKAGES" \
  FILES="/home/build/immortalwrt/files" \
  ROOTFS_PARTSIZE="$ROOTFS_PARTSIZE"

# 收尾: 兜底去 ext4 (防 .config 行格式变动) + sha256sums 只覆盖将发布的文件
cd bin/targets/rockchip/armv8
rm -f *ext4*
sha256sum *.img.gz *.manifest > sha256sums
echo "== 产物 (squashfs-only) =="
ls -la
cd /home/build/immortalwrt

echo "BUILD_OK"
