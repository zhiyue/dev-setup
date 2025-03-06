#!/bin/bash
# brew-essentials.sh - 通过Homebrew安装开发必备工具
# 包含命令行工具、开发语言、应用程序等

# 配置变量
LOG_FILE="$HOME/brew_install_log.txt"
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

# 安装或升级包的函数
install_or_upgrade() {
    local package=$1
    
    if $SKIP_EXISTING && brew list "$package" &>/dev/null; then
        echo "包 $package 已安装，正在升级..."
        brew upgrade "$package" 2>/dev/null || echo "包 $package 已是最新版本"
    else
        echo "安装包 $package..."
        brew install "$package"
    fi
}

# 安装或升级cask应用的函数
install_or_upgrade_cask() {
    local package=$1
    
    if $SKIP_EXISTING && brew list --cask "$package" &>/dev/null; then
        echo "应用 $package 已安装，正在升级..."
        brew upgrade --cask "$package" 2>/dev/null || echo "应用 $package 已是最新版本"
    else
        echo "安装应用 $package..."
        brew install --cask "$package"
    fi
}

# 并行安装多个包
install_parallel() {
    local packages=("$@")
    local pids=()
    
    for package in "${packages[@]}"; do
        if $FAST_MODE; then
            # 并行安装
            (install_or_upgrade "$package") &
            pids+=($!)
        else
            # 串行安装
            install_or_upgrade "$package"
        fi
    done
    
    # 等待所有并行进程完成
    if $FAST_MODE; then
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
    fi
}

# 初始化
setup_logging
echo "===== 开始安装开发必备工具 ====="

# 确保使用最新版本的Homebrew
echo "更新Homebrew..."
brew update

# 命令行工具包列表
CLI_TOOLS=(
    git
    wget
    curl
    tree
    jq
    htop
    tmux
    vim
    neovim
    ripgrep
    fd
    fzf
    bat
    exa
    zsh
    zsh-completions
    zsh-syntax-highlighting
    zsh-autosuggestions
)

# 开发语言和工具包列表
DEV_TOOLS=(
    python@3.10
    python@3.11
    node
    nvm
    go
    cmake
    docker
    docker-compose
    kubectl
    awscli
    terraform
)

# 数据库工具包列表
DB_TOOLS=(
    mysql
    postgresql
    redis
    mongodb-community
)

# 应用程序包列表
APPLICATIONS=(
    visual-studio-code
    iterm2
    docker
    postman
    google-chrome
    firefox
    slack
    rectangle
    alfred
    stats
    notion
    figma
    jetbrains-toolbox
)

# 字体包列表
FONTS=(
    font-fira-code
    font-jetbrains-mono
    font-hack-nerd-font
    font-source-code-pro
)

# 安装命令行工具
if $INSTALL_CORE; then
    echo "安装命令行工具..."
    install_parallel "${CLI_TOOLS[@]}"
fi

# 安装开发语言和工具
if $INSTALL_LANGUAGES; then
    echo "安装开发语言和工具..."
    install_parallel "${DEV_TOOLS[@]}"
fi

# 安装数据库工具
if $INSTALL_DATABASES; then
    echo "安装数据库工具..."
    install_parallel "${DB_TOOLS[@]}"
fi

# 安装应用程序
if $INSTALL_APPS; then
    echo "通过Homebrew Cask安装应用程序..."
    for app in "${APPLICATIONS[@]}"; do
        install_or_upgrade_cask "$app"
    done
fi

# 安装开发字体
if $INSTALL_FONTS; then
    echo "安装开发字体..."
    brew tap homebrew/cask-fonts 2>/dev/null || true
    for font in "${FONTS[@]}"; do
        install_or_upgrade_cask "$font"
    done
fi

# 清理过时的版本
echo "清理过时的包版本..."
brew cleanup

echo "===== 开发必备工具安装完成 ====="

# 显示安装的包数量
echo "已安装 $(brew list | wc -l | xargs) 个包"
echo "详细安装日志保存在: $LOG_FILE"