#!/bin/bash

# --- 内部配置变量 ---
INTERNAL_XRAYR_PORT="12345" # XrayR 内部监听端口
FALLBACK_PORT="8080"      # Nginx 回落接收端口
DEFAULT_REDIRECT_URL="https://www.bing.com"
NGINX_CONF_DIR="/etc/nginx/conf.d"
NGINX_MAIN_CONF="/etc/nginx/nginx.conf"

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- 1. 获取用户输入 ---
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN} Nginx 前置代理配置脚本 (自动修改 nginx.conf)${NC}"
echo -e "${GREEN}==========================================${NC}"

# 获取域名
while [ -z "$DOMAIN" ]; do
    read -rp "请输入您的 SNI 域名 (例如: hk12.yylxjichang.lol): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空。${NC}"
    fi
done

# 获取证书路径
while [ -z "$CERT_PATH" ]; do
    read -rp "请输入完整的证书文件路径 (.pem 或 .crt): " CERT_PATH
    if [ ! -f "$CERT_PATH" ]; then
        echo -e "${RED}文件不存在，请检查路径。${NC}"
        CERT_PATH=""
    fi
done

# 获取密钥路径
while [ -z "$KEY_PATH" ]; do
    read -rp "请输入完整的密钥文件路径 (.key): " KEY_PATH
    if [ ! -f "$KEY_PATH" ]; then
        echo -e "${RED}文件不存在，请检查路径。${NC}"
        KEY_PATH=""
    fi
done

# --- 2. 安装/检查 Nginx 并启用 Stream 模块 ---
install_nginx_and_stream() {
    echo -e "${GREEN}--- 正在安装 Nginx 完整版并检查 Stream 模块 ---${NC}"
    if command -v apt > /dev/null; then
        # Debian/Ubuntu
        sudo apt update > /dev/null
        # 安装 Nginx 核心，尝试安装 stream 模块
        sudo apt install -y nginx nginx-mod-stream 2>/dev/null
    elif command -v yum > /dev/null || command -v dnf > /dev/null; then
        # CentOS/RHEL/Fedora
        sudo yum install -y nginx || sudo dnf install -y nginx
        echo "Stream module assumed to be present on RHEL/CentOS."
    else
        echo -e "${RED}未找到 apt、yum 或 dnf 包管理器。请手动安装 Nginx。${NC}"
        exit 1
    fi
}

# --- 3. 生成 Stream 块内容 ---
generate_stream_config() {
    echo -e "${GREEN}--- 生成 Nginx Stream 块内容 ---${NC}"
    STREAM_BLOCK=$(cat <<EOF
stream {
    preread_timeout 5s;

    map \$ssl_preread_server_name \$backend_server {
        "$DOMAIN" 127.0.0.1:${INTERNAL_XRAYR_PORT};
        default 127.0.0.1:${FALLBACK_PORT};
    }

    server {
        listen 443 ssl;
        listen [::]:443 ssl;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_certificate ${CERT_PATH};
        ssl_certificate_key ${KEY_PATH};

        proxy_protocol on; 
        proxy_pass \$backend_server;
    }
}
EOF
)
}

# --- 4. 将 Stream 块插入到 nginx.conf ---
insert_stream_block() {
    echo -e "${GREEN}--- 将 Stream 块插入到 ${NGINX_MAIN_CONF} ---${NC}"
    
    # 检查 Stream 块是否已经存在，避免重复添加
    if sudo grep -q "stream {" ${NGINX_MAIN_CONF}; then
        echo -e "${RED}Stream 块似乎已存在于 ${NGINX_MAIN_CONF}，跳过插入。${NC}"
    else
        # 查找 http { 块，并在这之前插入 stream 块 (使用分隔符避免变量冲突)
        # sed -i 'i\INSERT_TEXT' 在匹配行之前插入文本
        # 注意：这里可能需要转义一些字符，但使用 cat/EOF block 可以避免大部分转义问题
        
        # 备份主配置文件
        sudo cp ${NGINX_MAIN_CONF} ${NGINX_MAIN_CONF}.bak_$(date +%Y%m%d%H%M%S)
        
        # 查找 http { 块，并在其之前插入生成的 Stream 块内容
        # 使用 -e 选项处理多行插入
        # 使用 '|' 作为 sed 的分隔符，防止路径中的 '/' 引起问题
        
        INSERT_POINT='^http {'
        
        # 将多行文本作为单个字符串插入
        # 查找 http {，然后在其前插入 Stream 块
        sudo sed -i "/${INSERT_POINT}/i\ ${STREAM_BLOCK}" ${NGINX_MAIN_CONF}
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Stream 块已成功插入到 ${NGINX_MAIN_CONF}。${NC}"
        else
            echo -e "${RED}Stream 块插入失败，请手动检查 ${NGINX_MAIN_CONF}。${NC}"
            exit 1
        fi
    fi
}

# --- 5. 配置 Nginx HTTP 回落 (8080 端口) ---
configure_http_fallback() {
    echo -e "${GREEN}--- 配置 Nginx ${FALLBACK_PORT} 端口 (HTTP 回落块) ---${NC}"
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
    echo -e "${GREEN}Nginx HTTP 回落配置已写入: ${HTTP_CONFIG}${NC}"
}

# --- 主程序执行 ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用 root 权限运行此脚本 (例如: sudo bash 脚本名.sh)${NC}"
  exit 1
fi

install_nginx_and_stream
generate_stream_config
insert_stream_block
configure_http_fallback

# 检查配置语法并重启 Nginx
echo -e "${GREEN}--- 检查配置语法并重启 Nginx ---${NC}"
sudo nginx -t
if [ $? -eq 0 ]; then
    sudo systemctl restart nginx
    
    echo -e "\n${GREEN}==========================================${NC}"
    echo -e "${GREEN}🎉 Nginx 配置和重启成功!${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo "Nginx 现在负责 443 端口的 TLS 卸载和流量分流。"
    echo -e "${RED}--- 关键下一步：请务必修改 XrayR 配置! ---${NC}"
    echo "1. 节点端口: 将您的 Trojan/VLESS 节点端口改为: ${INTERNAL_XRAYR_PORT}"
    echo "2. CertMode: 将 CertMode 改为: ${RED}none${NC}"
    echo "3. ProxyProtocol: 将 EnableProxyProtocol 改为: ${RED}true${NC}"
    echo "完成后，请运行: ${GREEN}sudo systemctl restart XrayR${NC}"
else
    echo -e "\n${RED}⚠️ Nginx 配置语法检查失败，请检查 ${NGINX_MAIN_CONF} 和 ${NGINX_CONF_DIR} 目录下的文件内容。${NC}"
    echo -e "${RED}已备份您的主配置文件到 ${NGINX_MAIN_CONF}.bak_*${NC}"
    exit 1
fi
