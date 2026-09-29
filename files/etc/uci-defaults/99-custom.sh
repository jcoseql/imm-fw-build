#!/bin/sh
# ============================================================
# 首启脚本 (自建版, 极简): 仅设置 LAN 管理地址。
# 原则: 不放开 WAN 入站 / 不改 ttyd·dropbear 监听 / 不拉第三方仓库。
# 管理 IP 来源: /etc/config/custom_router_ip.txt (由 CI 构建时写入)
# ============================================================
IP_FILE="/etc/config/custom_router_ip.txt"
LOGFILE="/etc/config/uci-defaults-log.txt"
{
  echo "Starting 99-custom.sh at $(date)"
  if [ -f "$IP_FILE" ]; then
    IP=$(cat "$IP_FILE")
    uci -q delete network.lan.ipaddr
    uci set network.lan.proto='static'
    uci set network.lan.ipaddr="$IP"
    uci set network.lan.netmask='255.255.255.0'
    uci commit network
    echo "lan.ipaddr -> $IP"
  else
    echo "no custom_router_ip.txt, keep default lan ip"
  fi
} >>"$LOGFILE" 2>&1
exit 0
