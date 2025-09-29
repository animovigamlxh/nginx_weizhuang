#!/bin/bash

# Nginx Fallback 一键配置脚本
# 用于配合 XrayR 的 Fallback 功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本必须以 root 权限运行"
        exit 1
    fi
}

# 检测系统类型
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        print_error "无法检测系统类型"
        exit 1
    fi
}

# 安装 Nginx
install_nginx() {
    print_info "检查 Nginx 安装状态..."
    
    if command -v nginx &> /dev/null; then
        print_success "Nginx 已安装"
        nginx -v
        return 0
    fi
    
    print_info "正在安装 Nginx..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y nginx
            ;;
        centos|rhel|fedora)
            yum install -y nginx || dnf install -y nginx
            ;;
        *)
            print_error "不支持的系统: $OS"
            exit 1
            ;;
    esac
    
    print_success "Nginx 安装完成"
}

# 安装 PHP-FPM (可选)
install_php() {
    local install_php=$1
    
    if [[ "$install_php" != "y" ]]; then
        return 0
    fi
    
    print_info "正在安装 PHP-FPM..."
    
    case $OS in
        ubuntu|debian)
            apt-get install -y php-fpm php-cli php-mysql php-curl php-json php-mbstring
            PHP_FPM_SOCK=$(find /run/php -name "php*.sock" | head -n 1)
            ;;
        centos|rhel|fedora)
            yum install -y php-fpm php-cli php-mysqlnd php-curl php-json php-mbstring || \
            dnf install -y php-fpm php-cli php-mysqlnd php-curl php-json php-mbstring
            PHP_FPM_SOCK="/run/php-fpm/www.sock"
            ;;
    esac
    
    systemctl enable php-fpm
    systemctl start php-fpm
    
    print_success "PHP-FPM 安装完成"
}

# 创建网站目录
create_web_directory() {
    local web_root=$1
    
    print_info "创建网站目录: $web_root"
    
    mkdir -p "$web_root"
    
    # 创建默认 index.html
    cat > "$web_root/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            text-align: center;
            color: white;
        }
        h1 {
            font-size: 3em;
            margin-bottom: 0.5em;
        }
        p {
            font-size: 1.2em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 网站运行正常</h1>
        <p>Nginx Fallback 配置成功</p>
    </div>
</body>
</html>
EOF
    
    # 设置权限
    chown -R www-data:www-data "$web_root" 2>/dev/null || chown -R nginx:nginx "$web_root" 2>/dev/null
    chmod -R 755 "$web_root"
    
    print_success "网站目录创建完成"
}

# 生成 Nginx 配置
generate_nginx_config() {
    local domain=$1
    local port=$2
    local web_root=$3
    local enable_php=$4
    local enable_http2=$5
    local enable_proxy_protocol=$6
    local proxy_target=$7
    
    local config_file="/etc/nginx/sites-available/fallback-${port}.conf"
    local http2_option=""
    local proxy_protocol_option=""
    local location_block=""
    
    # HTTP/2 支持
    if [[ "$enable_http2" == "y" ]]; then
        http2_option=" http2"
    fi
    
    # PROXY Protocol 支持
    if [[ "$enable_proxy_protocol" == "y" ]]; then
        proxy_protocol_option="    # PROXY Protocol 配置
    set_real_ip_from 127.0.0.1;
    set_real_ip_from ::1;
    real_ip_header proxy_protocol;
    "
    fi
    
    # 反向代理模式
    if [[ -n "$proxy_target" ]]; then
        location_block="
    # 反向代理配置
    location / {
        proxy_pass ${proxy_target};
        proxy_set_header Host \$proxy_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Accept-Encoding \"\";
        proxy_redirect off;
        
        # 缓冲配置
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # 超时配置
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # SSL 配置 (如果目标是 HTTPS)
        proxy_ssl_server_name on;
        proxy_ssl_protocols TLSv1.2 TLSv1.3;
    }"
    else
        # 本地网站模式
        local php_block=""
        if [[ "$enable_php" == "y" && -n "$PHP_FPM_SOCK" ]]; then
            php_block="
    
    location ~ \\.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_FPM_SOCK};
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }"
        fi
        
        location_block="
    # 主要位置块
    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }
${php_block}
    
    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control \"public, immutable\";
    }"
    fi
    
    # 生成配置文件
    cat > "$config_file" << EOF
server {
    listen ${port}${http2_option};
    listen [::]:${port}${http2_option};
    
    server_name ${domain};
EOF

    # 只在本地网站模式添加 root
    if [[ -z "$proxy_target" ]]; then
        echo "    root ${web_root};" >> "$config_file"
        echo "    index index.php index.html index.htm;" >> "$config_file"
    fi

    cat >> "$config_file" << EOF
    
${proxy_protocol_option}
    # 日志配置
    access_log /var/log/nginx/fallback-${port}-access.log;
    error_log /var/log/nginx/fallback-${port}-error.log;
    
    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
${location_block}
    
    # 隐藏敏感文件
    location ~ /\\.(?!well-known).* {
        deny all;
    }
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF
    
    print_success "配置文件已生成: $config_file"
    
    # 创建符号链接
    if [[ -d "/etc/nginx/sites-enabled" ]]; then
        ln -sf "$config_file" "/etc/nginx/sites-enabled/"
    fi
}

