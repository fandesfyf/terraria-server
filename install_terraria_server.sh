#!/bin/bash

# Terraria服务器一键安装配置脚本
# 作者: AI Assistant
# 版本: 1.0

# set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用root用户运行此脚本！"
        log_info "请使用普通用户运行，脚本会在需要时请求sudo权限"
        exit 1
    fi
}

# 检测Linux发行版
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        log_error "无法检测Linux发行版"
        exit 1
    fi
    
    log_info "检测到系统: $PRETTY_NAME"
}

# 安装依赖包
install_dependencies() {
    log_info "安装必要的依赖包..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y wget tmux unzip curl tmux
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y wget tmux unzip curl
            else
                sudo yum install -y wget tmux unzip curl
            fi
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm wget tmux unzip curl
            ;;
        *)
            log_warning "未识别的发行版，请手动安装: wget, tmux, unzip, curl"
            ;;
    esac
    
    log_success "依赖包安装完成"
}

# 获取Terraria服务器版本信息
get_terraria_version() {
    log_info "获取Terraria最新版本信息..."
    
    # 尝试从官方API获取版本信息
    VERSION_URL="https://terraria.org/api/download/pc-dedicated-server/terraria-server-latest.zip"
    
    # 如果无法获取最新版本，使用已知的稳定版本
    TERRARIA_VERSION="1449"
    TERRARIA_URL="https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip"
    
    log_info "将下载Terraria服务器版本: $TERRARIA_VERSION"
}

# 下载并安装Terraria服务器
install_terraria() {
    log_info "开始下载Terraria服务器..."
    
    # 创建安装目录
    INSTALL_DIR="$HOME/terraria-server"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 下载服务器文件
    if [ ! -f "terraria-server-${TERRARIA_VERSION}.zip" ]; then
        log_info "下载Terraria服务器文件..."
        wget -O "terraria-server-${TERRARIA_VERSION}.zip" "$TERRARIA_URL" || {
            log_error "下载失败，请检查网络连接"
            exit 1
        }
    else
        log_info "服务器文件已存在，跳过下载"
    fi
    
    # 解压文件
    log_info "解压服务器文件..."
    unzip -o "terraria-server-${TERRARIA_VERSION}.zip"
    mv "${TERRARIA_VERSION}" "terraria-server-${TERRARIA_VERSION}"
    
    # 设置权限
    chmod +x "terraria-server-${TERRARIA_VERSION}/Linux/TerrariaServer.bin.x86_64"
    
    log_success "Terraria服务器安装完成"
}

# 交互式配置
configure_server() {
    log_info "开始配置服务器..."
    
    # 获取用户输入
    echo
    read -p "请输入服务器名称 [MyTerrariaServer]: " SERVER_NAME
    SERVER_NAME=${SERVER_NAME:-MyTerrariaServer}
    
    read -p "请输入最大玩家数 [8]: " MAX_PLAYERS
    MAX_PLAYERS=${MAX_PLAYERS:-8}
    
    read -p "请输入服务器端口 [7777]: " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-7777}
    
    read -p "请输入服务器密码 (留空表示无密码): " SERVER_PASSWORD
    
    echo
    echo "请选择世界大小:"
    echo "1) 小世界 (1)"
    echo "2) 中世界 (2)"
    echo "3) 大世界 (3)"
    read -p "请选择 [3]: " WORLD_SIZE_CHOICE
    case $WORLD_SIZE_CHOICE in
        1) WORLD_SIZE=1 ;;
        2) WORLD_SIZE=2 ;;
        *) WORLD_SIZE=3 ;;
    esac
    
    echo
    echo "请选择难度:"
    echo "1) 经典 (0)"
    echo "2) 专家 (1)"
    echo "3) 大师 (2)"
    read -p "请选择 [0]: " DIFFICULTY_CHOICE
    case $DIFFICULTY_CHOICE in
        1) DIFFICULTY=1 ;;
        2) DIFFICULTY=2 ;;
        *) DIFFICULTY=0 ;;
    esac
    
    read -p "请输入欢迎消息 [欢迎来到我的Terraria服务器！]: " MOTD
    MOTD=${MOTD:-欢迎来到我的Terraria服务器！}
    
    # 创建世界目录
    mkdir -p "$INSTALL_DIR/worlds"
    
    # 生成配置文件
    log_info "生成服务器配置文件..."
    cat > "$INSTALL_DIR/serverconfig.txt" << EOF
world=$INSTALL_DIR/worlds/${SERVER_NAME}.wld
autocreate=$WORLD_SIZE
worldname=$SERVER_NAME
difficulty=$DIFFICULTY
maxplayers=$MAX_PLAYERS
port=$SERVER_PORT
password=$SERVER_PASSWORD
motd=$MOTD
worldpath=$INSTALL_DIR/worlds
banlist=$INSTALL_DIR/banlist.txt
EOF
    
    log_success "服务器配置完成"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 启动脚本
    cat > "$INSTALL_DIR/start_terraria.sh" << 'EOF'
#!/bin/bash
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR/terraria-server-1449/Linux"

if tmux has-session -t terraria 2>/dev/null; then
    echo "Terraria服务器已在运行中"
    echo "使用 'tmux attach-session -t terraria' 连接到控制台"
