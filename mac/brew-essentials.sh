#!/bin/bash
# brew-essentials.sh - 通过Homebrew安装开发必备工具
# 使用分类 Brewfile 管理依赖包

# 配置变量
LOG_FILE="$HOME/brew_install_log.txt"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BREWFILES_DIR="${SCRIPT_DIR}/Brewfiles"
INSTALL_CORE=true
INSTALL_LANGUAGES=true
INSTALL_DATABASES=true
INSTALL_APPS=true
INSTALL_FONTS=true
SKIP_EXISTING=true
FAST_MODE=false # 并行安装模式

# 解析命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-core) INSTALL_CORE=false ;;
        --no-languages) INSTALL_LANGUAGES=false ;;
        --no-databases) INSTALL_DATABASES=false ;;
        --no-apps) INSTALL_APPS=false ;;
        --no-fonts) INSTALL_FONTS=false ;;
        --force) SKIP_EXISTING=false ;;
        --fast) FAST_MODE=true ;;
        --help) 
            echo "用法: ./brew-essentials.sh [选项]"
            echo "选项:"
            echo "  --no-core       不安装核心命令行工具"
            echo "  --no-languages  不安装编程语言"
            echo "  --no-databases  不安装数据库工具"
            echo "  --no-apps       不安装应用程序"
            echo "  --no-fonts      不安装字体"
            echo "  --force         强制重新安装已存在的包"
            echo "  --fast          启用并行安装模式(更快但日志可能混乱)"
            exit 0
            ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

# 创建临时组合 Brewfile
create_combined_brewfile() {
    local tempfile="${SCRIPT_DIR}/Brewfile.combined.temp"
    
    # 开始创建临时组合 Brewfile
    echo "# 临时组合 Brewfile - 由脚本生成 $(date)" > "$tempfile"
    
    # 根据用户选择添加相应的 Brewfile
    if $INSTALL_CORE && [ -f "${BREWFILES_DIR}/core.brewfile" ]; then
        echo "# 添加命令行工具..."
        echo "# ==== 命令行工具 ====" >> "$tempfile"
        cat "${BREWFILES_DIR}/core.brewfile" >> "$tempfile"
        echo "" >> "$tempfile"
    fi
    
    if $INSTALL_LANGUAGES && [ -f "${BREWFILES_DIR}/languages.brewfile" ]; then
        echo "# 添加开发语言和工具..."
        echo "# ==== 开发语言和工具 ====" >> "$tempfile"
        cat "${BREWFILES_DIR}/languages.brewfile" >> "$tempfile"
        echo "" >> "$tempfile"
    fi
    
    if $INSTALL_DATABASES && [ -f "${BREWFILES_DIR}/databases.brewfile" ]; then
        echo "# 添加数据库工具..."
        echo "# ==== 数据库工具 ====" >> "$tempfile"
        cat "${BREWFILES_DIR}/databases.brewfile" >> "$tempfile"
        echo "" >> "$tempfile"
    fi
    
    if $INSTALL_APPS && [ -f "${BREWFILES_DIR}/apps.brewfile" ]; then
        echo "# 添加应用程序..."
        echo "# ==== 应用程序 ====" >> "$tempfile"
        cat "${BREWFILES_DIR}/apps.brewfile" >> "$tempfile"
        echo "" >> "$tempfile"
    fi
    
    if $INSTALL_FONTS && [ -f "${BREWFILES_DIR}/fonts.brewfile" ]; then
        echo "# 添加开发字体..."
        echo "# ==== 开发字体 ====" >> "$tempfile"
        cat "${BREWFILES_DIR}/fonts.brewfile" >> "$tempfile"
    fi
    
    echo "$tempfile"
}

# 设置日志和错误处理
setup_logging() {
    # 创建新的日志文件
    echo "===== 开发工具安装日志 $(date) =====" > "$LOG_FILE"
    # 同时将输出发送到终端和日志文件
    exec &> >(tee -a "$LOG_FILE")
}

# 错误处理函数
handle_error() {
    echo "错误: 命令失败，退出代码: $?" | tee -a "$LOG_FILE"
    echo "查看日志文件获取详细信息: $LOG_FILE"
    exit 1
}

# 设置错误处理
trap 'handle_error' ERR

# 初始化
setup_logging
echo "===== 开始安装开发必备工具 ====="

# 确保使用最新版本的Homebrew
echo "更新Homebrew..."
brew update

# 检查并创建 Brewfiles 目录（如果不存在）
if [ ! -d "$BREWFILES_DIR" ]; then
    echo "Brewfiles 目录不存在，创建目录..."
    mkdir -p "$BREWFILES_DIR"
    echo "警告: Brewfiles 目录是新创建的，可能需要手动添加 Brewfile 文件"
fi

# 生成临时组合 Brewfile
COMBINED_BREWFILE=$(create_combined_brewfile)
echo "已生成临时组合 Brewfile: $COMBINED_BREWFILE"

# 使用 Homebrew Bundle 安装所有依赖
echo "使用 Brewfile 安装依赖..."
if $SKIP_EXISTING; then
    # 不重新安装已有的包
    brew bundle --file="$COMBINED_BREWFILE"
else
    # 强制重新安装所有包
    brew bundle --file="$COMBINED_BREWFILE" --force
fi

# 清理临时文件
rm -f "$COMBINED_BREWFILE"

# 清理过时的版本
echo "清理过时的包版本..."
brew cleanup

echo "===== 开发必备工具安装完成 ====="

# 显示安装的包数量
echo "已安装 $(brew list | wc -l | xargs) 个包"
echo "详细安装日志保存在: $LOG_FILE"