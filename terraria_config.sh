#!/bin/bash

# Terraria服务器配置脚本
# 作者: AI Assistant
# 版本: 2.0
# 功能: 配置和管理Terraria服务器世界

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/Server"
GLOBAL_CONFIG="$SERVER_DIR/configs/server_global.json"
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

log_menu() {
    echo -e "${CYAN}[MENU]${NC} $1"
}

log_input() {
    echo -e "${MAGENTA}[INPUT]${NC} $1"
}

# 检查安装状态
check_installation() {
    if [ ! -d "$SERVER_DIR" ]; then
        log_error "未找到Server目录，请先运行安装脚本："
        log_info "./terraria_install.sh"
        exit 1
    fi
    
    if [ ! -f "$SERVER_DIR/bin/terraria-server/Linux/TerrariaServer.bin.x86_64" ]; then
        log_error "未找到Terraria服务器程序，请先运行安装脚本"
        exit 1
    fi
    
    if [ ! -f "$GLOBAL_CONFIG" ]; then
        log_error "未找到全局配置文件，请先运行安装脚本"
        exit 1
    fi
}

# 检查端口是否可用
check_port_available() {
    local port="$1"
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # 端口被占用
    else
        return 0  # 端口可用
    fi
}

# 获取下一个可用端口
get_next_available_port() {
    local start_port=$(jq -r '.port_range.start' "$GLOBAL_CONFIG")
    local end_port=$(jq -r '.port_range.end' "$GLOBAL_CONFIG")
    local port=$start_port
    
    # 获取已使用的端口
    local used_ports=()
    if [ -d "$SERVER_DIR/worlds" ]; then
        while IFS= read -r config_file; do
            if [ -f "$config_file" ]; then
                local config_port=$(grep "^port=" "$config_file" | cut -d'=' -f2)
                if [ -n "$config_port" ]; then
                    used_ports+=("$config_port")
                fi
            fi
        done < <(find "$SERVER_DIR/worlds" -name "*.config" -type f)
    fi
    
    # 查找下一个可用端口
    while [ $port -le $end_port ]; do
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
    done
    
    log_error "无法在端口范围 $start_port-$end_port 内找到可用端口"
    return 1
}

# 显示主菜单
show_main_menu() {
    clear
    echo "=========================================="
    echo "    Terraria服务器配置管理工具 v2.0"
    echo "=========================================="
    echo
    log_menu "请选择操作："
    echo "  1) 创建新世界"
    echo "  2) 载入已有世界"
    echo "  3) 重载所有世界"
    echo "  4) 列出所有世界"
    echo "  5) 启动/停止世界"
    echo "  6) 配置自启动"
    echo "  7) 备份世界"
    echo "  8) 系统设置"
    echo "  0) 退出"
    echo
}

# 创建新世界
create_new_world() {
    clear
    echo "=========================================="
    echo "           创建新世界"
    echo "=========================================="
    echo
    
    # 获取世界名称
    while true; do
        log_input "请输入新世界名称:"
        read -p "> " WORLD_NAME
        
        if [ -z "$WORLD_NAME" ]; then
            log_error "世界名称不能为空"
            continue
        fi
        
        # 检查世界名称是否已存在
        if [ -f "$SERVER_DIR/worlds/${WORLD_NAME}.config" ]; then
            log_warning "世界名称 '$WORLD_NAME' 已存在，请选择其他名称"
            continue
        fi
        
        # 检查文件名合法性
        if [[ ! "$WORLD_NAME" =~ ^[a-zA-Z0-9_\-\u4e00-\u9fa5]+$ ]]; then
            log_warning "世界名称只能包含字母、数字、下划线、连字符和中文字符"
            continue
        fi
        
        break
    done
    
    # 获取端口配置
    local suggested_port=$(get_next_available_port)
    while true; do
        log_input "请输入端口号 [默认: $suggested_port]:"
        read -p "> " WORLD_PORT
        WORLD_PORT=${WORLD_PORT:-$suggested_port}
        
        if ! [[ "$WORLD_PORT" =~ ^[0-9]+$ ]] || [ "$WORLD_PORT" -lt 1024 ] || [ "$WORLD_PORT" -gt 65535 ]; then
            log_warning "端口号必须是1024-65535之间的数字"
            continue
        fi
        
        if ! check_port_available "$WORLD_PORT"; then
            log_warning "端口 $WORLD_PORT 已被使用，请选择其他端口"
            continue
        fi
        
        break
    done
    
    # 获取其他配置
    log_input "请输入最大玩家数 [默认: 8]:"
    read -p "> " MAX_PLAYERS
    MAX_PLAYERS=${MAX_PLAYERS:-8}
    
    log_input "请输入服务器密码 (留空表示无密码):"
    read -p "> " SERVER_PASSWORD
    
    echo
    echo "请选择世界大小:"
    echo "  1) 小世界 (适合1-4人)"
    echo "  2) 中世界 (适合4-8人)" 
    echo "  3) 大世界 (适合8-16人)"
    log_input "请选择 [默认: 3]:"
    read -p "> " WORLD_SIZE_CHOICE
    case $WORLD_SIZE_CHOICE in
        1) WORLD_SIZE=1 ;;
        2) WORLD_SIZE=2 ;;
        *) WORLD_SIZE=3 ;;
    esac
    
    echo
    echo "请选择难度:"
    echo "  1) 经典 (适合新手)"
    echo "  2) 专家 (适合有经验的玩家)"
    echo "  3) 大师 (适合高级玩家)"
    log_input "请选择 [默认: 1]:"
    read -p "> " DIFFICULTY_CHOICE
    case $DIFFICULTY_CHOICE in
        2) DIFFICULTY=1 ;;
        3) DIFFICULTY=2 ;;
        *) DIFFICULTY=0 ;;
    esac
    
    log_input "请输入欢迎消息 [默认: 欢迎来到我的Terraria服务器！]:"
    read -p "> " MOTD
    MOTD=${MOTD:-欢迎来到我的Terraria服务器！}
    
    # 创建世界配置
    create_world_configuration "$WORLD_NAME" "$WORLD_PORT" "$MAX_PLAYERS" "$SERVER_PASSWORD" "$WORLD_SIZE" "$DIFFICULTY" "$MOTD" "true"
    
    log_success "新世界 '$WORLD_NAME' 创建完成！"
    
    # 询问是否立即启动
    echo
    log_input "是否立即启动新世界？[Y/n]:"
    read -p "> " START_NOW
    if [[ ! $START_NOW =~ ^[Nn]$ ]]; then
        start_world "$WORLD_NAME"
    fi
    
    read -p "按回车键继续..."
}

