#!/bin/bash
# Terraria统一世界重载脚本
# 重新加载自启动配置并重启相应的世界

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/Server"
AUTOSTART_CONFIG="$SCRIPT_DIR/autostart.conf"
LOG_FILE="$SERVER_DIR/logs/master_service.log"

# 日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "开始重载Terraria世界配置..."

# 检查Server目录是否存在
if [ ! -d "$SERVER_DIR" ]; then
    log_message "错误: Server目录不存在"
    exit 1
fi

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

# 检查配置文件是否存在
if [ ! -f "$AUTOSTART_CONFIG" ]; then
    log_message "错误: 自启动配置文件不存在: $AUTOSTART_CONFIG"
    exit 1
fi

# 获取当前应该自启动的世界列表
should_run_worlds=()
while IFS= read -r line; do
    # 跳过空行和注释行
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # 去除行首尾空白字符
    world_name=$(echo "$line" | xargs)
    
    if [ -n "$world_name" ]; then
        should_run_worlds+=("$world_name")
    fi
done < "$AUTOSTART_CONFIG"

log_message "配置中的自启动世界: ${should_run_worlds[*]}"

# 获取当前正在运行的terraria世界
running_worlds=()
for session in $(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^terraria_"); do
    world_name=${session#terraria_}
    running_worlds+=("$world_name")
done

log_message "当前运行的世界: ${running_worlds[*]}"

# 停止不应该运行的世界
for running_world in "${running_worlds[@]}"; do
    should_run=false
    for should_run_world in "${should_run_worlds[@]}"; do
        if [ "$running_world" = "$should_run_world" ]; then
            should_run=true
            break
        fi
    done
    
    if [ "$should_run" = false ]; then
        log_message "停止不需要自启动的世界: $running_world"
        if [ -f "$SERVER_DIR/scripts/stop_${running_world}.sh" ]; then
            "$SERVER_DIR/scripts/stop_${running_world}.sh" >> "$LOG_FILE" 2>&1
        else
            tmux send-keys -t "terraria_$running_world" "exit" Enter 2>/dev/null
            sleep 2
            tmux kill-session -t "terraria_$running_world" 2>/dev/null
        fi
    fi
done

# 启动应该运行但未运行的世界
for should_run_world in "${should_run_worlds[@]}"; do
    if ! tmux has-session -t "terraria_$should_run_world" 2>/dev/null; then
        log_message "启动世界: $should_run_world"
        
        # 检查配置和脚本是否存在
        if [ ! -f "$SERVER_DIR/worlds/${should_run_world}.config" ]; then
            log_message "警告: 世界配置文件不存在: ${should_run_world}.config"
            continue
        fi
        
        if [ ! -f "$SERVER_DIR/scripts/start_${should_run_world}.sh" ]; then
            log_message "警告: 启动脚本不存在: start_${should_run_world}.sh"
            continue
        fi
        
        # 启动世界
        "$SERVER_DIR/scripts/start_${should_run_world}.sh" >> "$LOG_FILE" 2>&1
        sleep 2
    else
        log_message "世界 '$should_run_world' 已在运行中"
    fi
done

log_message "重载完成"

exit 0
