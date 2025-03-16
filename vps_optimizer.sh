#!/bin/bash

# ==============================
# 📌 一键 VPS 优化脚本
# 🚀 支持系统: CentOS / Ubuntu / Debian
# 🛠️ 功能：
#   1. 自动安装 BBR 并优化 TCP
#   2. 检测并升级内核（若不支持 BBR）
#   3. 安装并配置 cron 定时清理任务
#   4. 引入 chiakge 的 Linux-NetSpeed 优化方案
# ==============================

# 颜色输出
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
NC="\e[0m"

# 确保以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：请使用 root 账号运行此脚本！${NC}"
    exit 1
fi

# 检测系统信息
if [ -f /etc/redhat-release ]; then
    OS="CentOS"
    PKG_MANAGER="yum"
    SERVICE_MANAGER="systemctl"
elif [ -f /etc/debian_version ]; then
    OS=$(cat /etc/os-release | grep -w "ID" | cut -d'=' -f2 | tr -d '"')
    PKG_MANAGER="apt"
    SERVICE_MANAGER="systemctl"
else
    echo -e "${RED}错误：不支持的操作系统${NC}"
    exit 1
fi

# 检查网络连接
if ! ping -c 1 google.com &> /dev/null; then
    echo -e "${RED}错误：网络连接失败，请检查网络设置${NC}"
    exit 1
fi

# 更新系统包
echo -e "${YELLOW}🔄 更新系统软件包...${NC}"
if [ "$PKG_MANAGER" = "yum" ]; then
    yum update -y
elif [ "$PKG_MANAGER" = "apt" ]; then
    apt update -y && apt upgrade -y
fi

# 安装基础组件
echo -e "${YELLOW}📦 安装基础组件...${NC}"
if [ "$OS" = "CentOS" ]; then
    yum install -y curl vim wget nano screen unzip zip cronie
    $SERVICE_MANAGER enable crond
    $SERVICE_MANAGER start crond
elif [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
    apt install -y curl vim wget nano screen unzip zip cron
    $SERVICE_MANAGER enable cron
    $SERVICE_MANAGER start cron
fi

# 📌 BBR 安装检测
echo -e "${YELLOW}🔍 检测是否安装 BBR...${NC}"
if lsmod | grep -q bbr; then
    echo -e "${GREEN}✅ BBR 已启用！${NC}"
else
    echo -e "${YELLOW}🚀 安装并启用 BBR...${NC}"
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p

    if lsmod | grep -q bbr; then
        echo -e "${GREEN}✅ BBR 启用成功！${NC}"
    else
        echo -e "${RED}❌ BBR 启用失败，需要升级内核！${NC}"
        
        # 自动升级内核
        if [ "$OS" = "CentOS" ]; then
            yum install -y epel-release
            yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
            yum --enablerepo=elrepo-kernel install -y kernel-ml
            grub2-set-default 0 && grub2-mkconfig -o /boot/grub2/grub.cfg
        elif [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
            apt install -y linux-image-$(uname -r)
            update-grub
        fi
        echo -e "${YELLOW}🔄 重启后请重新运行脚本！${NC}"
        reboot
    fi
fi

# 📌 下载并运行 chiakge TCP 优化脚本
echo -e "${YELLOW}📥 下载并执行 TCP 优化脚本...${NC}"
wget -O tcp_optimize.sh https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh && chmod +x tcp_optimize.sh && bash tcp_optimize.sh

# 📌 创建清理脚本
echo -e "${YELLOW}🧹 创建缓存清理脚本...${NC}"
mkdir -p /opt/script/cron
cat > /opt/script/cron/cleanCache.sh << 'EOF'
#!/bin/bash
echo "开始清除缓存"
sync;sync;sync
chmod -R 755 /opt/script/cron
chmod -R 755 /var/spool/mail
echo 1 > /proc/sys/vm/drop_caches
echo 2 > /proc/sys/vm/drop_caches
echo 3 > /proc/sys/vm/drop_caches
echo "缓存清理完成"
echo "删除30天之前的日志文件"
find /var/log -mtime +30 -type f -name "*.log" | xargs rm -f
echo "旧日志清理完成"
EOF
chmod +x /opt/script/cron/cleanCache.sh

# 📌 配置定时任务
echo -e "${YELLOW}⏲️ 配置定时任务（每9分钟运行一次）...${NC}"
(crontab -l 2>/dev/null; echo "*/9 * * * * bash /opt/script/cron/cleanCache.sh") | crontab -

# 📌 重启 cron 服务
echo -e "${YELLOW}🔄 重启 cron 服务...${NC}"
if [ "$OS" = "CentOS" ]; then
    $SERVICE_MANAGER restart crond
elif [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
    $SERVICE_MANAGER restart cron
fi

# ✅ 完成信息
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✅ VPS 优化脚本执行完毕！${NC}"
echo -e "${GREEN}✅ BBR 状态: $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')${NC}"
echo -e "${GREEN}✅ 定时任务已设置，每9分钟清理缓存 & 旧日志${NC}"
echo -e "${GREEN}=====================================${NC}"

# 📌 提示重启
echo ""
echo -e "${YELLOW}🔄 现在是否重启服务器？ [${RED}yes${NC}/${GREEN}no${NC}]${NC}"
read -p "输入你的选择: " choice
case "$choice" in
    [Yy]*)
        echo -e "${YELLOW}正在重启服务器...${NC}"
        reboot
        ;;
    *)
        echo -e "${GREEN}✅ 操作完成，手动重启以应用所有优化！${NC}"
        ;;
esac