# 载入已有世界
load_existing_world() {
    clear
    echo "=========================================="
    echo "           载入已有世界"
    echo "=========================================="
    echo
    
    # 获取世界文件路径
    while true; do
        log_input "请输入世界文件(.wld)的完整路径:"
        read -p "> " WORLD_FILE_PATH
        
        if [ -z "$WORLD_FILE_PATH" ]; then
            log_error "路径不能为空"
            continue
        fi
        
        if [ ! -f "$WORLD_FILE_PATH" ]; then
            log_error "文件不存在: $WORLD_FILE_PATH"
            continue
        fi
        
        if [[ ! "$WORLD_FILE_PATH" =~ \.wld$ ]]; then
            log_error "文件必须是.wld格式"
            continue
        fi
        
        break
    done
    
    # 提取世界名称
    WORLD_FILENAME=$(basename "$WORLD_FILE_PATH")
    DEFAULT_WORLD_NAME="${WORLD_FILENAME%.wld}"
    
    # 获取世界名称
    while true; do
        log_input "请输入世界名称 [默认: $DEFAULT_WORLD_NAME]:"
        read -p "> " WORLD_NAME
        WORLD_NAME=${WORLD_NAME:-$DEFAULT_WORLD_NAME}
        
        if [ -z "$WORLD_NAME" ]; then
            log_error "世界名称不能为空"
            continue
        fi
        
        # 检查世界名称是否已存在
        if [ -f "$SERVER_DIR/worlds/${WORLD_NAME}.config" ]; then
            log_warning "世界名称 '$WORLD_NAME' 已存在，请选择其他名称"
            continue
        fi
        
        break
    done
    
    # 复制世界文件到worlds目录
    cp "$WORLD_FILE_PATH" "$SERVER_DIR/worlds/${WORLD_NAME}.wld"
    log_success "世界文件已复制到: $SERVER_DIR/worlds/${WORLD_NAME}.wld"
    
    # 获取端口配置
    local suggested_port=$(get_next_available_port)
    while true; do
        log_input "请输入端口号 [默认: $suggested_port]:"
        read -p "> " WORLD_PORT
        WORLD_PORT=${WORLD_PORT:-$suggested_port}
        
        if ! [[ "$WORLD_PORT" =~ ^[0-9]+$ ]] || [ "$WORLD_PORT" -lt 1024 ] || [ "$WORLD_PORT" -gt 65535 ]; then
            log_warning "端口号必须是1024-65535之间的数字"
            continue
        fi
        
        if ! check_port_available "$WORLD_PORT"; then
            log_warning "端口 $WORLD_PORT 已被使用，请选择其他端口"
            continue
        fi
        
        break
    done
    
    # 获取其他配置
    log_input "请输入最大玩家数 [默认: 8]:"
    read -p "> " MAX_PLAYERS
    MAX_PLAYERS=${MAX_PLAYERS:-8}
    
    log_input "请输入服务器密码 (留空表示无密码):"
    read -p "> " SERVER_PASSWORD
    
    log_input "请输入欢迎消息 [默认: 欢迎来到我的Terraria服务器！]:"
    read -p "> " MOTD
    MOTD=${MOTD:-欢迎来到我的Terraria服务器！}
    
    # 创建世界配置（不自动创建世界，因为已存在）
    create_world_configuration "$WORLD_NAME" "$WORLD_PORT" "$MAX_PLAYERS" "$SERVER_PASSWORD" "0" "0" "$MOTD" "false"
    
    log_success "已有世界 '$WORLD_NAME' 载入完成！"
    
    # 询问是否立即启动
    echo
    log_input "是否立即启动世界？[Y/n]:"
    read -p "> " START_NOW
    if [[ ! $START_NOW =~ ^[Nn]$ ]]; then
        start_world "$WORLD_NAME"
    fi
    
    read -p "按回车键继续..."
}

