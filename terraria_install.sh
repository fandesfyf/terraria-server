#!/bin/bash

# Terraria服务器安装脚本
# 作者: AI Assistant
# 版本: 2.0
# 功能: 安装Terraria服务器到当前仓库的Server目录

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/Server"
TERRARIA_VERSION="1449"

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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    clear
    echo "=========================================="
    echo "    Terraria服务器安装工具 v2.0"
    echo "=========================================="
    echo
    log_info "本工具将安装Terraria服务器到当前仓库的Server目录"
    log_info "安装目录: $SERVER_DIR"
    echo
    read -p "按回车键继续安装..."
    echo
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
    log_step "检测系统环境..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        log_error "无法检测Linux发行版"
        exit 1
    fi
    
    log_success "检测到系统: $PRETTY_NAME"
}

# 安装依赖包
install_dependencies() {
    log_step "安装必要的依赖包..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y wget tmux unzip curl jq lsof
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y wget tmux unzip curl jq lsof
            else
                sudo yum install -y wget tmux unzip curl jq lsof
            fi
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm wget tmux unzip curl jq lsof
            ;;
        *)
            log_warning "未识别的发行版，请手动安装: wget, tmux, unzip, curl, jq, lsof"
            read -p "是否已安装所需依赖？[y/N]: " DEPS_INSTALLED
            if [[ ! $DEPS_INSTALLED =~ ^[Yy]$ ]]; then
                log_error "请先安装依赖包后重新运行脚本"
                exit 1
            fi
            ;;
    esac
    
    log_success "依赖包安装完成"
}

# 创建目录结构
create_directory_structure() {
    log_step "创建目录结构..."
    
    # 创建主目录结构
    mkdir -p "$SERVER_DIR"/{bin,worlds,configs,logs,scripts,backups}
    
    log_info "创建的目录结构:"
    log_info "  $SERVER_DIR/bin      - Terraria服务器程序"
    log_info "  $SERVER_DIR/worlds   - 世界文件和配置"
    log_info "  $SERVER_DIR/configs  - 全局配置文件"
    log_info "  $SERVER_DIR/logs     - 日志文件"
    log_info "  $SERVER_DIR/scripts  - 管理脚本"
    log_info "  $SERVER_DIR/backups  - 备份文件"
    
    log_success "目录结构创建完成"
}

# 下载并安装Terraria服务器
download_terraria() {
    log_step "下载Terraria服务器..."
    
    cd "$SERVER_DIR/bin"
    
    # 检查是否已经下载
    if [ -f "terraria-server-${TERRARIA_VERSION}.zip" ]; then
        log_info "服务器文件已存在，跳过下载"
    else
        log_info "下载Terraria服务器 v${TERRARIA_VERSION}..."
        TERRARIA_URL="https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip"
        
        wget -O "terraria-server-${TERRARIA_VERSION}.zip" "$TERRARIA_URL" || {
            log_error "下载失败，请检查网络连接"
            exit 1
        }
    fi
    
    # 解压文件
    log_info "解压服务器文件..."
    if [ -d "${TERRARIA_VERSION}" ]; then
        rm -rf "${TERRARIA_VERSION}"
    fi
    
    unzip -q "terraria-server-${TERRARIA_VERSION}.zip"
    
    # 重命名目录
    if [ -d "${TERRARIA_VERSION}" ]; then
        mv "${TERRARIA_VERSION}" "terraria-server"
    fi
    
    # 设置权限
    chmod +x "terraria-server/Linux/TerrariaServer.bin.x86_64"
    
    log_success "Terraria服务器安装完成"
}

# 创建全局配置文件
create_global_config() {
    log_step "创建全局配置文件..."
    
    # 创建服务器全局配置
    cat > "$SERVER_DIR/configs/server_global.json" << EOF
{
  "terraria_version": "$TERRARIA_VERSION",
  "server_dir": "$SERVER_DIR",
  "default_settings": {
    "maxplayers": 8,
    "difficulty": 0,
    "world_size": 3,
    "motd": "欢迎来到我的Terraria服务器！",
    "secure": true,
    "language": "zh-Hans"
  },
  "port_range": {
    "start": 7777,
    "end": 7877
  },
  "auto_backup": {
    "enabled": true,
    "interval": 3600,
    "keep_backups": 10
  },
  "worlds": []
}
EOF

    # 创建世界模板配置
    cat > "$SERVER_DIR/configs/world_template.txt" << 'EOF'
# Terraria世界配置模板
# 复制此文件并重命名为 <世界名>.config 来创建新世界配置

world=WORLD_FILE_PATH
autocreate=WORLD_SIZE
worldname=WORLD_NAME
difficulty=DIFFICULTY
maxplayers=MAX_PLAYERS
port=PORT
password=PASSWORD
motd=MOTD
worldpath=WORLD_PATH
banlist=BAN_LIST_PATH
logpath=LOG_FILE_PATH
secure=1
language=zh-Hans
EOF

    log_success "全局配置文件创建完成"
}

