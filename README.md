# Terraria服务器管理工具

一个功能完整的Terraria服务器安装和配置管理工具，支持多世界管理、自动化部署和系统服务集成。

## 功能特性

- 🚀 **一键安装** - 自动下载和配置Terraria服务器
- 🌍 **多世界管理** - 支持创建、载入和管理多个世界
- 🔧 **交互式配置** - 友好的菜单界面，简化配置过程
- 🔄 **自动重载** - 支持配置文件热重载，无需重启服务器
- 🚦 **自启动支持** - 集成systemd服务，支持开机自启动
- 📊 **状态监控** - 实时查看世界运行状态
- 💾 **自动备份** - 定期备份世界文件
- 🛡️ **防火墙配置** - 自动配置防火墙规则

## 系统要求

- Linux系统（Ubuntu/Debian/CentOS/Arch等）
- Bash 4.0+
- 普通用户权限（会在需要时请求sudo）
- 网络连接（用于下载服务器文件）

## 快速开始

### 1. 克隆仓库

```bash
git clone <仓库地址>
cd terraria
```

### 2. 安装服务器

```bash
./terraria_install.sh
```

安装脚本将会：
- 检测系统环境并安装必要依赖
- 下载Terraria服务器文件到`Server`目录
- 创建完整的目录结构
- 生成管理脚本和配置模板

### 3. 配置世界

```bash
./terraria_config.sh
```

配置脚本提供以下功能：
- 创建新世界
- 载入已有世界
- 重载所有世界配置
- 管理世界状态
- 配置自启动服务

## 目录结构

```
terraria/
├── Server/                     # 服务器主目录
│   ├── bin/                   # Terraria服务器程序
│   │   └── terraria-server/   # 服务器可执行文件
│   ├── worlds/                # 世界文件和配置
│   │   ├── *.wld             # 世界文件
│   │   └── *.config          # 世界配置文件
│   ├── configs/              # 全局配置
│   │   ├── server_global.json # 服务器全局设置
│   │   ├── world_template.txt # 世界配置模板
│   │   └── terraria@.service  # systemd服务模板
│   ├── logs/                 # 日志文件
│   ├── scripts/              # 管理脚本
│   │   ├── start_*.sh        # 世界启动脚本
│   │   ├── stop_*.sh         # 世界停止脚本
│   │   └── backup_worlds.sh  # 备份脚本
│   └── backups/              # 备份文件
├── terraria_install.sh       # 安装脚本
├── terraria_config.sh        # 配置脚本
└── README.md                 # 本文件
```

## 使用说明

### 创建新世界

1. 运行配置脚本：`./terraria_config.sh`
2. 选择菜单选项 `1) 创建新世界`
3. 按提示输入世界配置：
   - 世界名称
   - 端口号（自动分配可用端口）
   - 最大玩家数
   - 服务器密码（可选）
   - 世界大小（小/中/大）
   - 难度（经典/专家/大师）
   - 欢迎消息

### 载入已有世界

1. 选择菜单选项 `2) 载入已有世界`
2. 输入现有`.wld`文件的完整路径
3. 配置服务器参数
4. 世界文件会自动复制到`Server/worlds`目录

### 手动添加世界

你也可以手动添加世界：

1. 将`.wld`文件复制到`Server/worlds/`目录
2. 复制`Server/configs/world_template.txt`为`Server/worlds/世界名.config`
3. 编辑配置文件，修改相应参数
4. 运行配置脚本，选择 `3) 重载所有世界`

### 管理世界

- **启动世界**：配置脚本菜单 → `5) 启动/停止世界`
- **查看状态**：配置脚本菜单 → `4) 列出所有世界`
- **连接控制台**：`tmux attach-session -t terraria_世界名`
- **分离控制台**：在tmux中按 `Ctrl+B` 然后按 `D`

### 自启动配置

1. 选择菜单选项 `6) 配置自启动`
2. 可以选择：
   - 配置所有世界自启动
   - 配置单个世界自启动
   - 禁用所有自启动
   - 查看自启动状态

### 系统服务命令