# 创建世界配置文件和脚本
create_world_configuration() {
    local world_name="$1"
    local port="$2"
    local max_players="$3"
    local password="$4"
    local world_size="$5"
    local difficulty="$6"
    local motd="$7"
    local autocreate="$8"
    
    local config_file="$SERVER_DIR/worlds/${world_name}.config"
    local world_file="$SERVER_DIR/worlds/${world_name}.wld"
    local log_file="$SERVER_DIR/logs/${world_name}.log"
    local ban_file="$SERVER_DIR/worlds/${world_name}.banlist"
    
    # 创建配置文件
    cat > "$config_file" << EOF
# Terraria世界配置文件 - $world_name
world=$world_file
autocreate=$([[ "$autocreate" == "true" ]] && echo "$world_size" || echo "0")
worldname=$world_name
difficulty=$difficulty
maxplayers=$max_players
port=$port
password=$password
motd=$motd
worldpath=$SERVER_DIR/worlds
banlist=$ban_file
logpath=$log_file
secure=1
language=zh-Hans
EOF
    
    # 创建启动脚本
    local start_script="$SERVER_DIR/scripts/start_${world_name}.sh"
    sed "s/WORLD_NAME_PLACEHOLDER/$world_name/g; s|CONFIG_FILE_PLACEHOLDER|$config_file|g; s/TMUX_SESSION_PLACEHOLDER/terraria_$world_name/g" \
        "$SERVER_DIR/scripts/start_world_template.sh" > "$start_script"
    chmod +x "$start_script"
    
    # 创建停止脚本
    local stop_script="$SERVER_DIR/scripts/stop_${world_name}.sh"
    sed "s/WORLD_NAME_PLACEHOLDER/$world_name/g; s/TMUX_SESSION_PLACEHOLDER/terraria_$world_name/g" \
        "$SERVER_DIR/scripts/stop_world_template.sh" > "$stop_script"
    chmod +x "$stop_script"
    
    # 创建空的ban文件
    touch "$ban_file"
    
    log_info "配置文件已创建: $config_file"
    log_info "启动脚本已创建: $start_script"
    log_info "停止脚本已创建: $stop_script"
}

# 重载所有世界
reload_all_worlds() {
    clear
    echo "=========================================="
    echo "           重载所有世界"
    echo "=========================================="
    echo
    
    log_info "扫描worlds目录中的配置文件..."
    
    local config_count=0
    local world_count=0
    local error_count=0
    
    # 扫描所有配置文件
    if [ -d "$SERVER_DIR/worlds" ]; then
        while IFS= read -r config_file; do
            if [ -f "$config_file" ]; then
                config_count=$((config_count + 1))
                local world_name=$(basename "$config_file" .config)
                
                log_info "处理世界: $world_name"
                
                # 检查配置文件格式
                if ! grep -q "^worldname=" "$config_file" || ! grep -q "^port=" "$config_file"; then
                    log_warning "跳过无效配置文件: $config_file"
                    error_count=$((error_count + 1))
                    continue
                fi
                
                # 检查世界文件是否存在
                local world_file=$(grep "^world=" "$config_file" | cut -d'=' -f2)
                if [ ! -f "$world_file" ]; then
                    log_warning "世界文件不存在，跳过: $world_file"
                    error_count=$((error_count + 1))
                    continue
                fi
                
                # 重新生成管理脚本
                regenerate_world_scripts "$world_name" "$config_file"
                world_count=$((world_count + 1))
                
                log_success "世界 '$world_name' 重载完成"
            fi
        done < <(find "$SERVER_DIR/worlds" -name "*.config" -type f 2>/dev/null)
    fi
    
    echo
    log_success "重载完成！"
    log_info "总配置文件: $config_count"
    log_info "成功重载: $world_count"
    log_info "跳过错误: $error_count"
    
    if [ $world_count -gt 0 ]; then
        echo
        log_input "是否重新配置所有世界的自启动服务？[y/N]:"
        read -p "> " SETUP_AUTOSTART
        if [[ $SETUP_AUTOSTART =~ ^[Yy]$ ]]; then
            setup_all_autostart
        fi
    fi
    
    read -p "按回车键继续..."
}

