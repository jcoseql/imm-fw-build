# imm-fw-build — ImmortalWrt Rockchip 固化固件（自建构建）

自建 ImageBuilder 固化构建：**不依赖任何第三方构建脚本**，只用官方组件
（`immortalwrt/imagebuilder` 容器 + `downloads.immortalwrt.org` 官方 feed）+ 本仓库自己的脚本与叠加层。

## 烘入清单

| 项 | 来源 | 校验 |
|---|---|---|
| dae `r857.17cc1d` | 本仓库 Releases `dae-bin-r857`（防上游 nightly 滚动覆盖） | 构建时 sha256 `930142c5…` 锁定；自检解包比对 |
| geoip / geosite | Loyalsoldier latest | 构建时下载 |
| dae procd init | `files/etc/init.d/dae` | sha256 `824fc2e3…`；IB 自动 enable（S99dae） |
| Tailscale 官方静态 `v1.102.4` | `pkgs.tailscale.com`（GitHub Release 无二进制资产） | sha256 ×3（tgz + 两二进制）；自检解包比对 |
| 首启脚本 | `files/etc/uci-defaults/99-custom.sh`（自建，仅设管理 IP） | 自检断言在位 |
| 包清单 | `scripts/build.sh`（唯一权威位置） | 自检断言关键包 |

## 运行

1. Actions → `Build 25.12.x Rockchip (自建 IB · dae 固化版)` → Run workflow
2. 输入：
   - `luci_version`：25.12.2（= builder 镜像 tag）
   - `profile`：设备型号（如 `friendlyarm_nanopi-r3s` / `radxa_e52c`）
   - `custom_router_ip`：管理地址（如 `192.168.12.1`）
   - `rootfs_partsize`：2G 默认（R3S 用 4G）
   - `enable_docker`：默认 no
3. 构建结束前自带 **Self-check**（manifest 断言 + 解包 sha 比对），失败会红
4. 产物在 Releases（tag `Autobuild`）：`*.img.gz` + `sha256sums` + `*.manifest`

## 刷机后

- 网络/PPPoE/dae 配置/TS state 等敏感配置**刻意不进镜像**；按恢复套件（`r3s_home_build/kit/README_restore.md`）scp 恢复
- dae：放 `/etc/dae/config.dae`（0640）→ `/etc/init.d/dae start`（S99dae 已就位）
- Tailscale：恢复 `/etc/tailscale/` state → `/etc/init.d/tailscale start`
- root 无密码：尽快设置；WAN 入站默认拒绝（首启脚本不做任何放开）

## 版本升级

- **dae 换版**：传新二进制到 Releases → 改 workflow 里 URL + sha（2 行）+ `selfcheck.sh` 里对应 sha（1 行）
- **Tailscale 换版**：改 workflow 里 URL（1 处）+ sha（3 处）+ `selfcheck.sh`（2 行）
- **增删包**：只改 `scripts/build.sh` 的 PACKAGES

## 本地复核（可选）

runner 自检已覆盖核心断言；如需再复核：下载 img.gz + manifest，按 `scripts/selfcheck.sh` 的方法在本地 Linux/容器内解包比对即可。

## 与老 fork（AutoBuildImmortalWrt）的关系

本仓库是 2026-09-30 起的**主力构建通道**；老 fork 保留作历史与回滚（其悟空包装层的问题——
argon 硬编码、首启放开 WAN 入站、第三方 apk 仓库拉取——在本项目里都不存在）。
