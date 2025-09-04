#!/bin/bash

# Terraria新世界添加脚本
# 作者: AI Assistant
# 版本: 1.0
# 功能: 在现有Terraria服务器基础上添加新世界

# set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
INSTALL_DIR="$HOME/terraria-server"
WORLDS_CONFIG_FILE="$INSTALL_DIR/worlds_config.json"
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

log_tutorial() {
    echo -e "${CYAN}[教程]${NC} $1"
}

# 检查Terraria服务器是否已安装
check_terraria_installation() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "未找到Terraria服务器安装目录: $INSTALL_DIR"
        log_info "请先运行 install_terraria_server.sh 安装Terraria服务器"
        exit 1
    fi
    
    if [ ! -f "$INSTALL_DIR/terraria-server-${TERRARIA_VERSION}/Linux/TerrariaServer.bin.x86_64" ]; then
        log_error "未找到Terraria服务器可执行文件"
        log_info "请先运行 install_terraria_server.sh 安装Terraria服务器"
        exit 1
    fi
    
    log_success "Terraria服务器安装检查通过"
}

# 检查世界配置文件是否存在
check_worlds_config() {
    if [ ! -f "$WORLDS_CONFIG_FILE" ]; then
        log_warning "未找到世界配置文件，将创建新的配置文件"
        create_initial_worlds_config
    else
        log_info "找到现有世界配置文件: $WORLDS_CONFIG_FILE"
    fi
}

# 创建初始世界配置文件
create_initial_worlds_config() {
    log_info "创建初始世界配置文件..."
    
    # 检查是否有现有的serverconfig.txt
    if [ -f "$INSTALL_DIR/serverconfig.txt" ]; then
        log_info "发现现有服务器配置，正在转换..."
        
        # 从现有配置中提取信息
        SERVER_NAME=$(grep "^worldname=" "$INSTALL_DIR/serverconfig.txt" | cut -d'=' -f2)
        SERVER_PORT=$(grep "^port=" "$INSTALL_DIR/serverconfig.txt" | cut -d'=' -f2)
        MAX_PLAYERS=$(grep "^maxplayers=" "$INSTALL_DIR/serverconfig.txt" | cut -d'=' -f2)
        DIFFICULTY=$(grep "^difficulty=" "$INSTALL_DIR/serverconfig.txt" | cut -d'=' -f2)
        WORLD_SIZE=$(grep "^autocreate=" "$INSTALL_DIR/serverconfig.txt" | cut -d'=' -f2)
        PASSWORD=$(grep "^password=" "$INSTALL_DIR/serverconfig.txt" | cut -d'=' -f2)
        MOTD=$(grep "^motd=" "$INSTALL_DIR/serverconfig.txt" | cut -d'=' -f2)
        
        # 检查世界文件是否存在
        WORLD_FILE=$(grep "^world=" "$INSTALL_DIR/serverconfig.txt" | cut -d'=' -f2)
        WORLD_EXISTS="false"
        if [ -f "$WORLD_FILE" ]; then
            WORLD_EXISTS="true"
        fi
        
        # 创建JSON配置
        cat > "$WORLDS_CONFIG_FILE" << EOF
{
  "terraria_version": "$TERRARIA_VERSION",
  "install_dir": "$INSTALL_DIR",
  "worlds": [
    {
      "name": "$SERVER_NAME",
      "port": $SERVER_PORT,
      "config_file": "$INSTALL_DIR/serverconfig.txt",
      "world_file": "$WORLD_FILE",
      "log_file": "$INSTALL_DIR/logs/${SERVER_NAME}.log",
      "world_exists": $WORLD_EXISTS,
      "tmux_session": "terraria_${SERVER_NAME}"
    }
  ]
}
EOF
        
        # 创建必要的目录
        mkdir -p "$INSTALL_DIR/logs"
        mkdir -p "$INSTALL_DIR/configs"
        
        # 移动现有配置到configs目录
        mv "$INSTALL_DIR/serverconfig.txt" "$INSTALL_DIR/configs/${SERVER_NAME}_config.txt"
        
        # 更新JSON中的配置文件路径
        sed -i "s|$INSTALL_DIR/serverconfig.txt|$INSTALL_DIR/configs/${SERVER_NAME}_config.txt|g" "$WORLDS_CONFIG_FILE"
        
        log_success "已转换现有配置为多世界格式"
    else
        log_error "未找到现有服务器配置，无法创建初始配置"
        log_info "请先运行 install_terraria_server.sh 安装Terraria服务器"
        exit 1
    fi
}