# 重新生成世界脚本
regenerate_world_scripts() {
    local world_name="$1"
    local config_file="$2"
    
    # 创建启动脚本
    local start_script="$SERVER_DIR/scripts/start_${world_name}.sh"
    sed "s/WORLD_NAME_PLACEHOLDER/$world_name/g; s|CONFIG_FILE_PLACEHOLDER|$config_file|g; s/TMUX_SESSION_PLACEHOLDER/terraria_$world_name/g" \
        "$SERVER_DIR/scripts/start_world_template.sh" > "$start_script"
    chmod +x "$start_script"
    
    # 创建停止脚本
    local stop_script="$SERVER_DIR/scripts/stop_${world_name}.sh"
    sed "s/WORLD_NAME_PLACEHOLDER/$world_name/g; s/TMUX_SESSION_PLACEHOLDER/terraria_$world_name/g" \
        "$SERVER_DIR/scripts/stop_world_template.sh" > "$stop_script"
    chmod +x "$stop_script"
}

# 列出所有世界
list_all_worlds() {
    clear
    echo "=========================================="
    echo "           所有世界列表"
    echo "=========================================="
    echo
    
    if [ ! -d "$SERVER_DIR/worlds" ]; then
        log_warning "worlds目录不存在"
        read -p "按回车键继续..."
        return
    fi
    
    local world_count=0
    printf "%-20s %-8s %-12s %-10s %-15s\n" "世界名称" "端口" "最大玩家" "状态" "世界文件"
    echo "--------------------------------------------------------------------------------"
    
    while IFS= read -r config_file; do
        if [ -f "$config_file" ]; then
            world_count=$((world_count + 1))
            local world_name=$(basename "$config_file" .config)
            local port=$(grep "^port=" "$config_file" | cut -d'=' -f2)
            local max_players=$(grep "^maxplayers=" "$config_file" | cut -d'=' -f2)
            local world_file=$(grep "^world=" "$config_file" | cut -d'=' -f2)
            local world_exists="不存在"
            local status="未运行"
            
            if [ -f "$world_file" ]; then
                world_exists="存在"
            fi
            
            if tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -Fxq "terraria_$world_name"; then
                status="运行中"
            fi
            
            printf "%-20s %-8s %-12s %-10s %-15s\n" "$world_name" "$port" "$max_players" "$status" "$world_exists"
        fi
    done < <(find "$SERVER_DIR/worlds" -name "*.config" -type f 2>/dev/null)
    
    echo "--------------------------------------------------------------------------------"
    log_info "总计世界数量: $world_count"
    
    if [ $world_count -eq 0 ]; then
        echo
        log_warning "未找到任何世界配置"
        log_info "请使用菜单选项 1 或 2 来创建或载入世界"
    fi
    
    echo
    read -p "按回车键继续..."
}

# 启动/停止世界
manage_world_status() {
    clear
    echo "=========================================="
    echo "           启动/停止世界"
    echo "=========================================="
    echo
    
    # 列出所有世界
    local worlds=()
    while IFS= read -r config_file; do
        if [ -f "$config_file" ]; then
            local world_name=$(basename "$config_file" .config)
            local port=$(grep "^port=" "$config_file" | cut -d'=' -f2)
            local status="未运行"
            
            if tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -Fxq "terraria_$world_name"; then
                status="运行中"
            fi
            
            worlds+=("$world_name:$port:$status")
        fi
    done < <(find "$SERVER_DIR/worlds" -name "*.config" -type f 2>/dev/null)
    
    if [ ${#worlds[@]} -eq 0 ]; then
        log_warning "未找到任何世界配置"
        read -p "按回车键继续..."
        return
    fi
    
    echo "可用的世界:"
    local i=1
    for world_info in "${worlds[@]}"; do
        IFS=':' read -r name port status <<< "$world_info"
        printf "%2d) %-20s (端口:%s, 状态:%s)\n" $i "$name" "$port" "$status"
        i=$((i + 1))
    done
    echo "  0) 返回主菜单"
    echo
    
    log_input "请选择要操作的世界 [0-${#worlds[@]}]:"
    read -p "> " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt ${#worlds[@]} ]; then
        log_error "无效选择"
        read -p "按回车键继续..."
        return
    fi
    
    if [ "$choice" -eq 0 ]; then
        return
    fi
    
    local selected_world_info="${worlds[$((choice-1))]}"
    IFS=':' read -r world_name port status <<< "$selected_world_info"
    
    echo
    echo "选择的世界: $world_name (端口: $port, 状态: $status)"
    echo
    echo "请选择操作:"
    echo "  1) 启动世界"
    echo "  2) 停止世界"
    echo "  3) 重启世界"
    echo "  4) 连接到控制台"
    echo "  0) 返回"
    
    log_input "请选择操作 [0-4]:"
    read -p "> " action
    
    case $action in
        1)
            start_world "$world_name"
            ;;
        2)
            stop_world "$world_name"
            ;;
        3)
            restart_world "$world_name"
            ;;
        4)
            connect_to_console "$world_name"
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 启动世界
start_world() {
    local world_name="$1"
    log_info "启动世界: $world_name"
    
    if tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -Fxq "terraria_$world_name"; then
        log_warning "世界 '$world_name' 已在运行中"
        return
    fi
    
    if [ -f "$SERVER_DIR/scripts/start_${world_name}.sh" ]; then
        "$SERVER_DIR/scripts/start_${world_name}.sh"
    else
        log_error "启动脚本不存在: start_${world_name}.sh"
    fi
}

