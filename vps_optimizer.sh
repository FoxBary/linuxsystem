#!/bin/bash

# =======================================
# 📌 一键优化 VPS，启用 TCP/UDP网络和服务器性能优化脚本
# 🛠 支持系统: CentOS / Ubuntu / Debian
# 🔥 作者: VmShell INC
# ⏳ 更新时间: 2025-03-16
# =======================================
# 🚀 优化服务器性能，提升网络吞吐量，让您的VPS更强劲！
# 🎉 立即体验：一键优化 TCP/UDP网络和服务器性能

# =======================================
# 相关信息：
# ➡️  公司：VmShell INC
# ➡️  注册：美国怀俄明注册正规企业
# ➡️  ASN号：147002（自有网络运营ASN号）
# ➡️  高速网络：香港CMI线路、高效美国云计算中心
# ➡️  官网订购地址: https://vmshell.com/
# ➡️  企业高速网络: https://tototel.com/
# ➡️  TeleGram讨论: https://t.me/vmshellhk
# ➡️  TeleGram频道: https://t.me/vmshell
# ➡️  支付方式：微信/支付宝/美国PayPal/USDT/比特币 (3日内无条件退款)
# =======================================

# 确保脚本以 root 用户权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本需要以 root 权限运行！"
    exit 1
fi

# 检查系统类型
OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

# 更新系统
echo "正在更新系统软件包..."
if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
    apt update && apt upgrade -y
elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* || "$OS" == *"Fedora"* ]]; then
    yum update -y
elif [[ "$OS" == *"Arch Linux"* ]]; then
    pacman -Syu --noconfirm
else
    echo "未支持的操作系统：$OS"
    exit 1
fi

# TCP 和 UDP 吞吐量优化
echo "正在进行 TCP 和 UDP 网络调优..."

# TCP 和 UDP 调优
sysctl -w net.core.netdev_max_backlog=50000
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
sysctl -w net.ipv4.tcp_mtu_probing=1
sysctl -w net.ipv4.tcp_max_syn_backlog=8192
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_fin_timeout=15
sysctl -w net.ipv4.tcp_keepalive_time=300
sysctl -w net.ipv4.tcp_keepalive_intvl=30
sysctl -w net.ipv4.tcp_keepalive_probes=10
sysctl -w net.ipv4.tcp_congestion_control=cubic  # 使用更高效的拥塞控制算法

# 启用 UDP 性能优化
sysctl -w net.ipv4.udp_mem="4096 87380 16777216"
sysctl -w net.ipv4.udp_rmem_min=4096
sysctl -w net.ipv4.udp_wmem_min=4096
sysctl -w net.core.udp_rmem_min=4096
sysctl -w net.core.udp_wmem_min=4096

# 禁用 TCP 延迟，提升吞吐量
sysctl -w net.ipv4.tcp_delack_min=0

# 加强内存和 CPU 性能优化
echo "正在进行内存和 CPU 性能优化..."

# 优化内存分配参数，最大化网络数据在内存中的缓存
sysctl -w vm.swappiness=1  # 降低交换分区的使用，优先使用内存
sysctl -w vm.dirty_ratio=80  # 允许更多的脏数据缓存
sysctl -w vm.dirty_background_ratio=5  # 后台写入脏数据前的缓存量
sysctl -w vm.page-cluster=3  # 提高页面处理速度，减少磁盘访问
sysctl -w vm.max_map_count=262144  # 增加进程能够映射的内存页数

# 调整 CPU 调度器的优先级，提升 CPU 性能
sysctl -w kernel.sched_child_runs_first=1  # 优先调度子进程
sysctl -w kernel.sched_min_granularity_ns=10000000  # 减少时间片，增加 CPU 调度精度
sysctl -w kernel.sched_wakeup_granularity_ns=15000000  # 提高 CPU 调度的灵敏度

# 调整内核 TCP、UDP 缓存区大小
sysctl -w net.ipv4.tcp_mem="524288 1048576 4194304"
sysctl -w net.ipv4.udp_mem="524288 1048576 4194304"

# 增加允许的最大套接字连接数
sysctl -w fs.file-max=2097152

# 增加 CPU 性能和网络数据传输的能力
echo "net.ipv4.tcp_rmem = 4096 87380 16777216" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 16777216" >> /etc/sysctl.conf
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
echo "net.ipv4.tcp_mtu_probing = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 8192" >> /etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fin_timeout = 15" >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_time = 300" >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_intvl = 30" >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_probes = 10" >> /etc/sysctl.conf
echo "vm.swappiness = 1" >> /etc/sysctl.conf
echo "vm.dirty_ratio = 80" >> /etc/sysctl.conf
echo "vm.dirty_background_ratio = 5" >> /etc/sysctl.conf
echo "vm.page-cluster = 3" >> /etc/sysctl.conf
echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
echo "kernel.sched_child_runs_first = 1" >> /etc/sysctl.conf
echo "kernel.sched_min_granularity_ns = 10000000" >> /etc/sysctl.conf
echo "kernel.sched_wakeup_granularity_ns = 15000000" >> /etc/sysctl.conf
echo "fs.file-max = 2097152" >> /etc/sysctl.conf

# 应用 sysctl 设置
sysctl -p

# 重启网络服务以使更改生效
echo "正在重启网络服务..."
if [[ "$OS" == *"Ubuntu"* || "$OS" == *"Debian"* ]]; then
    systemctl restart networking
elif [[ "$OS" == *"CentOS"* || "$OS" == *"Red Hat"* || "$OS" == *"Fedora"* ]]; then
    systemctl restart network
elif [[ "$OS" == *"Arch Linux"* ]]; then
    systemctl restart NetworkManager
else
    echo "重启网络服务失败：未支持的操作系统"
    exit 1
fi

echo "TCP/UDP 调优和系统性能优化完成，我们建议您重启服务器Reboot,性能得到显著提高，谢谢，感谢您使用 VmShell INC提供的优化脚本。"

