#!/bin/bash

# =======================================
# 📌 一键优化 VPS，启用 BBR + FQ，定时清理
# 🛠 支持系统: CentOS / Ubuntu / Debian
# 🔥 作者: FoxBary
# ⏳ 更新时间: 2025-03-16
# =======================================

# 检查是否以 root 用户运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误：请以 root 用户运行此脚本: sudo bash $0"
    exit 1
fi

# 检测系统类型
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

# 检查网络连接
if ! ping -c 1 google.com &> /dev/null; then
    echo "❌ 错误：网络连接失败，请检查网络设置"
    exit 1
fi

# 更新系统软件包
echo "📦 更新系统软件包..."
if [ "$PKG_MANAGER" = "yum" ]; then
    yum update -y || { echo "❌ 错误：更新失败"; exit 1; }
elif [ "$PKG_MANAGER" = "apt" ]; then
    apt update -y && apt upgrade -y || { echo "❌ 错误：更新失败"; exit 1; }
fi

# 安装必要组件
echo "🔧 安装基础组件..."
if [ "$OS" = "CentOS" ]; then
    yum install -y curl vim wget nano screen unzip zip crontabs
    $SERVICE_MANAGER enable crond
    $SERVICE_MANAGER start crond
elif [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
    apt install -y curl vim wget nano screen unzip zip cron
    $SERVICE_MANAGER enable cron
    $SERVICE_MANAGER start cron
fi

# **安装 BBR**
echo "🔄 检测是否安装 BBR..."
if lsmod | grep -q "bbr"; then
    echo "✅ BBR 已安装，无需重复安装。"
else
    echo "🚀 安装并启用 BBR..."

    # 配置 BBR 参数
    cat > /etc/sysctl.d/99-bbr.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_fastopen=3
EOF

    # 使配置生效
    sysctl --system

    # 检查是否成功启用
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo "✅ BBR 启用成功！"
    else
        echo "❌ BBR 启用失败，需要升级内核！"
        
        # **升级内核**
        echo "🚀 升级内核..."
        if [ "$OS" = "CentOS" ]; then
            yum install -y epel-release
            rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
            yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
            yum --enablerepo=elrepo-kernel install -y kernel-ml
        elif [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
            apt install -y linux-generic-hwe-$(lsb_release -sr)
        fi

        # 设置新内核为默认启动
        grub2-set-default 0
        grub2-mkconfig -o /boot/grub2/grub.cfg

        echo "🔄 内核升级完成，请手动重启系统后重新运行此脚本。"
        exit 1
    fi
fi

# **创建清理缓存的定时任务**
echo "🧹 创建定时任务：清理缓存 & 日志"

mkdir -p /opt/script/cron

cat > /opt/script/cron/cleanCache.sh << 'EOF'
#!/bin/bash
echo "🚀 开始清理缓存..."
sync
echo 1 > /proc/sys/vm/drop_caches
echo 2 > /proc/sys/vm/drop_caches
echo 3 > /proc/sys/vm/drop_caches
echo "✅ 缓存清理完成！"

echo "🗑 删除 30 天前的日志文件..."
find /var/log -mtime +30 -type f -name "*.log" -delete
echo "✅ 日志清理完成！"
EOF

chmod +x /opt/script/cron/cleanCache.sh

(crontab -l 2>/dev/null; echo "*/9 * * * * bash /opt/script/cron/cleanCache.sh") | crontab -

echo "🔄 重启 cron 任务..."
if [ "$OS" = "CentOS" ]; then
    $SERVICE_MANAGER restart crond
elif [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
    $SERVICE_MANAGER restart cron
fi

echo "====================================="
echo "✅ VPS 优化 & BBR 启用成功！"
echo "📅 定时清理任务已设置，每 9 分钟自动清理缓存 & 日志。"
echo "====================================="

# **询问是否重启**
echo -e "请现在确认重启服务器? [\e[31myes\e[0m/\e[32mno\e[0m]"
read -p "输入你的选择: " choice

case "$choice" in
    [Yy][Ee][Ss]|[Yy])
        echo "🔄 正在重启服务器..."
        reboot
        ;;
    [Nn][Oo]|[Nn])
        echo "✅ 已取消重启，脚本执行完毕。"
        ;;
    *)
        echo "❌ 无效输入，默认不重启。"
        ;;
esac