# 检查端口是否已被使用
check_port_available() {
    local port="$1"
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # 端口被占用
    else
        return 0  # 端口可用
    fi
}

# 检查世界文件是否存在
check_world_exists() {
    local world_name="$1"
    local world_file="$INSTALL_DIR/worlds/${world_name}.wld"
    [ -f "$world_file" ]
}

# 获取下一个可用端口
get_next_available_port() {
    local start_port=7777
    local port=$start_port
    
    # 从现有配置中获取已使用的端口
    local used_ports=()
    if [ -f "$WORLDS_CONFIG_FILE" ]; then
        used_ports=($(jq -r '.worlds[].port' "$WORLDS_CONFIG_FILE" 2>/dev/null || echo ""))
    fi
    
    # 查找下一个可用端口
    while true; do
        local port_in_use=false
        
        # 检查是否在已配置的端口中
        for used_port in "${used_ports[@]}"; do
            if [ "$port" = "$used_port" ]; then
                port_in_use=true
                break
            fi
        done
        
        # 检查端口是否被系统占用
        if [ "$port_in_use" = false ] && check_port_available "$port"; then
            echo "$port"
            return
        fi
        
        port=$((port + 1))
        
        # 防止无限循环
        if [ $port -gt 9999 ]; then
            log_error "无法找到可用端口"
            exit 1
        fi
    done
}

# 显示配置引导教程
show_configuration_tutorial() {
    echo
    log_tutorial "=========================================="
    log_tutorial "        Terraria新世界配置引导教程"
    log_tutorial "=========================================="
    echo
    log_tutorial "欢迎使用Terraria新世界添加工具！"
    echo
    log_tutorial "本工具将帮助您："
    log_tutorial "1. 创建新的Terraria世界服务器"
    log_tutorial "2. 配置世界参数（大小、难度、玩家数等）"
    log_tutorial "3. 自动分配可用端口"
    log_tutorial "4. 检测现有世界文件并直接使用"
    log_tutorial "5. 更新防火墙配置"
    echo
    log_tutorial "配置完成后，您将获得："
    log_tutorial "- 独立的世界服务器实例"
    log_tutorial "- 专用的tmux会话管理"
    log_tutorial "  - 启动/停止/重启脚本"
    log_tutorial "  - 状态监控脚本"
    echo
    read -p "按回车键继续配置..."
    echo
}

# 显示现有世界信息
show_existing_worlds() {
    if [ -f "$WORLDS_CONFIG_FILE" ]; then
        log_info "当前已配置的世界："
        echo "=========================================="
        
        jq -r '.worlds[] | "世界名称: \(.name) | 端口: \(.port) | 状态: \(if .world_exists then "已存在" else "将创建" end)"' "$WORLDS_CONFIG_FILE" | while read -r line; do
            echo "  $line"
        done
        
        echo "=========================================="
        echo
    fi
}

