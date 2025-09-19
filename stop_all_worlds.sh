#!/bin/bash
# Terraria统一世界停止脚本
# 停止所有正在运行的Terraria世界

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/Server"
LOG_FILE="$SERVER_DIR/logs/master_service.log"

# 日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "开始停止所有Terraria世界..."

# 检查Server目录是否存在
if [ ! -d "$SERVER_DIR" ]; then
    log_message "错误: Server目录不存在"
    exit 1
fi

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

stopped_count=0

# 查找所有terraria相关的tmux会话并停止
for session in $(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^terraria_"); do
    world_name=${session#terraria_}
    
    log_message "正在停止世界: $world_name"
    
    # 尝试使用停止脚本
    if [ -f "$SERVER_DIR/scripts/stop_${world_name}.sh" ]; then
        if "$SERVER_DIR/scripts/stop_${world_name}.sh" >> "$LOG_FILE" 2>&1; then
            log_message "世界 '$world_name' 停止成功"
            stopped_count=$((stopped_count + 1))
        else
            log_message "使用停止脚本失败，尝试强制停止会话: $session"
            # 发送退出命令
            tmux send-keys -t "$session" "exit" Enter 2>/dev/null
            sleep 3
            # 强制杀死会话
            tmux kill-session -t "$session" 2>/dev/null
            log_message "世界 '$world_name' 已强制停止"
            stopped_count=$((stopped_count + 1))
        fi
    else
        log_message "停止脚本不存在，直接停止tmux会话: $session"
        # 发送退出命令
        tmux send-keys -t "$session" "exit" Enter 2>/dev/null
        sleep 3
        # 强制杀死会话
        tmux kill-session -t "$session" 2>/dev/null
        log_message "世界 '$world_name' 已停止"
        stopped_count=$((stopped_count + 1))
    fi
    
    # 等待一下再停止下一个世界
    sleep 1
done

log_message "停止完成 - 共停止: $stopped_count 个世界"

exit 0