配置自启动后，可以使用systemd命令管理服务：

```bash
# 启动服务
sudo systemctl start terraria@世界名

# 停止服务
sudo systemctl stop terraria@世界名

# 重启服务
sudo systemctl restart terraria@世界名

# 查看服务状态
sudo systemctl status terraria@世界名

# 查看服务日志
sudo journalctl -u terraria@世界名 -f
```

## 配置文件说明

### 全局配置 (Server/configs/server_global.json)

```json
{
  "terraria_version": "1449",
  "server_dir": "/path/to/Server",
  "default_settings": {
    "maxplayers": 8,
    "difficulty": 0,
    "world_size": 3,
    "motd": "欢迎来到我的Terraria服务器！"
  },
  "port_range": {
    "start": 7777,
    "end": 7877
  }
}
```

### 世界配置 (Server/worlds/世界名.config)

```ini
world=/path/to/world.wld
autocreate=3
worldname=世界名
difficulty=0
maxplayers=8
port=7777
password=
motd=欢迎来到我的Terraria服务器！
worldpath=/path/to/worlds
banlist=/path/to/banlist
logpath=/path/to/log
secure=1
language=zh-Hans
```

## 端口管理

- 默认端口范围：7777-7877
- 系统会自动分配可用端口
- 可通过系统设置修改端口范围
- 支持端口冲突检测

## 备份功能

- 自动备份脚本：`Server/scripts/backup_worlds.sh`
- 备份位置：`Server/backups/`
- 保留最近10个备份
- 可通过配置脚本手动触发备份

## 防火墙配置

安装脚本会自动配置防火墙规则：

- **UFW** (Ubuntu/Debian)：`sudo ufw allow 端口/tcp`
- **firewalld** (CentOS/RHEL)：`sudo firewall-cmd --add-port=端口/tcp`
- **iptables**：`sudo iptables -A INPUT -p tcp --dport 端口 -j ACCEPT`

## 故障排除

### 常见问题

1. **端口被占用**
   - 使用配置脚本的系统设置检查端口状态
   - 修改世界配置文件中的端口号

2. **世界无法启动**
   - 检查世界文件是否存在：`ls -la Server/worlds/`
   - 查看错误日志：`tail -f Server/logs/世界名.log`
   - 检查tmux会话：`tmux list-sessions`

3. **自启动失败**
   - 检查systemd服务状态：`sudo systemctl status terraria@世界名`
   - 查看服务日志：`sudo journalctl -u terraria@世界名`

4. **权限问题**
   - 确保脚本有执行权限：`chmod +x *.sh`
   - 检查目录权限：`ls -la Server/`

### 日志查看

- **世界日志**：`Server/logs/世界名.log`
- **系统日志**：`sudo journalctl -u terraria@世界名`
- **tmux会话**：`tmux attach-session -t terraria_世界名`

### 重置配置

如果需要重置配置：

1. 停止所有世界服务
2. 删除`Server`目录
3. 重新运行安装脚本

## 高级功能

### 批量操作

- 启动所有世界：通过配置脚本的自启动功能
- 停止所有世界：`sudo systemctl stop 'terraria@*'`
- 重载所有配置：配置脚本菜单选项3

### 自定义配置

你可以直接编辑配置文件来进行高级自定义：

1. 编辑`Server/worlds/世界名.config`
2. 运行配置脚本，选择"重载所有世界"
3. 重启对应的世界服务

### 网络配置

如果服务器在NAT后面，需要配置端口转发：

1. 路由器端口转发：外部端口 → 服务器IP:内部端口
2. 防火墙规则：允许对应端口的TCP连接
3. 确保服务器监听正确的端口

## 贡献

欢迎提交Issue和Pull Request来改进这个工具！

## 许可证

本项目采用MIT许可证。

## 更新日志

### v2.0
- 重构为模块化架构
- 添加完整的菜单系统
- 支持多世界管理
- 集成systemd服务
- 添加备份功能
- 改进错误处理

### v1.0
- 基础安装和配置功能
- 单世界管理
- 简单的脚本生成
