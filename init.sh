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

# 创建搜索引擎风格页面
create_search_page() {
    local web_root=$1
    cat > "$web_root/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>搜索</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
            background: #fff;
            color: #202124;
            display: flex;
            flex-direction: column;
            min-height: 100vh;
        }
        .header {
            padding: 20px 40px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .logo {
            font-size: 24px;
            font-weight: 600;
            color: #4285f4;
        }
        .nav-links {
            display: flex;
            gap: 20px;
        }
        .nav-links a {
            color: #5f6368;
            text-decoration: none;
            font-size: 13px;
        }
        .nav-links a:hover {
            text-decoration: underline;
        }
        .main {
            flex: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            padding: 0 20px;
            margin-top: -100px;
        }
        .search-logo {
            font-size: 72px;
            font-weight: 300;
            margin-bottom: 30px;
            color: #4285f4;
        }
        .search-box {
            width: 100%;
            max-width: 584px;
            margin-bottom: 30px;
        }
        .search-input {
            width: 100%;
            padding: 14px 16px;
            font-size: 16px;
            border: 1px solid #dfe1e5;
            border-radius: 24px;
            outline: none;
            transition: box-shadow 0.2s;
        }
        .search-input:hover {
            box-shadow: 0 1px 6px rgba(32,33,36,.28);
            border-color: rgba(223,225,229,0);
        }
        .search-input:focus {
            box-shadow: 0 1px 6px rgba(32,33,36,.28);
            border-color: rgba(223,225,229,0);
        }
        .buttons {
            display: flex;
            gap: 12px;
            margin-top: 20px;
        }
        .btn {
            background: #f8f9fa;
            border: 1px solid #f8f9fa;
            padding: 10px 16px;
            font-size: 14px;
            color: #3c4043;
            border-radius: 4px;
            cursor: pointer;
            transition: all 0.1s;
        }
        .btn:hover {
            box-shadow: 0 1px 1px rgba(0,0,0,.1);
            background: #f8f9fa;
            border: 1px solid #dadce0;
            color: #202124;
        }
        .footer {
            background: #f2f2f2;
            padding: 15px 30px;
            font-size: 14px;
            color: #70757a;
            border-top: 1px solid #dadce0;
        }
        .footer-row {
            display: flex;
            justify-content: space-between;
            padding: 12px 0;
        }
        .footer-links {
            display: flex;
            gap: 30px;
        }
        .footer-links a {
            color: #70757a;
            text-decoration: none;
        }
        .footer-links a:hover {
            text-decoration: underline;
        }
        @media (max-width: 768px) {
            .search-logo {
                font-size: 48px;
            }
            .footer-row {
                flex-direction: column;
                gap: 15px;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="logo">Search</div>
        <div class="nav-links">
            <a href="#">关于</a>
            <a href="#">产品</a>
        </div>
    </div>
    
    <div class="main">
        <div class="search-logo">Search</div>
        <div class="search-box">
            <input type="text" class="search-input" placeholder="搜索或输入网址">
        </div>
        <div class="buttons">
            <button class="btn">搜索</button>
            <button class="btn">手气不错</button>
        </div>
    </div>
    
    <div class="footer">
        <div class="footer-row">
            <div class="footer-links">
                <a href="#">广告</a>
                <a href="#">商务</a>
            </div>
            <div class="footer-links">
                <a href="#">隐私权</a>
                <a href="#">条款</a>
                <a href="#">设置</a>
            </div>
        </div>
    </div>
</body>
</html>
EOF
}

# 创建博客风格页面
create_blog_page() {
    local web_root=$1
    cat > "$web_root/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>个人博客</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
        }
        .header {
            background: #fff;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            padding: 20px 0;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
        }
        .nav {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .logo {
            font-size: 24px;
            font-weight: bold;
            color: #2c3e50;
        }
        .nav-links {
            display: flex;
            gap: 30px;
        }
        .nav-links a {
            color: #555;
            text-decoration: none;
            transition: color 0.3s;
        }
        .nav-links a:hover {
            color: #3498db;
        }
        .hero {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 80px 0;
            text-align: center;
        }
        .hero h1 {
            font-size: 48px;
            margin-bottom: 20px;
        }
        .hero p {
            font-size: 20px;
            opacity: 0.9;
        }
        .content {
            padding: 60px 0;
        }
        .posts {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 30px;
            margin-top: 40px;
        }
        .post-card {
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }
        .post-card:hover {
            transform: translateY(-5px);
        }
        .post-image {
            width: 100%;
            height: 200px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .post-content {
            padding: 25px;
        }
        .post-title {
            font-size: 22px;
            margin-bottom: 10px;
            color: #2c3e50;
        }
        .post-meta {
            color: #999;
            font-size: 14px;
            margin-bottom: 15px;
        }
        .post-excerpt {
            color: #666;
            line-height: 1.6;
        }
        .footer {
            background: #2c3e50;
            color: white;
            text-align: center;
            padding: 30px 0;
            margin-top: 60px;
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="container">
            <nav class="nav">
                <div class="logo">我的博客</div>
                <div class="nav-links">
                    <a href="#">首页</a>
                    <a href="#">文章</a>
                    <a href="#">关于</a>
                    <a href="#">联系</a>
                </div>
            </nav>
        </div>
    </header>

    <section class="hero">
        <div class="container">
            <h1>欢迎来到我的博客</h1>
            <p>分享技术，记录生活</p>
        </div>
    </section>

    <section class="content">
        <div class="container">
            <h2>最新文章</h2>
            <div class="posts">
                <div class="post-card">
                    <div class="post-image"></div>
                    <div class="post-content">
                        <h3 class="post-title">技术分享：现代Web开发</h3>
                        <div class="post-meta">2025年9月30日 · 5分钟阅读</div>
                        <p class="post-excerpt">探索现代Web开发的最佳实践，包括前端框架、性能优化和用户体验设计...</p>
                    </div>
                </div>
                <div class="post-card">
                    <div class="post-image"></div>
                    <div class="post-content">
                        <h3 class="post-title">云计算入门指南</h3>
                        <div class="post-meta">2025年9月28日 · 8分钟阅读</div>
                        <p class="post-excerpt">从零开始了解云计算的基本概念，以及如何选择适合的云服务平台...</p>
                    </div>
                </div>
                <div class="post-card">
                    <div class="post-image"></div>
                    <div class="post-content">
                        <h3 class="post-title">编程思维的培养</h3>
                        <div class="post-meta">2025年9月25日 · 6分钟阅读</div>
                        <p class="post-excerpt">如何培养良好的编程思维，提高代码质量和开发效率...</p>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <footer class="footer">
        <div class="container">
            <p>&copy; 2025 我的博客. 保留所有权利.</p>
        </div>
    </footer>
</body>
</html>
EOF
}

# 创建商业网站风格页面
create_business_page() {
    local web_root=$1
    cat > "$web_root/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>企业官网</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }
        .header {
            background: rgba(255, 255, 255, 0.95);
            position: fixed;
            width: 100%;
            top: 0;
            z-index: 1000;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .nav {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .logo {
            font-size: 24px;
            font-weight: bold;
            color: #2c3e50;
        }
        .nav-links {
            display: flex;
            gap: 30px;
        }
        .nav-links a {
            color: #555;
            text-decoration: none;
            transition: color 0.3s;
        }
        .nav-links a:hover {
            color: #3498db;
        }
        .hero {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 150px 20px 100px;
            text-align: center;
            margin-top: 70px;
        }
        .hero h1 {
            font-size: 56px;
            margin-bottom: 20px;
            font-weight: 700;
        }
        .hero p {
            font-size: 24px;
            margin-bottom: 40px;
            opacity: 0.9;
        }
        .cta-button {
            display: inline-block;
            padding: 15px 40px;
            background: white;
            color: #667eea;
            text-decoration: none;
            border-radius: 50px;
            font-weight: 600;
            transition: transform 0.3s;
        }
        .cta-button:hover {
            transform: scale(1.05);
        }
        .features {
            padding: 80px 20px;
            max-width: 1200px;
            margin: 0 auto;
        }
        .features h2 {
            text-align: center;
            font-size: 42px;
            margin-bottom: 60px;
            color: #2c3e50;
        }
        .feature-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 40px;
        }
        .feature-item {
            text-align: center;
            padding: 30px;
        }
        .feature-icon {
            width: 80px;
            height: 80px;
            margin: 0 auto 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 36px;
            color: white;
        }
        .feature-title {
            font-size: 24px;
            margin-bottom: 15px;
            color: #2c3e50;
        }
        .feature-desc {
            color: #666;
            line-height: 1.6;
        }
        .footer {
            background: #2c3e50;
            color: white;
            padding: 40px 20px;
            text-align: center;
        }
    </style>
</head>
<body>
    <header class="header">
        <nav class="nav">
            <div class="logo">企业名称</div>
            <div class="nav-links">
                <a href="#">首页</a>
                <a href="#">产品</a>
                <a href="#">解决方案</a>
                <a href="#">关于我们</a>
                <a href="#">联系</a>
            </div>
        </nav>
    </header>

    <section class="hero">
        <h1>创新科技，引领未来</h1>
        <p>为企业提供专业的数字化解决方案</p>
        <a href="#" class="cta-button">立即咨询</a>
    </section>

    <section class="features">
        <h2>我们的优势</h2>
        <div class="feature-grid">
            <div class="feature-item">
                <div class="feature-icon">🚀</div>
                <h3 class="feature-title">高效创新</h3>
                <p class="feature-desc">采用最新技术栈，为客户提供高效的解决方案，助力企业数字化转型。</p>
            </div>
            <div class="feature-item">
                <div class="feature-icon">💡</div>
                <h3 class="feature-title">专业团队</h3>
                <p class="feature-desc">汇集行业精英，拥有丰富的项目经验和专业技术能力。</p>
            </div>
            <div class="feature-item">
                <div class="feature-icon">🎯</div>
                <h3 class="feature-title">定制服务</h3>
                <p class="feature-desc">深入了解客户需求，提供个性化的定制服务和长期技术支持。</p>
            </div>
        </div>
    </section>

    <footer class="footer">
        <p>&copy; 2025 企业名称. 保留所有权利.</p>
    </footer>
</body>
</html>
EOF
}

# 创建默认页面
create_default_page() {
    local web_root=$1
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
}

# 创建网站目录
create_web_directory() {
    local web_root=$1
    local page_type=$2
    
    print_info "创建网站目录: $web_root"
    
    mkdir -p "$web_root"
    
    # 根据类型创建不同的伪装页面
    case $page_type in
        "search")
            create_search_page "$web_root"
            ;;
        "blog")
            create_blog_page "$web_root"
            ;;
        "business")
            create_business_page "$web_root"
            ;;
        *)
            create_default_page "$web_root"
            ;;
    esac
    
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
    local enable_http2=$4
    local enable_proxy_protocol=$5
    
    local config_file="/etc/nginx/sites-available/fallback-${port}.conf"
    local http2_option=""
    local proxy_protocol_option=""
    
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
    
    # 生成配置文件
    cat > "$config_file" << EOF
server {
    listen ${port}${http2_option};
    listen [::]:${port}${http2_option};
    
    server_name ${domain};
    root ${web_root};
    index index.html index.htm;
    
${proxy_protocol_option}
    # 日志配置
    access_log /var/log/nginx/fallback-${port}-access.log;
    error_log /var/log/nginx/fallback-${port}-error.log;
    
    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
    
    # 主要位置块
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
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
    local page_style=$4
    
    local style_name=""
    case $page_style in
        "search") style_name="搜索引擎风格" ;;
        "blog") style_name="个人博客风格" ;;
        "business") style_name="企业官网风格" ;;
        *) style_name="简单欢迎页面" ;;
    esac
    
    echo ""
    print_success "================================"
    print_success "Nginx Fallback 配置完成！"
    print_success "================================"
    echo ""
    echo -e "${GREEN}配置信息:${NC}"
    echo -e "  域名: ${YELLOW}${domain}${NC}"
    echo -e "  端口: ${YELLOW}${port}${NC}"
    echo -e "  伪装类型: ${YELLOW}${style_name}${NC}"
    echo -e "  网站目录: ${YELLOW}${web_root}${NC}"
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
    echo -e "  ${YELLOW}curl -I http://127.0.0.1:${port}${NC}"
    echo ""
    echo -e "${GREEN}提示:${NC}"
    echo -e "  - 伪装页面位于: ${YELLOW}${web_root}/index.html${NC}"
    echo -e "  - 您可以随时编辑该文件来自定义页面内容"
    echo -e "  - 重启 Nginx: ${YELLOW}systemctl reload nginx${NC}"
    echo ""
}