# 交互式配置新世界
configure_new_world() {
    log_info "开始配置新世界..."
    echo
    
    # 显示现有世界
    show_existing_worlds
    
    # 获取世界名称
    while true; do
        read -p "请输入新世界名称 [NewWorld]: " WORLD_NAME
        WORLD_NAME=${WORLD_NAME:-NewWorld}
        
        # 检查世界名称是否已存在
        if [ -f "$WORLDS_CONFIG_FILE" ]; then
            if jq -e --arg name "$WORLD_NAME" '.worlds[] | select(.name == $name)' "$WORLDS_CONFIG_FILE" >/dev/null 2>&1; then
                log_warning "世界名称 '$WORLD_NAME' 已存在，请选择其他名称"
            else
                break
            fi
        else
            break
        fi
    done
    
    # 获取端口配置
    local suggested_port=$(get_next_available_port)
    while true; do
        read -p "请输入端口号 [$suggested_port]: " WORLD_PORT
        WORLD_PORT=${WORLD_PORT:-$suggested_port}
        
        if ! check_port_available "$WORLD_PORT"; then
            log_warning "端口 $WORLD_PORT 已被使用，请选择其他端口"
            suggested_port=$(get_next_available_port)
        else
            break
        fi
    done
    
    # 获取其他配置
    read -p "请输入最大玩家数 [8]: " MAX_PLAYERS
    MAX_PLAYERS=${MAX_PLAYERS:-8}
    
    read -p "请输入服务器密码 (留空表示无密码): " SERVER_PASSWORD
    
    echo
    echo "请选择世界大小:"
    echo "1) 小世界 (1) - 适合1-4人"
    echo "2) 中世界 (2) - 适合4-8人"
    echo "3) 大世界 (3) - 适合8-16人"
    read -p "请选择 [3]: " WORLD_SIZE_CHOICE
    case $WORLD_SIZE_CHOICE in
        1) WORLD_SIZE=1 ;;
        2) WORLD_SIZE=2 ;;
        *) WORLD_SIZE=3 ;;
    esac
    
    echo
    echo "请选择难度:"
    echo "1) 经典 (0) - 适合新手"
    echo "2) 专家 (1) - 适合有经验的玩家"
    echo "3) 大师 (2) - 适合高级玩家"
    read -p "请选择 [0]: " DIFFICULTY_CHOICE
    case $DIFFICULTY_CHOICE in
        1) DIFFICULTY=1 ;;
        2) DIFFICULTY=2 ;;
        *) DIFFICULTY=0 ;;
    esac
    
    read -p "请输入欢迎消息 [欢迎来到我的Terraria服务器！]: " MOTD
    MOTD=${MOTD:-欢迎来到我的Terraria服务器！}
    
    # 检查世界文件是否存在
    if check_world_exists "$WORLD_NAME"; then
        log_info "发现现有世界文件: ${WORLD_NAME}.wld，将直接使用现有世界"
        WORLD_EXISTS="true"
        AUTOCREATE=0
    else
        log_info "未发现世界文件，将创建新世界: ${WORLD_NAME}.wld"
        WORLD_EXISTS="false"
        AUTOCREATE=$WORLD_SIZE
    fi
    
    # 创建世界配置
    create_world_config
}

# 创建世界配置文件
create_world_config() {
    local config_file="$INSTALL_DIR/configs/${WORLD_NAME}_config.txt"
    local world_file="$INSTALL_DIR/worlds/${WORLD_NAME}.wld"
    
    # 确保目录存在
    mkdir -p "$INSTALL_DIR/worlds"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/configs"
    
    # 创建配置文件
    cat > "$config_file" << EOF
world=$world_file
autocreate=$AUTOCREATE
worldname=$WORLD_NAME
difficulty=$DIFFICULTY
maxplayers=$MAX_PLAYERS
port=$WORLD_PORT
password=$SERVER_PASSWORD
motd=$MOTD
worldpath=$INSTALL_DIR/worlds
banlist=$INSTALL_DIR/banlist.txt
logpath=$INSTALL_DIR/logs/${WORLD_NAME}.log
EOF
    
    log_success "世界配置文件已创建: $config_file"
}

