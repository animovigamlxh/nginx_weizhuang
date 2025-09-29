#!/bin/bash

# --- 内部配置变量 ---
INTERNAL_XRAYR_PORT="12345" # XrayR 内部监听端口
FALLBACK_PORT="8080"      # Nginx 回落接收端口
DEFAULT_REDIRECT_URL="https://www.bing.com"
NGINX_CONF_DIR="/etc/nginx/conf.d"

# --- 1. 获取用户输入 ---
echo "=========================================="
echo " Nginx 前置代理配置脚本 (TLS 卸载)"
echo "=========================================="

# 获取域名
while [ -z "$DOMAIN" ]; do
    read -rp "请输入您的 SNI 域名 (例如: hk12.yylxjichang.lol): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "域名不能为空。"
    fi
done

# 获取证书路径
while [ -z "$CERT_PATH" ]; do
    read -rp "请输入完整的证书文件路径 (.pem 或 .crt): " CERT_PATH
    if [ ! -f "$CERT_PATH" ]; then
        echo "文件不存在，请检查路径。"
        CERT_PATH=""
    fi
done

# 获取密钥路径
while [ -z "$KEY_PATH" ]; do
    read -rp "请输入完整的密钥文件路径 (.key): " KEY_PATH
    if [ ! -f "$KEY_PATH" ]; then
        echo "文件不存在，请检查路径。"
        KEY_PATH=""
    fi
done

# --- 2. 安装/检查 Nginx Stream 模块 ---
install_stream_module() {
    echo "--- 正在安装/检查 Nginx Stream 模块 ---"
    if command -v apt > /dev/null; then
        # Debian/Ubuntu
        sudo apt update > /dev/null
        sudo apt install -y nginx-mod-stream 
    elif command -v yum > /dev/null || command -v dnf > /dev/null; then
        # CentOS/RHEL/Fedora
        # stream 模块通常默认包含，此处跳过
        echo "Stream module assumed to be present."
    else
        echo "未找到 apt、yum 或 dnf 包管理器。请手动检查 Nginx 安装。"
        exit 1
    fi
}

# --- 3. 配置 Nginx Stream 分流 (443 端口) ---
configure_stream() {
    echo "--- 配置 Nginx 443 端口 (Stream 块) ---"
    STREAM_CONFIG="${NGINX_CONF_DIR}/stream_443.conf"
    
    # 将 stream 块内容写入一个单独的文件，并确保 nginx.conf 能够包含它
    # 注意：如果您的发行版要求 stream 块必须在 nginx.conf 的最外层，您需要手动移动此内容。
    sudo cat << EOF > ${STREAM_CONFIG}
stream {
    # 允许 Nginx 使用 \$ssl_preread_server_name 变量来检查 SNI 域名
    preread_timeout 5s; 

    # 定义 map 规则：根据 SNI 决定转发目标
    map \$ssl_preread_server_name \$backend_server {
        # 如果 SNI 匹配，转发给 XrayR 的内部端口 $INTERNAL_XRAYR_PORT
        "$DOMAIN" 127.0.0.1:${INTERNAL_XRAYR_PORT};
        
        # 否则，转发给 Nginx 的 HTTP 回落端口 $FALLBACK_PORT
        default 127.0.0.1:${FALLBACK_PORT};
    }

    # 主监听块：负责处理 443 端口的所有 TLS 流量
    server {
        listen 443 ssl;
        listen [::]:443 ssl;
        
        # 证书配置
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_certificate ${CERT_PATH};
        ssl_certificate_key ${KEY_PATH};

        # 开启 PROXY 协议，将客户端真实 IP 转发给后端
        proxy_protocol on; 
        
        # 使用 map 定义的后端地址进行转发
        proxy_pass \$backend_server;
    }
}
EOF
    echo "Nginx Stream 配置已写入: ${STREAM_CONFIG}"
}

# --- 4. 配置 Nginx HTTP 回落 (8080 端口) ---
configure_http_fallback() {
    echo "--- 配置 Nginx 8080 端口 (HTTP 回落块) ---"
    HTTP_CONFIG="${NGINX_CONF_DIR}/fallback_${FALLBACK_PORT}.conf"

    sudo cat << EOF > ${HTTP_CONFIG}
server {
    # 监听 $FALLBACK_PORT 端口，并启用 proxy_protocol 读取真实 IP
    listen ${FALLBACK_PORT} proxy_protocol; 
    listen [::]:${FALLBACK_PORT} proxy_protocol;

    server_name $DOMAIN;

    # 配置回落行为：重定向到默认目标
    location / {
        return 302 ${DEFAULT_REDIRECT_URL};
    }
}
EOF
    echo "Nginx HTTP 回落配置已写入: ${HTTP_CONFIG}"
}

# --- 主程序执行 ---
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (例如: sudo bash 脚本名.sh)"
  exit 1
fi

install_stream_module
configure_stream
configure_http_fallback

# 检查配置语法并重启 Nginx
echo "--- 检查配置语法并重启 Nginx ---"
sudo nginx -t
if [ $? -eq 0 ]; then
    sudo systemctl restart nginx
    echo "=========================================="
    echo "🎉 **Nginx 配置和重启成功!**"
    echo "Nginx 现在负责 443 端口的 TLS 卸载和流量分流。"
    echo "---"
    echo "下一步：请务必修改 XrayR 配置!"
    echo "=========================================="
    echo "请在 XrayR 的 /etc/XrayR/config.yml 中进行以下关键修改："
    echo "1. 节点端口: 将您的 Trojan/VLESS 节点端口改为: ${INTERNAL_XRAYR_PORT}"
    echo "2. CertMode: 将 CertMode 改为: none"
    echo "3. ProxyProtocol: 将 EnableProxyProtocol 改为: true"
    echo "完成后，请重启 XrayR 服务: sudo systemctl restart XrayR"
else
    echo "⚠️ Nginx 配置语法检查失败，请检查 ${NGINX_CONF_DIR} 目录下的文件内容。"
    exit 1
fi