# 主菜单
main_menu() {
    clear
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Nginx Fallback 一键配置脚本  ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    # 伪装页面类型选择
    echo -e "${GREEN}选择伪装页面类型:${NC}"
    echo "  1) 搜索引擎风格 (类似 Google/Bing)"
    echo "  2) 个人博客风格"
    echo "  3) 企业官网风格"
    echo "  4) 简单欢迎页面"
    read -p "请选择 (1/2/3/4, 默认: 1): " page_type
    page_type=${page_type:-1}
    
    case $page_type in
        1) page_style="search" ;;
        2) page_style="blog" ;;
        3) page_style="business" ;;
        *) page_style="default" ;;
    esac
    
    # 域名
    read -p "请输入域名 (默认: localhost): " domain
    domain=${domain:-localhost}
    
    # 端口
    read -p "请输入监听端口 (默认: 8080): " port
    port=${port:-8080}
    
    # 网站目录
    read -p "请输入网站根目录 (默认: /var/www/fallback): " web_root
    web_root=${web_root:-/var/www/fallback}
    
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
    create_web_directory "$web_root" "$page_style"
    generate_nginx_config "$domain" "$port" "$web_root" "$enable_http2" "$enable_proxy_protocol"
    reload_nginx
    show_config_info "$domain" "$port" "$web_root" "$page_style"
}

# 主程序入口
main() {
    check_root
    detect_os
    main_menu
}

# 运行主程序
main