# 更新世界配置JSON文件
update_worlds_config() {
    log_info "更新世界配置文件..."
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 添加新世界到配置
    jq --arg name "$WORLD_NAME" \
       --arg port "$WORLD_PORT" \
       --arg config_file "$INSTALL_DIR/configs/${WORLD_NAME}_config.txt" \
       --arg world_file "$INSTALL_DIR/worlds/${WORLD_NAME}.wld" \
       --arg log_file "$INSTALL_DIR/logs/${WORLD_NAME}.log" \
       --arg world_exists "$WORLD_EXISTS" \
       --arg tmux_session "terraria_${WORLD_NAME}" \
       '.worlds += [{
         "name": $name,
         "port": ($port | tonumber),
         "config_file": $config_file,
         "world_file": $world_file,
         "log_file": $log_file,
         "world_exists": ($world_exists == "true"),
         "tmux_session": $tmux_session
       }]' "$WORLDS_CONFIG_FILE" > "$temp_file"
    
    # 替换原文件
    mv "$temp_file" "$WORLDS_CONFIG_FILE"
    
    log_success "世界配置已更新"
}

# 创建世界管理脚本
create_world_management_scripts() {
    log_info "创建世界管理脚本..."
    
    # 启动单个世界脚本
    cat > "$INSTALL_DIR/start_world.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORLDS_CONFIG="$SCRIPT_DIR/worlds_config.json"

if [ $# -eq 0 ]; then
    echo "用法: $0 <世界名称>"
    echo "可用的世界:"
    jq -r '.worlds[] | "  - \(.name) (端口: \(.port))"' "$WORLDS_CONFIG"
    exit 1
fi

WORLD_NAME="$1"

# 查找世界配置
WORLD_INFO=$(jq -r --arg name "$WORLD_NAME" '.worlds[] | select(.name == $name) | "\(.port) \(.config_file) \(.tmux_session)"' "$WORLDS_CONFIG")

if [ -z "$WORLD_INFO" ]; then
    echo "错误: 未找到世界 '$WORLD_NAME'"
    echo "可用的世界:"
    jq -r '.worlds[] | "  - \(.name) (端口: \(.port))"' "$WORLDS_CONFIG"
    exit 1
fi

read -r port config_file tmux_session <<< "$WORLD_INFO"

if tmux has-session -t "$tmux_session" 2>/dev/null; then
    echo "世界 '$WORLD_NAME' 已在运行中 (端口: $port)"
    echo "使用 'tmux attach-session -t $tmux_session' 连接到控制台"
else
    echo "启动世界 '$WORLD_NAME' (端口: $port)..."
    tmux new-session -d -s "$tmux_session" -c "$SCRIPT_DIR/terraria-server-1449/Linux" './TerrariaServer.bin.x86_64 -config '"$config_file"
    echo "世界 '$WORLD_NAME' 已启动"
    echo "使用 'tmux attach-session -t $tmux_session' 连接到控制台"
fi
EOF

    # 停止单个世界脚本
    cat > "$INSTALL_DIR/stop_world.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORLDS_CONFIG="$SCRIPT_DIR/worlds_config.json"

if [ $# -eq 0 ]; then
    echo "用法: $0 <世界名称>"
    echo "可用的世界:"
    jq -r '.worlds[] | "  - \(.name) (端口: \(.port))"' "$WORLDS_CONFIG"
    exit 1
fi

WORLD_NAME="$1"

# 查找世界配置
WORLD_INFO=$(jq -r --arg name "$WORLD_NAME" '.worlds[] | select(.name == $name) | "\(.tmux_session)"' "$WORLDS_CONFIG")

if [ -z "$WORLD_INFO" ]; then
    echo "错误: 未找到世界 '$WORLD_NAME'"
    echo "可用的世界:"
    jq -r '.worlds[] | "  - \(.name) (端口: \(.port))"' "$WORLDS_CONFIG"
    exit 1
fi

tmux_session="$WORLD_INFO"

if tmux has-session -t "$tmux_session" 2>/dev/null; then
    echo "停止世界 '$WORLD_NAME'..."
    tmux send-keys -t "$tmux_session" "exit" Enter
    sleep 2
    tmux kill-session -t "$tmux_session" 2>/dev/null || true
    echo "世界 '$WORLD_NAME' 已停止"
else
    echo "世界 '$WORLD_NAME' 未运行"
fi
EOF

    # 重启单个世界脚本
    cat > "$INSTALL_DIR/restart_world.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -eq 0 ]; then
    echo "用法: $0 <世界名称>"
    echo "可用的世界:"
    jq -r '.worlds[] | "  - \(.name) (端口: \(.port))"' "$SCRIPT_DIR/worlds_config.json"
    exit 1
fi

WORLD_NAME="$1"
echo "正在重启世界 '$WORLD_NAME'..."
"$SCRIPT_DIR/stop_world.sh" "$WORLD_NAME"
sleep 2
"$SCRIPT_DIR/start_world.sh" "$WORLD_NAME"
EOF

    # 启动所有世界脚本
    cat > "$INSTALL_DIR/start_all_worlds.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORLDS_CONFIG="$SCRIPT_DIR/worlds_config.json"

if [ ! -f "$WORLDS_CONFIG" ]; then
    echo "错误: 世界配置文件不存在: $WORLDS_CONFIG"
    exit 1
fi

echo "启动所有Terraria世界服务器..."

# 读取世界配置并启动每个世界
jq -r '.worlds[] | "\(.name) \(.port) \(.config_file) \(.tmux_session)"' "$WORLDS_CONFIG" | while read -r name port config_file tmux_session; do
    if tmux has-session -t "$tmux_session" 2>/dev/null; then
        echo "世界 '$name' 已在运行中 (端口: $port)"
    else
        echo "启动世界 '$name' (端口: $port)..."
        tmux new-session -d -s "$tmux_session" -c "$SCRIPT_DIR/terraria-server-1449/Linux" './TerrariaServer.bin.x86_64 -config '"$config_file"
        echo "世界 '$name' 已启动"
    fi
done

echo "所有世界服务器启动完成"
echo "使用 'tmux list-sessions' 查看所有会话"
echo "使用 'tmux attach-session -t terraria_<世界名>' 连接到特定世界控制台"
EOF

    # 停止所有世界脚本
    cat > "$INSTALL_DIR/stop_all_worlds.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORLDS_CONFIG="$SCRIPT_DIR/worlds_config.json"

if [ ! -f "$WORLDS_CONFIG" ]; then
    echo "错误: 世界配置文件不存在: $WORLDS_CONFIG"
    exit 1
fi

echo "停止所有Terraria世界服务器..."

# 读取世界配置并停止每个世界
jq -r '.worlds[] | "\(.name) \(.tmux_session)"' "$WORLDS_CONFIG" | while read -r name tmux_session; do
    if tmux has-session -t "$tmux_session" 2>/dev/null; then
        echo "停止世界 '$name'..."
        tmux send-keys -t "$tmux_session" "exit" Enter
        sleep 2
        tmux kill-session -t "$tmux_session" 2>/dev/null || true
        echo "世界 '$name' 已停止"
    else
        echo "世界 '$name' 未运行"
    fi
done

echo "所有世界服务器已停止"
EOF

    # 状态检查脚本
    cat > "$INSTALL_DIR/status_worlds.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORLDS_CONFIG="$SCRIPT_DIR/worlds_config.json"

if [ ! -f "$WORLDS_CONFIG" ]; then
    echo "错误: 世界配置文件不存在: $WORLDS_CONFIG"
    exit 1
fi

echo "Terraria世界服务器状态:"
echo "================================"

jq -r '.worlds[] | "\(.name) \(.port) \(.tmux_session)"' "$WORLDS_CONFIG" | while read -r name port tmux_session; do
    if tmux has-session -t "$tmux_session" 2>/dev/null; then
        echo "✓ $name (端口: $port) - 运行中"
    else
        echo "✗ $name (端口: $port) - 未运行"
    fi
done

echo "================================"
echo "使用 'tmux list-sessions' 查看所有tmux会话"
echo "使用 'tmux attach-session -t terraria_<世界名>' 连接到特定世界控制台"
EOF

    # 设置脚本权限
    chmod +x "$INSTALL_DIR"/*.sh
    
    log_success "世界管理脚本创建完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # 检测防火墙类型
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian UFW
        sudo ufw allow $WORLD_PORT/tcp
        sudo ufw reload
        log_success "UFW防火墙规则已添加 (端口: $WORLD_PORT)"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewalld
        sudo firewall-cmd --permanent --add-port=$WORLD_PORT/tcp
        sudo firewall-cmd --reload
        log_success "firewalld防火墙规则已添加 (端口: $WORLD_PORT)"
    elif command -v iptables &> /dev/null; then
        # iptables
        sudo iptables -A INPUT -p tcp --dport $WORLD_PORT -j ACCEPT
        log_success "iptables防火墙规则已添加 (端口: $WORLD_PORT)"
        log_warning "请手动保存iptables规则: sudo iptables-save > /etc/iptables/rules.v4"
    else
        log_warning "未检测到防火墙，请手动开放端口 $WORLD_PORT"
    fi
}

# 显示完成信息
show_completion_info() {
    echo
    log_success "=========================================="
    log_success "新世界 '$WORLD_NAME' 配置完成！"
    log_success "=========================================="
    echo
    log_info "世界信息:"
    log_info "  世界名称: $WORLD_NAME"
    log_info "  端口: $WORLD_PORT"
    log_info "  最大玩家数: $MAX_PLAYERS"
    log_info "  世界大小: $WORLD_SIZE"
    log_info "  难度: $DIFFICULTY"
    log_info "  世界文件: $([ "$WORLD_EXISTS" = "true" ] && echo "已存在" || echo "将创建")"
    echo
    log_info "管理命令:"
    log_info "  启动世界: $INSTALL_DIR/start_world.sh $WORLD_NAME"
    log_info "  停止世界: $INSTALL_DIR/stop_world.sh $WORLD_NAME"
    log_info "  重启世界: $INSTALL_DIR/restart_world.sh $WORLD_NAME"
    log_info "  查看状态: $INSTALL_DIR/status_worlds.sh"
    echo
    log_info "连接控制台:"
    log_info "  tmux attach-session -t terraria_$WORLD_NAME"
    echo
    log_info "连接服务器:"
    log_info "  在Terraria游戏中选择'多人游戏' -> '通过IP加入'"
    log_info "  输入服务器IP和端口: $WORLD_PORT"
    if [ -n "$SERVER_PASSWORD" ]; then
        log_info "  密码: $SERVER_PASSWORD"
    fi
    echo
    read -p "是否现在启动新世界 '$WORLD_NAME'？[Y/n]: " START_NOW
    if [[ ! $START_NOW =~ ^[Nn]$ ]]; then
        "$INSTALL_DIR/start_world.sh" "$WORLD_NAME"
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "    Terraria新世界添加工具"
    echo "=========================================="
    echo
    
    # 检查依赖
    if ! command -v jq &> /dev/null; then
        log_error "未找到jq命令，请先安装:"
        log_info "  Ubuntu/Debian: sudo apt install jq"
        log_info "  CentOS/RHEL: sudo yum install jq"
        log_info "  Arch: sudo pacman -S jq"
        exit 1
    fi
    
    check_terraria_installation
    check_worlds_config
    show_configuration_tutorial
    configure_new_world
    update_worlds_config
    create_world_management_scripts
    configure_firewall
    show_completion_info
}

# 运行主函数
main "$@"