# 停止世界
stop_world() {
    local world_name="$1"
    log_info "停止世界: $world_name"
    
    if ! tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -Fxq "terraria_$world_name"; then
        log_warning "世界 '$world_name' 未运行"
        return
    fi
    
    if [ -f "$SERVER_DIR/scripts/stop_${world_name}.sh" ]; then
        "$SERVER_DIR/scripts/stop_${world_name}.sh"
    else
        log_error "停止脚本不存在: stop_${world_name}.sh"
    fi
}

# 重启世界
restart_world() {
    local world_name="$1"
    log_info "重启世界: $world_name"
    
    stop_world "$world_name"
    sleep 3
    start_world "$world_name"
}

# 连接到控制台
connect_to_console() {
    local world_name="$1"
    
    if ! tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -Fxq "terraria_$world_name"; then
        log_error "世界 '$world_name' 未运行"
        return
    fi
    
    log_info "连接到世界 '$world_name' 的控制台..."
    log_info "使用 Ctrl+B 然后按 D 来分离会话"
    sleep 2
    tmux attach-session -t "terraria_$world_name"
}

# 配置自启动
setup_autostart() {
    clear
    echo "=========================================="
    echo "           配置自启动"
    echo "=========================================="
    echo
    
    # 列出所有世界
    local worlds=()
    while IFS= read -r config_file; do
        if [ -f "$config_file" ]; then
            local world_name=$(basename "$config_file" .config)
            worlds+=("$world_name")
        fi
    done < <(find "$SERVER_DIR/worlds" -name "*.config" -type f 2>/dev/null)
    
    if [ ${#worlds[@]} -eq 0 ]; then
        log_warning "未找到任何世界配置"
        read -p "按回车键继续..."
        return
    fi
    
    echo "自启动配置选项:"
    echo "  1) 配置所有世界自启动"
    echo "  2) 配置单个世界自启动"
    echo "  3) 禁用所有自启动"
    echo "  4) 查看自启动状态"
    echo "  0) 返回主菜单"
    echo
    
    log_input "请选择操作 [0-4]:"
    read -p "> " choice
    
    case $choice in
        1)
            setup_all_autostart
            ;;
        2)
            setup_single_autostart
            ;;
        3)
            disable_all_autostart
            ;;
        4)
            show_autostart_status
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 配置所有世界自启动
setup_all_autostart() {
    log_info "配置所有世界的统一自启动服务..."
    
    # 复制统一服务模板到系统目录
    if [ -f "$SCRIPT_DIR/terraria-master.service" ]; then
        sudo cp "$SCRIPT_DIR/terraria-master.service" /etc/systemd/system/
        sudo systemctl daemon-reload
        log_success "Terraria统一服务模板已安装"
    else
        log_error "未找到统一服务模板文件"
        return
    fi
    
    # 将所有世界添加到自启动配置文件
    local autostart_config="$SCRIPT_DIR/autostart.conf"
    local enabled_count=0
    
    # 清空现有配置（保留注释）
    sed -i '/^[^#]/d' "$autostart_config"
    
    while IFS= read -r config_file; do
        if [ -f "$config_file" ]; then
            local world_name=$(basename "$config_file" .config)
            
            # 添加到自启动配置文件
            echo "$world_name" >> "$autostart_config"
            log_success "世界 '$world_name' 已添加到自启动列表"
            enabled_count=$((enabled_count + 1))
        fi
    done < <(find "$SERVER_DIR/worlds" -name "*.config" -type f 2>/dev/null)
    
    # 启用统一服务
    if sudo systemctl enable terraria-master 2>/dev/null; then
        log_success "Terraria统一服务已启用"
    else
        log_error "启用统一服务失败"
        return
    fi
    
    log_success "共配置了 $enabled_count 个世界的自启动"
    
    log_input "是否立即启动统一服务？[y/N]:"
    read -p "> " START_SERVICE
    if [[ $START_SERVICE =~ ^[Yy]$ ]]; then
        sudo systemctl start terraria-master
        log_success "Terraria统一服务已启动"
    fi
}

