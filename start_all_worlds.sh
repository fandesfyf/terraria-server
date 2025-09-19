#!/bin/bash
# Terraria统一世界启动脚本
# 读取autostart.conf配置文件，启动所有配置了自启动的世界

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/Server"
AUTOSTART_CONFIG="$SCRIPT_DIR/autostart.conf"
LOG_FILE="$SERVER_DIR/logs/master_service.log"

# 日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "开始启动所有自启动世界..."

# 检查Server目录是否存在
if [ ! -d "$SERVER_DIR" ]; then
    log_message "错误: Server目录不存在，请先运行安装脚本"
    exit 1
fi

# 检查配置文件是否存在
if [ ! -f "$AUTOSTART_CONFIG" ]; then
    log_message "错误: 自启动配置文件不存在: $AUTOSTART_CONFIG"
    exit 1
fi

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

started_count=0
failed_count=0

# 读取配置文件并启动世界
while IFS= read -r line; do
    # 跳过空行和注释行
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # 去除行首尾空白字符
    world_name=$(echo "$line" | xargs)
    
    if [ -z "$world_name" ]; then
        continue
    fi
    
    log_message "正在启动世界: $world_name"
    
    # 检查世界配置文件是否存在
    if [ ! -f "$SERVER_DIR/worlds/${world_name}.config" ]; then
        log_message "警告: 世界配置文件不存在: ${world_name}.config"
        failed_count=$((failed_count + 1))
        continue
    fi
    
    # 检查启动脚本是否存在
    if [ ! -f "$SERVER_DIR/scripts/start_${world_name}.sh" ]; then
        log_message "警告: 启动脚本不存在: start_${world_name}.sh"
        failed_count=$((failed_count + 1))
        continue
    fi
    
    # 检查世界是否已经在运行
    if tmux has-session -t "terraria_$world_name" 2>/dev/null; then
        log_message "世界 '$world_name' 已在运行中，跳过启动"
        continue
    fi
    
    # 启动世界
    "$SERVER_DIR/scripts/start_${world_name}.sh"
    if [ $? -eq 0 ]; then
        log_message "世界 '$world_name' 启动成功"
        started_count=$((started_count + 1))
        # 等待一下再启动下一个世界，避免资源竞争
        sleep 3
    else
        log_message "世界 '$world_name' 启动失败"
        failed_count=$((failed_count + 1))
    fi
    
done < "$AUTOSTART_CONFIG"

log_message "自启动完成 - 成功启动: $started_count 个世界, 失败: $failed_count 个世界"

# 如果有世界启动成功，返回成功状态
if [ $started_count -gt 0 ]; then
    exit 0
else
    exit 1
fi