# 测试并重载 Nginx
reload_nginx() {
    print_info "测试 Nginx 配置..."
    
    if nginx -t; then
        print_success "Nginx 配置测试通过"
        print_info "重载 Nginx..."
        systemctl reload nginx
        print_success "Nginx 已重载"
    else
        print_error "Nginx 配置测试失败"
        exit 1
    fi
}

# 显示配置信息
show_config_info() {
    local domain=$1
    local port=$2
    local web_root=$3
    local proxy_target=$4
    
    echo ""
    print_success "================================"
    print_success "Nginx Fallback 配置完成！"
    print_success "================================"
    echo ""
    echo -e "${GREEN}配置信息:${NC}"
    echo -e "  域名: ${YELLOW}${domain}${NC}"
    echo -e "  端口: ${YELLOW}${port}${NC}"
    
    if [[ -n "$proxy_target" ]]; then
        echo -e "  模式: ${YELLOW}反向代理${NC}"
        echo -e "  代理目标: ${YELLOW}${proxy_target}${NC}"
    else
        echo -e "  模式: ${YELLOW}本地网站${NC}"
        echo -e "  网站目录: ${YELLOW}${web_root}${NC}"
    fi
    
    echo -e "  配置文件: ${YELLOW}/etc/nginx/sites-available/fallback-${port}.conf${NC}"
    echo ""
    echo -e "${GREEN}XrayR 配置示例:${NC}"
    echo -e "${YELLOW}EnableFallback: true${NC}"
    echo -e "${YELLOW}FallBackConfigs:${NC}"
    echo -e "${YELLOW}  -${NC}"
    echo -e "${YELLOW}    SNI:${NC}"
    echo -e "${YELLOW}    Path:${NC}"
    echo -e "${YELLOW}    Dest: ${port}${NC}"
    echo -e "${YELLOW}    ProxyProtocolVer: 0${NC}"
    echo ""
    echo -e "${GREEN}测试命令:${NC}"
    echo -e "  ${YELLOW}curl http://127.0.0.1:${port}${NC}"
    
    if [[ -n "$proxy_target" ]]; then
        echo -e "  ${YELLOW}curl -L http://127.0.0.1:${port} -H \"Host: $(echo $proxy_target | sed 's|https\?://||')\"${NC}"
    fi
    echo ""
}

# 主菜单
main_menu() {
    clear
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Nginx Fallback 一键配置脚本  ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    # 回落模式选择
    echo -e "${GREEN}选择回落模式:${NC}"
    echo "  1) 本地网站 (自定义网站目录)"
    echo "  2) 反向代理到 bing.com (默认)"
    echo "  3) 反向代理到自定义网站"
    read -p "请选择 (1/2/3, 默认: 2): " fallback_mode
    fallback_mode=${fallback_mode:-2}
    
    # 域名
    read -p "请输入域名 (默认: localhost): " domain
    domain=${domain:-localhost}
    
    # 端口
    read -p "请输入监听端口 (默认: 8080): " port
    port=${port:-8080}
    
    # 根据模式设置
    if [[ "$fallback_mode" == "1" ]]; then
        # 网站目录
        read -p "请输入网站根目录 (默认: /var/www/fallback): " web_root
        web_root=${web_root:-/var/www/fallback}
        
        # PHP 支持
        read -p "是否安装 PHP-FPM? (y/n, 默认: n): " install_php
        install_php=${install_php:-n}
        
        proxy_target=""
    elif [[ "$fallback_mode" == "2" ]]; then
        proxy_target="https://www.bing.com"
        web_root=""
        install_php="n"
        print_info "将回落到: $proxy_target"
    else
        read -p "请输入反向代理目标 (如: https://www.google.com): " proxy_target
        web_root=""
        install_php="n"
    fi
    
    # HTTP/2 支持
    read -p "是否启用 HTTP/2? (y/n, 默认: y): " enable_http2
    enable_http2=${enable_http2:-y}
    
    # PROXY Protocol
    read -p "是否启用 PROXY Protocol 支持? (y/n, 默认: n): " enable_proxy_protocol
    enable_proxy_protocol=${enable_proxy_protocol:-n}
    
    echo ""
    print_info "开始配置..."
    echo ""
    
    # 执行安装和配置
    install_nginx
    
    if [[ "$fallback_mode" == "1" ]]; then
        install_php "$install_php"
        create_web_directory "$web_root"
    fi
    
    generate_nginx_config "$domain" "$port" "$web_root" "$install_php" "$enable_http2" "$enable_proxy_protocol" "$proxy_target"
    reload_nginx
    show_config_info "$domain" "$port" "$web_root" "$proxy_target"
}

# 主程序入口
main() {
    check_root
    detect_os
    main_menu
}

# 运行主程序
main
