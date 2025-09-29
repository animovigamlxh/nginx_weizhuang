#!/bin/bash

# --- 脚本配置变量 ---
FALLBACK_PORT="8080"
BING_URL="https://www.bing.com"
DOMAIN="" # 域名将由用户输入

# --- 1. 获取用户输入 ---
echo "=========================================="
echo " Nginx 回落配置脚本"
echo "=========================================="

while [ -z "$DOMAIN" ]; do
    read -rp "请输入您要配置的 SNI 域名（例如: hk12.yylxjichang.lol）: " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "域名不能为空，请重新输入。"
    fi
done

CONFIG_FILE_NAME="${DOMAIN}.conf"

# Nginx 配置文件的路径 (根据系统确定)
if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
    # Debian/Ubuntu
    NGINX_CONF_DIR="/etc/nginx/sites-available"
    NGINX_ENABLE_DIR="/etc/nginx/sites-enabled"
elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ] || [ -f /etc/fedora-release ]; then
    # CentOS/RHEL/Fedora
    NGINX_CONF_DIR="/etc/nginx/conf.d"
    NGINX_ENABLE_DIR="/etc/nginx/conf.d" # 直接放在 conf.d
else
    echo "不支持的操作系统。请手动安装和配置 Nginx。"
    exit 1
fi
NGINX_CONFIG="${NGINX_CONF_DIR}/${CONFIG_FILE_NAME}"

# --- 函数：安装 Nginx ---
install_nginx() {
    echo "--- 2. 正在安装 Nginx ---"
    if command -v apt > /dev/null; then
        # Debian/Ubuntu
        sudo apt update
        sudo apt install -y nginx
    elif command -v yum > /dev/null; then
        # CentOS/RHEL
        sudo yum install -y epel-release 
        sudo yum install -y nginx
    elif command -v dnf > /dev/null; then
        # Fedora/较新的 RHEL
        sudo dnf install -y nginx
    else
        echo "未找到 apt、yum 或 dnf 包管理器。请手动安装 Nginx。"
        exit 1
    fi
    echo "Nginx 安装完成。"
}

# --- 函数：配置 Nginx 回落 ---
configure_nginx() {
    echo "--- 3. 正在配置 Nginx 回落服务器 ---"

    # 确保配置目录存在
    sudo mkdir -p ${NGINX_CONF_DIR}

    # 写入 Nginx 配置文件内容
    sudo cat << EOF > ${NGINX_CONFIG}
server {
    # 监听 XrayR/Trojan 转发过来的明文 HTTP 流量
    listen ${FALLBACK_PORT};
    listen [::]:${FALLBACK_PORT};

    # 匹配用户输入的 SNI 域名
    server_name ${DOMAIN};

    # 配置回落行为：将所有请求重定向到 bing.com
    location / {
        # 使用 302 临时重定向，返回 HTTPS 地址
        return 302 ${BING_URL};
    }
}
EOF

    echo "配置文件已写入到 ${NGINX_CONFIG}"

    # 启用配置 (仅 Debian/Ubuntu 需要创建软链接)
    if [ -d /etc/nginx/sites-available ] && [ -d /etc/nginx/sites-enabled ]; then
        if [ ! -L ${NGINX_ENABLE_DIR}/${CONFIG_FILE_NAME} ]; then
            sudo ln -s ${NGINX_CONFIG} ${NGINX_ENABLE_DIR}/${CONFIG_FILE_NAME}
            echo "已创建软链接到 ${NGINX_ENABLE_DIR}"
        fi
    fi
    
    # 确保移除 default 配置，避免干扰 (仅 Debian/Ubuntu 常见)
    if [ -f /etc/nginx/sites-enabled/default ]; then
        sudo rm -f /etc/nginx/sites-enabled/default
    fi
}

# --- 函数：测试并重启 Nginx ---
restart_nginx() {
    echo "--- 4. 正在测试并重启 Nginx 服务 ---"
    # 检查配置语法
    sudo nginx -t
    if [ $? -eq 0 ]; then
        echo "Nginx 配置语法检查通过。"
        # 启动或重新加载服务
        sudo systemctl enable nginx
        sudo systemctl restart nginx
        echo "Nginx 服务已重启，回落配置已生效。"
        echo "=========================================="
        echo "🎉 **回落配置脚本执行成功!**"
        echo "配置的伪装域名: **${DOMAIN}**"
        echo "监听端口: **${FALLBACK_PORT}**"
        echo "非 Trojan 访问将重定向到: **${BING_URL}**"
        echo "=========================================="
    else
        echo "⚠️ Nginx 配置语法检查失败，请检查文件 ${NGINX_CONFIG} 中的内容。"
        exit 1
    fi
}

# --- 主程序执行 ---
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (例如: sudo bash 脚本名.sh)"
  exit 1
fi

install_nginx
configure_nginx
restart_nginx