# 配置单个世界自启动
setup_single_autostart() {
    # 列出所有世界
    local worlds=()
    local autostart_config="$SCRIPT_DIR/autostart.conf"
    
    while IFS= read -r config_file; do
        if [ -f "$config_file" ]; then
            local world_name=$(basename "$config_file" .config)
            worlds+=("$world_name")
        fi
    done < <(find "$SERVER_DIR/worlds" -name "*.config" -type f 2>/dev/null)
    
    echo "可用的世界:"
    local i=1
    for world_name in "${worlds[@]}"; do
        local status="未启用"
        # 检查是否在自启动配置文件中
        if grep -q "^${world_name}$" "$autostart_config" 2>/dev/null; then
            status="已启用"
        fi
        printf "%2d) %-20s (自启动: %s)\n" $i "$world_name" "$status"
        i=$((i + 1))
    done
    echo "  0) 返回"
    echo
    
    log_input "请选择世界 [0-${#worlds[@]}]:"
    read -p "> " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt ${#worlds[@]} ]; then
        log_error "无效选择"
        return
    fi
    
    if [ "$choice" -eq 0 ]; then
        return
    fi
    
    local world_name="${worlds[$((choice-1))]}"
    
    echo
    echo "选择的世界: $world_name"
    echo "  1) 启用自启动"
    echo "  2) 禁用自启动"
    echo "  0) 返回"
    
    log_input "请选择操作 [0-2]:"
    read -p "> " action
    
    case $action in
        1)
            # 确保统一服务已安装
            if [ ! -f /etc/systemd/system/terraria-master.service ]; then
                if [ -f "$SCRIPT_DIR/terraria-master.service" ]; then
                    sudo cp "$SCRIPT_DIR/terraria-master.service" /etc/systemd/system/
                    sudo systemctl daemon-reload
                    sudo systemctl enable terraria-master
                    log_success "Terraria统一服务已安装并启用"
                else
                    log_error "未找到统一服务模板文件"
                    return
                fi
            fi
            
            # 添加到自启动配置文件（如果不存在）
            if ! grep -q "^${world_name}$" "$autostart_config" 2>/dev/null; then
                echo "$world_name" >> "$autostart_config"
                log_success "世界 '$world_name' 已添加到自启动列表"
            else
                log_info "世界 '$world_name' 已在自启动列表中"
            fi
            
            log_input "是否立即重载统一服务？[y/N]:"
            read -p "> " RELOAD_SERVICE
            if [[ $RELOAD_SERVICE =~ ^[Yy]$ ]]; then
                sudo systemctl reload terraria-master 2>/dev/null || sudo systemctl restart terraria-master
                log_success "统一服务已重载"
            fi
            ;;
        2)
            # 从自启动配置文件中移除
            if grep -q "^${world_name}$" "$autostart_config" 2>/dev/null; then
                sed -i "/^${world_name}$/d" "$autostart_config"
                log_success "世界 '$world_name' 已从自启动列表中移除"
                
                log_input "是否立即重载统一服务？[y/N]:"
                read -p "> " RELOAD_SERVICE
                if [[ $RELOAD_SERVICE =~ ^[Yy]$ ]]; then
                    sudo systemctl reload terraria-master 2>/dev/null || sudo systemctl restart terraria-master
                    log_success "统一服务已重载"
                fi
            else
                log_info "世界 '$world_name' 未在自启动列表中"
            fi
            ;;
    esac
}

# 禁用所有自启动
disable_all_autostart() {
    log_info "禁用所有世界的统一自启动服务..."
    
    local autostart_config="$SCRIPT_DIR/autostart.conf"
    
    # 停止并禁用统一服务
    if systemctl is-enabled terraria-master &>/dev/null; then
        sudo systemctl stop terraria-master 2>/dev/null || true
        sudo systemctl disable terraria-master
        log_success "Terraria统一服务已停止并禁用"
    fi
    
    # 清空自启动配置文件（保留注释）
    local disabled_count=0
    if [ -f "$autostart_config" ]; then
        # 计算被禁用的世界数量
        disabled_count=$(grep -v "^#" "$autostart_config" | grep -v "^$" | wc -l)
        # 清空非注释行
        sed -i '/^[^#]/d' "$autostart_config"
    fi
    
    log_success "共禁用了 $disabled_count 个世界的自启动"
}

