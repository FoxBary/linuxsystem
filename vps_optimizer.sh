#!/bin/bash
# 一键优化 Linux VPS（支持 CentOS / Ubuntu / Debian）
# 自动扩展磁盘、安装 BBR + FQ、优化系统参数、实时监控
# 作者: VmShell INC
# 日期: 2025-03-16

# 确保以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误：请使用 root 用户运行此脚本: sudo $0"
    exit 1
fi

# 获取操作系统类型
if [ -f /etc/redhat-release ]; then
    OS="CentOS"
    PKG_MANAGER="yum"
    SERVICE_MANAGER="systemctl"
elif [ -f /etc/debian_version ]; then
    OS=$(grep -w "ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    PKG_MANAGER="apt"
    SERVICE_MANAGER="systemctl"
else
    echo "❌ 错误：不支持的操作系统"
    exit 1
fi

# 检测并扩展根分区
echo "🔄 检测并扩展根分区..."
if grep -q "Debian 11" /etc/os-release || grep -q "Debian 12" /etc/os-release; then
    resize2fs -f /dev/vda1
elif grep -q "Ubuntu 20" /etc/os-release || grep -q "Ubuntu 24" /etc/os-release; then
    resize2fs -f /dev/vda2
fi

# CentOS 7: 更换 YUM 源
if [ "$OS" = "CentOS" ] && grep -q "release 7" /etc/redhat-release; then
    echo "🔄 CentOS 7: 更换 YUM 源..."
    sed -i -r -e 's|^mirrorlist=|#mirrorlist=|g' \
               -e 's|^#?baseurl=http://mirror.centos.org/centos|baseurl=https://vault.centos.org/centos|g' \
               /etc/yum.repos.d/CentOS-*.repo
    yum clean all && yum makecache
fi

# 更新系统
echo "🔄 更新系统软件包..."
if [ "$PKG_MANAGER" = "yum" ]; then
    yum update -y
elif [ "$PKG_MANAGER" = "apt" ]; then
    apt update -y && apt upgrade -y
fi

# 安装必要软件包
echo "🔄 安装基础软件包..."
$PKG_MANAGER install -y nano zip wget curl screen unzip vim cron

# 启用 cron 服务
$SERVICE_MANAGER enable cron
$SERVICE_MANAGER start cron

# **安装并启用 BBR + FQ**
echo "🔄 检测是否安装 BBR..."
if lsmod | grep -q "bbr"; then
    echo "✅ BBR 已安装，跳过安装步骤"
else
    echo "🚀 安装并启用 BBR..."
    modprobe tcp_bbr
    echo "tcp_bbr" >> /etc/modules-load.d/bbr.conf

    # 配置 BBR + FQ
    cat >> /etc/sysctl.conf <<EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
EOF

    # 立即生效
    sysctl -p

    # 确保 BBR 模块已正确加载
    if lsmod | grep -q "bbr"; then
        echo "✅ BBR + FQ 已成功启用！"
    else
        echo "❌ BBR 加载失败，请尝试手动启用！"
        exit 1
    fi

    # 提示用户重启系统
    echo "⚠️ BBR 需要重启服务器后才能完全生效！"
    read -p "是否立即重启？[Y/n]: " choice
    case "$choice" in
        [Yy]* ) reboot ;;
        * ) echo "🚀 请手动运行 'reboot' 以完成 BBR 配置！" ;;
    esac
fi

# **优化系统内核参数**
echo "🔄 优化 Linux 网络和 CPU 性能..."
cat >> /etc/sysctl.conf <<EOF
fs.file-max = 2097152
net.core.somaxconn = 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 8192
EOF
sysctl -p

# **实时监控系统状态**
monitor_system() {
    clear
    echo "==================== VPS 实时监控 ===================="
    while true; do
        echo -e "\n📊 系统资源使用情况："
        echo "--------------------------------------------"
        echo "📌 CPU 使用率：$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
        echo "📌 内存使用率：$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')"
        echo "📌 硬盘使用率：$(df -h | awk '$NF=="/"{printf "%s", $5}')"
        echo "📌 网络下载速度：$(cat /sys/class/net/eth0/statistics/rx_bytes) Bytes/s"
        echo "📌 网络上传速度：$(cat /sys/class/net/eth0/statistics/tx_bytes) Bytes/s"
        echo "--------------------------------------------"
        sleep 2
        clear
    done
}

# **菜单**
echo "====================================="
echo "✅ VPS 优化脚本执行完毕！"
echo "====================================="
echo "请选择要执行的操作："
echo "1. 运行实时监控"
echo "2. 退出"
echo "====================================="
read -p "请输入选项 [1-2]: " choice

case "$choice" in
    1) monitor_system ;;
    2) echo "🚀 退出脚本！"; exit 0 ;;
    *) echo "❌ 无效输入，退出"; exit 1 ;;
esac
