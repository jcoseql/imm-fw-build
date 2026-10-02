XDP 试装件 (generic/skb 模式) —— /root/xdp/
==================================================
内容:
  xdp_pass.c    源码（恒 PASS 的最小 XDP 程序，零扰动）
  xdp_pass.o    编译产物（构建时由 clang -O2 -target bpf 生成）
  本文件        使用说明

背景:
  E52C 两口均为瑞昱 RTL8125BG (PCIe) —— 厂商 r8125 驱动与主线 r8169 目前均无
  native XDP，因此一律使用 generic (skb) 模式。挂点比 native 晚（已进协议栈），
  适合功能试验（过滤/统计/重定向原型），非转发加速手段。

挂载 (以 eth1 为例，先确认端口命名):
  ip -force link set dev eth1 xdpgeneric obj /root/xdp/xdp_pass.o sec xdp
  # 或: xdp-loader load -m skb eth1 /root/xdp/xdp_pass.o

查看:
  ip link show dev eth1          # 接口行出现 prog/xdp 标记
  xdp-loader status              # 已加载的 XDP 程序一览
  bpftool net                    # bpf 挂载点总览
  bpftool prog show              # 全部 bpf 程序（类型/ID/tag）

卸载:
  ip link set dev eth1 xdpgeneric off
  # 或: xdp-loader unload eth1

随手工具:
  xdp-filter load eth1           # 轻量过滤（例: xdp-filter port 22）
  xdpdump -D eth1                # XDP 层抓包

注意:
  * generic XDP 丢弃的包对本机 conntrack/tcpdump 不可见；上生产规则前先定取证方案
  * XDP 位于 tc/iptables 之前；与 dae（tc eBPF 透明代理）可共存
  * 重启后挂载不保留（属预期，重新挂即可）
