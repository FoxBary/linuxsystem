#!/bin/bash

# 一键优化 & 监控脚本
# 适用系统: CentOS / Ubuntu / Debian
# 作者: VmShell
# 日期: 2025-03-16

# 确保以 root 用户运行
if [ "$EUID" -ne 0 ]; then
    echo "错误：请以 root 用户运行此脚本"
    exit 1
fi

# 获取操作系统信息
OS=$(grep -Eo 'ID=[a-z]+' /etc/os-release | cut -d'=' -f2)
VERSION_ID=$(grep -Eo 'VERSION_ID="[0-9]+' /etc/os-release | cut -d'"' -f2)

# 调整磁盘分区大小
echo "正在调整分区大小..."
if [[ "$OS" == "debian" && ("$VERSION_ID" == "11" || "$VERSION_ID" == "12") ]]; then
    resize2fs -f /dev/vda1
elif [[ "$OS" == "ubuntu" && ("$VERSION_ID" == "20" || "$VERSION_ID" == "24") ]]; then
    resize2fs -f /dev/vda2
fi

# 如果是 CentOS 7，切换源
if [ -f /etc/redhat-release ] && grep -q "release 7" /etc/redhat-release; then
    echo "检测到 CentOS 7，正在更换软件源..."
    sed -i -r -e 's|^mirrorlist=|#mirrorlist=|g' \
               -e 's|^#?baseurl=http://mirror.centos.org/centos|baseurl=https://vault.centos.org/centos|g' \
               /etc/yum.repos.d/CentOS-*.repo
    yum clean all && yum makecache
fi

# 更新系统并安装必要软件
echo "更新系统并安装必要软件..."
if [[ "$OS" == "centos" ]]; then
    yum update -y
    yum install -y nano zip wget curl screen unzip vim crontabs sysstat iftop htop
    systemctl enable crond
    systemctl start crond
else
    apt update -y && apt upgrade -y
    apt install -y nano zip wget curl screen unzip vim cron sysstat iftop htop
    systemctl enable cron
    systemctl start cron
fi

# 启用 BBR + FQ 网络优化
echo "启用 BBR 并优化网络..."
cat >> /etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max = 2097152
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 65536
net.core.somaxconn = 4096
net.ipv4.tcp_fastopen = 3
EOF
sysctl -p

# 创建定时清理任务
echo "创建定时清理任务..."
mkdir -p /opt/script/cron
cat > /opt/script/cron/cleanCache.sh << 'EOF'
#!/bin/bash
echo "清理系统缓存..."
sync
echo 1 > /proc/sys/vm/drop_caches
echo 2 > /proc/sys/vm/drop_caches
echo 3 > /proc/sys/vm/drop_caches
echo "清理完成"

echo "清理 30 天前的日志文件..."
find /var/log -mtime +30 -type f -name "*.log" -exec rm -f {} \;
EOF
chmod +x /opt/script/cron/cleanCache.sh

# 设置定时任务（每 9 分钟运行一次）
(crontab -l 2>/dev/null; echo "*/9 * * * * bash /opt/script/cron/cleanCache.sh") | crontab -

# ================== 监控功能 ==================
function show_monitor() {
    clear
    echo "====================================="
    echo "        实时系统监控面板"
    echo "====================================="
    
    while true; do
        echo ""
        echo "📌 **系统资源使用情况**"
        echo "-------------------------"
        echo -e "🖥️ CPU 使用率：$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
        echo -e "📊 内存使用率：$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')"
        echo -e "💾 磁盘使用率：$(df -h / | awk 'NR==2{print $5}')"
        
        echo ""
        echo "📡 **网络流量 (Mbps)**"
        echo "-------------------------"
        RX=$(cat /sys/class/net/eth0/statistics/rx_bytes)
        TX=$(cat /sys/class/net/eth0/statistics/tx_bytes)
        sleep 1
        RX_NEW=$(cat /sys/class/net/eth0/statistics/rx_bytes)
        TX_NEW=$(cat /sys/class/net/eth0/statistics/tx_bytes)
        RX_RATE=$(echo "scale=2; ($RX_NEW - $RX) / 1024 / 1024 * 8" | bc)
        TX_RATE=$(echo "scale=2; ($TX_NEW - $TX) / 1024 / 1024 * 8" | bc)
        echo -e "⬇ 下载速度：$RX_RATE Mbps"
        echo -e "⬆ 上传速度：$TX_RATE Mbps"

        echo ""
        echo "⏳ 按 Ctrl + C 退出监控"
        sleep 2
        clear
    done
}

# 让用户选择是否运行实时监控
echo ""
echo "==============================="
echo " 请选择功能："
echo " 1) 立即重启服务器"
echo " 2) 运行实时监控面板"
echo " 3) 退出"
echo "==============================="
read -p "请输入选项 [1-3]: " choice

case "$choice" in
    1)
        echo "正在重启服务器..."
        reboot
        ;;
    2)
        show_monitor
        ;;
    3)
        echo "已退出脚本。"
        exit 0
        ;;
    *)
        echo "无效选项，退出。"
        exit 1
        ;;
esac