# 创建基础管理脚本
create_base_scripts() {
    log_step "创建基础管理脚本..."
    
    # 创建世界启动脚本模板
    cat > "$SERVER_DIR/scripts/start_world_template.sh" << 'EOF'
#!/bin/bash
# Terraria世界启动脚本模板
# 此文件会被配置脚本自动修改

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"
WORLD_NAME="WORLD_NAME_PLACEHOLDER"
CONFIG_FILE="CONFIG_FILE_PLACEHOLDER"
TMUX_SESSION="TMUX_SESSION_PLACEHOLDER"

cd "$SERVER_DIR/bin/terraria-server/Linux"

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "世界 '$WORLD_NAME' 已在运行中"
    echo "使用 'tmux attach-session -t $TMUX_SESSION' 连接到控制台"
else
    echo "启动世界 '$WORLD_NAME'..."
    tmux new-session -d -s "$TMUX_SESSION" './TerrariaServer.bin.x86_64 -config '"$CONFIG_FILE"
    echo "世界 '$WORLD_NAME' 已启动"
    echo "使用 'tmux attach-session -t $TMUX_SESSION' 连接到控制台"
fi
EOF

    # 创建世界停止脚本模板
    cat > "$SERVER_DIR/scripts/stop_world_template.sh" << 'EOF'
#!/bin/bash
# Terraria世界停止脚本模板

WORLD_NAME="WORLD_NAME_PLACEHOLDER"
TMUX_SESSION="TMUX_SESSION_PLACEHOLDER"

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "停止世界 '$WORLD_NAME'..."
    tmux send-keys -t "$TMUX_SESSION" "exit" Enter
    sleep 2
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    echo "世界 '$WORLD_NAME' 已停止"
else
    echo "世界 '$WORLD_NAME' 未运行"
fi
EOF

    # 创建备份脚本
    cat > "$SERVER_DIR/scripts/backup_worlds.sh" << 'EOF'
#!/bin/bash
# Terraria世界备份脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$SERVER_DIR/backups"
DATE=$(date +"%Y%m%d_%H%M%S")

echo "开始备份世界文件..."
mkdir -p "$BACKUP_DIR/$DATE"

# 备份世界文件
if [ -d "$SERVER_DIR/worlds" ]; then
    cp -r "$SERVER_DIR/worlds" "$BACKUP_DIR/$DATE/"
    echo "世界文件已备份到: $BACKUP_DIR/$DATE/"
fi

# 清理旧备份（保留最近10个）
cd "$BACKUP_DIR"
ls -1t | tail -n +11 | xargs -r rm -rf

echo "备份完成"
EOF

    # 设置脚本权限
    chmod +x "$SERVER_DIR/scripts"/*.sh
    
    log_success "基础管理脚本创建完成"
}

# 创建systemd服务模板
create_systemd_template() {
    log_step "创建systemd服务模板..."
    
    cat > "$SERVER_DIR/configs/terraria@.service" << EOF
[Unit]
Description=Terraria Server - %i
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$SERVER_DIR/bin/terraria-server/Linux
ExecStart=$SERVER_DIR/scripts/start_%i.sh
ExecStop=$SERVER_DIR/scripts/stop_%i.sh
Restart=always
RestartSec=10
Environment=TERM=xterm

[Install]
WantedBy=multi-user.target
EOF

    log_info "systemd服务模板已创建: $SERVER_DIR/configs/terraria@.service"
    log_info "使用方法: sudo systemctl enable terraria@世界名"
    
    log_success "systemd服务模板创建完成"
}

# 显示安装完成信息
show_completion() {
    echo
    log_success "=========================================="
    log_success "Terraria服务器安装完成！"
    log_success "=========================================="
    echo
    log_info "安装目录: $SERVER_DIR"
    log_info "服务器版本: $TERRARIA_VERSION"
    echo
    log_info "目录结构:"
    log_info "  $SERVER_DIR/bin      - 服务器程序文件"
    log_info "  $SERVER_DIR/worlds   - 世界文件和配置"
    log_info "  $SERVER_DIR/configs  - 全局配置文件"
    log_info "  $SERVER_DIR/logs     - 服务器日志"
    log_info "  $SERVER_DIR/scripts  - 管理脚本"
    log_info "  $SERVER_DIR/backups  - 备份文件"
    echo
    log_info "下一步："
    log_info "  运行配置脚本来创建和管理世界:"
    log_info "  ./terraria_config.sh"
    echo
    
    # 检查是否存在现有世界文件
    if [ -f "$SCRIPT_DIR/可爱的树懒深沟.wld" ]; then
        log_info "发现现有世界文件: 可爱的树懒深沟.wld"
        read -p "是否将其移动到Server/worlds目录？[Y/n]: " MOVE_WORLD
        if [[ ! $MOVE_WORLD =~ ^[Nn]$ ]]; then
            mv "$SCRIPT_DIR/可爱的树懒深沟.wld" "$SERVER_DIR/worlds/"
            log_success "世界文件已移动到Server/worlds/"
        fi
    fi
    
    if [ -f "$SCRIPT_DIR/serverconfig.txt" ]; then
        log_info "发现现有配置文件: serverconfig.txt"
        read -p "是否将其移动到Server/worlds目录作为参考？[Y/n]: " MOVE_CONFIG
        if [[ ! $MOVE_CONFIG =~ ^[Nn]$ ]]; then
            mv "$SCRIPT_DIR/serverconfig.txt" "$SERVER_DIR/worlds/可爱的树懒深沟.config"
            log_success "配置文件已移动到Server/worlds/"
        fi
    fi
}

# 主函数
main() {
    show_welcome
    check_root
    detect_distro
    install_dependencies
    create_directory_structure
    download_terraria
    create_global_config
    create_base_scripts
    create_systemd_template
    show_completion
}

# 运行主函数
main "$@"