# 显示自启动状态
show_autostart_status() {
    echo "自启动服务状态:"
    echo "--------------------------------------------------------------------------------"
    
    local autostart_config="$SCRIPT_DIR/autostart.conf"
    local master_service_status="未启用"
    local master_running_status="未运行"
    
    # 检查统一服务状态
    if systemctl is-enabled terraria-master &>/dev/null; then
        master_service_status="已启用"
    fi
    
    if systemctl is-active terraria-master &>/dev/null; then
        master_running_status="运行中"
    fi
    
    echo "Terraria统一服务状态: $master_service_status ($master_running_status)"
    echo "--------------------------------------------------------------------------------"
    printf "%-20s %-12s %-12s\n" "世界名称" "自启动状态" "运行状态"
    echo "--------------------------------------------------------------------------------"
    
    while IFS= read -r config_file; do
        if [ -f "$config_file" ]; then
            local world_name=$(basename "$config_file" .config)
            local autostart_status="未启用"
            local running_status="未运行"
            
            # 检查是否在自启动配置文件中
            if grep -q "^${world_name}$" "$autostart_config" 2>/dev/null; then
                autostart_status="已启用"
            fi
            
            # 检查tmux会话是否运行
            if tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -Fxq "terraria_$world_name"; then
                running_status="运行中"
            fi
            
            printf "%-20s %-12s %-12s\n" "$world_name" "$autostart_status" "$running_status"
        fi
    done < <(find "$SERVER_DIR/worlds" -name "*.config" -type f 2>/dev/null)
    
    echo "--------------------------------------------------------------------------------"
}

# 备份世界
backup_worlds() {
    clear
    echo "=========================================="
    echo "           备份世界"
    echo "=========================================="
    echo
    
    log_info "开始备份所有世界文件..."
    
    if [ -f "$SERVER_DIR/scripts/backup_worlds.sh" ]; then
        "$SERVER_DIR/scripts/backup_worlds.sh"
        log_success "备份完成！"
        
        echo
        log_info "备份位置: $SERVER_DIR/backups/"
        ls -la "$SERVER_DIR/backups/" | tail -n 5
    else
        log_error "备份脚本不存在"
    fi
    
    read -p "按回车键继续..."
}

# 系统设置
system_settings() {
    clear
    echo "=========================================="
    echo "           系统设置"
    echo "=========================================="
    echo
    
    echo "系统设置选项:"
    echo "  1) 查看系统信息"
    echo "  2) 修改端口范围"
    echo "  3) 修改默认设置"
    echo "  4) 清理日志文件"
    echo "  5) 检查系统状态"
    echo "  0) 返回主菜单"
    echo
    
    log_input "请选择操作 [0-5]:"
    read -p "> " choice
    
    case $choice in
        1)
            show_system_info
            ;;
        2)
            modify_port_range
            ;;
        3)
            modify_default_settings
            ;;
        4)
            cleanup_logs
            ;;
        5)
            check_system_status
            ;;
        0)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 显示系统信息