else
    tmux new-session -d -s terraria './TerrariaServer.bin.x86_64 -config '"$INSTALL_DIR"'/serverconfig.txt'
    echo "Terraria服务器已启动"
    echo "使用 'tmux attach-session -t terraria' 连接到控制台"
    echo "使用 'tmux detach' 或 Ctrl+B 然后 D 来分离会话"
fi
EOF

    # 停止脚本
    cat > "$INSTALL_DIR/stop_terraria.sh" << 'EOF'
#!/bin/bash
if tmux has-session -t terraria 2>/dev/null; then
    tmux send-keys -t terraria "exit" Enter
    sleep 2
    tmux kill-session -t terraria 2>/dev/null || true
    echo "Terraria服务器已停止"
else
    echo "Terraria服务器未运行"
fi
EOF

    # 状态检查脚本
    cat > "$INSTALL_DIR/status_terraria.sh" << 'EOF'
#!/bin/bash
if tmux has-session -t terraria 2>/dev/null; then
    echo "Terraria服务器状态: 运行中"
    echo "使用 'tmux attach-session -t terraria' 连接到控制台"
else
    echo "Terraria服务器状态: 未运行"
    echo "使用 './start_terraria.sh' 启动服务器"
fi
EOF

    # 重启脚本
    cat > "$INSTALL_DIR/restart_terraria.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "正在重启Terraria服务器..."
"$SCRIPT_DIR/stop_terraria.sh"
sleep 3
"$SCRIPT_DIR/start_terraria.sh"
EOF

    # 设置脚本权限
    chmod +x "$INSTALL_DIR"/*.sh
    
    log_success "管理脚本创建完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # 检测防火墙类型
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian UFW
        sudo ufw allow $SERVER_PORT/tcp
        sudo ufw reload
        log_success "UFW防火墙规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewalld
        sudo firewall-cmd --permanent --add-port=$SERVER_PORT/tcp
        sudo firewall-cmd --reload
        log_success "firewalld防火墙规则已添加"
    elif command -v iptables &> /dev/null; then
        # iptables
        sudo iptables -A INPUT -p tcp --dport $SERVER_PORT -j ACCEPT
        log_success "iptables防火墙规则已添加"
        log_warning "请手动保存iptables规则: sudo iptables-save > /etc/iptables/rules.v4"
    else
        log_warning "未检测到防火墙，请手动开放端口 $SERVER_PORT"
    fi
}

# 创建systemd服务
create_systemd_service() {
    read -p "是否创建systemd服务以实现开机自启？[y/N]: " CREATE_SERVICE
    if [[ $CREATE_SERVICE =~ ^[Yy]$ ]]; then
        log_info "创建systemd服务..."
        
        sudo tee /etc/systemd/system/terraria.service > /dev/null << EOF
[Unit]
Description=Terraria Server
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$INSTALL_DIR/terraria-server-1449/Linux
ExecStart=$INSTALL_DIR/start_terraria.sh
ExecStop=$INSTALL_DIR/stop_terraria.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable terraria
        
        log_success "systemd服务创建完成"
        log_info "使用 'sudo systemctl start terraria' 启动服务"
        log_info "使用 'sudo systemctl stop terraria' 停止服务"
    fi
}

# 显示安装完成信息
show_completion_info() {
    echo
    log_success "=========================================="
    log_success "Terraria服务器安装配置完成！"
    log_success "=========================================="
    echo
    log_info "安装目录: $INSTALL_DIR"
    log_info "服务器名称: $SERVER_NAME"
    log_info "最大玩家数: $MAX_PLAYERS"
    log_info "服务器端口: $SERVER_PORT"
    log_info "世界大小: $WORLD_SIZE"
    log_info "难度: $DIFFICULTY"
    echo
    log_info "管理命令:"
    log_info "  启动服务器: $INSTALL_DIR/start_terraria.sh"
    log_info "  停止服务器: $INSTALL_DIR/stop_terraria.sh"
    log_info "  重启服务器: $INSTALL_DIR/restart_terraria.sh"
    log_info "  查看状态: $INSTALL_DIR/status_terraria.sh"
    log_info "  连接控制台: tmux attach-session -t terraria"
    echo
    log_info "连接服务器:"
    log_info "  在Terraria游戏中选择'多人游戏' -> '通过IP加入'"
    log_info "  输入服务器IP: $SERVER_PORT"
    if [ -n "$SERVER_PASSWORD" ]; then
        log_info "  密码: $SERVER_PASSWORD"
    fi
    echo
    log_info "首次启动时会自动创建世界，请耐心等待"
    echo
    read -p "是否现在启动服务器？[Y/n]: " START_NOW
    if [[ ! $START_NOW =~ ^[Nn]$ ]]; then
        "$INSTALL_DIR/start_terraria.sh"
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "    Terraria服务器一键安装配置脚本"
    echo "=========================================="
    echo
    
    check_root
    detect_distro
    install_dependencies
    get_terraria_version
    install_terraria
    configure_server
    create_management_scripts
    configure_firewall
    create_systemd_service
    show_completion_info
}

# 运行主函数
main "$@"