show_system_info() {
    echo "系统信息:"
    echo "--------------------------------------------------------------------------------"
    echo "服务器目录: $SERVER_DIR"
    echo "Terraria版本: $TERRARIA_VERSION"
    echo "配置文件: $GLOBAL_CONFIG"
    echo
    echo "目录使用情况:"
    du -sh "$SERVER_DIR"/* 2>/dev/null | sort -hr
    echo
    echo "端口范围: $(jq -r '.port_range.start' "$GLOBAL_CONFIG")-$(jq -r '.port_range.end' "$GLOBAL_CONFIG")"
    echo "默认最大玩家: $(jq -r '.default_settings.maxplayers' "$GLOBAL_CONFIG")"
    echo "默认难度: $(jq -r '.default_settings.difficulty' "$GLOBAL_CONFIG")"
    echo "默认世界大小: $(jq -r '.default_settings.world_size' "$GLOBAL_CONFIG")"
}

# 修改端口范围
modify_port_range() {
    local current_start=$(jq -r '.port_range.start' "$GLOBAL_CONFIG")
    local current_end=$(jq -r '.port_range.end' "$GLOBAL_CONFIG")
    
    echo "当前端口范围: $current_start-$current_end"
    echo
    
    log_input "请输入新的起始端口 [当前: $current_start]:"
    read -p "> " new_start
    new_start=${new_start:-$current_start}
    
    log_input "请输入新的结束端口 [当前: $current_end]:"
    read -p "> " new_end
    new_end=${new_end:-$current_end}
    
    if [[ ! "$new_start" =~ ^[0-9]+$ ]] || [[ ! "$new_end" =~ ^[0-9]+$ ]] || [ "$new_start" -ge "$new_end" ]; then
        log_error "无效的端口范围"
        return
    fi
    
    # 更新配置文件
    jq --arg start "$new_start" --arg end "$new_end" \
       '.port_range.start = ($start | tonumber) | .port_range.end = ($end | tonumber)' \
       "$GLOBAL_CONFIG" > "$GLOBAL_CONFIG.tmp" && mv "$GLOBAL_CONFIG.tmp" "$GLOBAL_CONFIG"
    
    log_success "端口范围已更新为: $new_start-$new_end"
}

# 修改默认设置
modify_default_settings() {
    echo "修改默认设置:"
    echo
    
    local current_players=$(jq -r '.default_settings.maxplayers' "$GLOBAL_CONFIG")
    local current_difficulty=$(jq -r '.default_settings.difficulty' "$GLOBAL_CONFIG")
    local current_size=$(jq -r '.default_settings.world_size' "$GLOBAL_CONFIG")
    local current_motd=$(jq -r '.default_settings.motd' "$GLOBAL_CONFIG")
    
    log_input "默认最大玩家数 [当前: $current_players]:"
    read -p "> " new_players
    new_players=${new_players:-$current_players}
    
    echo "默认难度:"
    echo "  0) 经典"
    echo "  1) 专家"
    echo "  2) 大师"
    log_input "请选择 [当前: $current_difficulty]:"
    read -p "> " new_difficulty
    new_difficulty=${new_difficulty:-$current_difficulty}
    
    echo "默认世界大小:"
    echo "  1) 小世界"
    echo "  2) 中世界"
    echo "  3) 大世界"
    log_input "请选择 [当前: $current_size]:"
    read -p "> " new_size
    new_size=${new_size:-$current_size}
    
    log_input "默认欢迎消息 [当前: $current_motd]:"
    read -p "> " new_motd
    new_motd=${new_motd:-$current_motd}
    
    # 更新配置文件
    jq --arg players "$new_players" --arg difficulty "$new_difficulty" --arg size "$new_size" --arg motd "$new_motd" \
       '.default_settings.maxplayers = ($players | tonumber) | 
        .default_settings.difficulty = ($difficulty | tonumber) | 
        .default_settings.world_size = ($size | tonumber) | 
        .default_settings.motd = $motd' \
       "$GLOBAL_CONFIG" > "$GLOBAL_CONFIG.tmp" && mv "$GLOBAL_CONFIG.tmp" "$GLOBAL_CONFIG"
    
    log_success "默认设置已更新"
}

# 清理日志文件
cleanup_logs() {
    log_info "清理日志文件..."
    
    local log_dir="$SERVER_DIR/logs"
    if [ -d "$log_dir" ]; then
        local log_count=$(find "$log_dir" -name "*.log" -type f | wc -l)
        local total_size=$(du -sh "$log_dir" | cut -f1)
        
        echo "当前日志文件数量: $log_count"
        echo "当前日志总大小: $total_size"
        echo
        
        log_input "是否清理所有日志文件？[y/N]:"
        read -p "> " CLEANUP_LOGS
        
        if [[ $CLEANUP_LOGS =~ ^[Yy]$ ]]; then
            find "$log_dir" -name "*.log" -type f -delete
            log_success "日志文件已清理"
        fi
    else
        log_info "日志目录不存在"
    fi
}

# 检查系统状态
check_system_status() {
    echo "系统状态检查:"
    echo "--------------------------------------------------------------------------------"
    
    # 检查tmux会话
    echo "活动的tmux会话:"
    tmux list-sessions 2>/dev/null | grep terraria || echo "  无活动的Terraria会话"
    echo
    
    # 检查端口使用情况
    echo "端口使用情况:"
    local start_port=$(jq -r '.port_range.start' "$GLOBAL_CONFIG")
    local end_port=$(jq -r '.port_range.end' "$GLOBAL_CONFIG")
    
    for port in $(seq $start_port $end_port); do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            local process=$(lsof -Pi :$port -sTCP:LISTEN -t | head -1)
            local process_name=$(ps -p $process -o comm= 2>/dev/null || echo "未知")
            echo "  端口 $port: 被占用 (进程: $process_name)"
        fi
    done
    echo
    
    # 检查systemd服务
    echo "systemd服务状态:"
    systemctl list-units --type=service --state=running | grep terraria || echo "  无运行中的Terraria服务"
}

# 主循环
main_loop() {
    while true; do
        show_main_menu
        
        log_input "请选择操作 [0-8]:"
        read -p "> " choice
        
        case $choice in
            1)
                create_new_world
                ;;
            2)
                load_existing_world
                ;;
            3)
                reload_all_worlds
                ;;
            4)
                list_all_worlds
                ;;
            5)
                manage_world_status
                ;;
            6)
                setup_autostart
                ;;
            7)
                backup_worlds
                ;;
            8)
                system_settings
                ;;
            0)
                log_info "感谢使用Terraria服务器配置工具！"
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                sleep 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 检查依赖
    if ! command -v jq &> /dev/null; then
        log_error "未找到jq命令，请先安装:"
        log_info "  Ubuntu/Debian: sudo apt install jq"
        log_info "  CentOS/RHEL: sudo yum install jq"
        log_info "  Arch: sudo pacman -S jq"
        exit 1
    fi
    
    check_installation
    main_loop
}

# 运行主函数
main "$@"
