#!/bin/bash

# Mac开发环境设置主脚本
# 作者：zhiyue
# 日期：2025-03-05

# 获取脚本目录和仓库根目录路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/*}"
LOG_DIR="$HOME/.dev_env_setup_logs"
MAIN_LOG="$LOG_DIR/setup_$(date +%Y%m%d%H%M%S).log"
STATUS_DIR="$LOG_DIR/status"
STATUS_FILE="$STATUS_DIR/current_status"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

# 可配置选项
INSTALL_XCODE=true
INSTALL_HOMEBREW=true
INSTALL_DEVTOOLS=true
INSTALL_APPSTORE=true
CONFIGURE_MACOS=true
CONFIGURE_1PASSWORD_SSH=false
VERBOSE=false
SKIP_CONFIRMATION=false
SKIP_ENV_CHECK=false
RESUME_MODE=false

# 用户选择的参数
BREW_PARAMS=""
MACOS_PARAMS=""
APPSTORE_PARAMS=""

# 支持命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-xcode) INSTALL_XCODE=false ;;
        --no-homebrew) INSTALL_HOMEBREW=false ;;
        --no-devtools) INSTALL_DEVTOOLS=false ;;
        --no-macos) CONFIGURE_MACOS=false ;;
        --no-appstore) INSTALL_APPSTORE=false ;;
        --1password-ssh) CONFIGURE_1PASSWORD_SSH=true ;;
        --verbose) VERBOSE=true ;;
        --yes) SKIP_CONFIRMATION=true ;;
        --no-env-check) SKIP_ENV_CHECK=true ;;
        --help)
            echo "用法: ./install.sh [选项]"
            echo "选项:"
            echo "  --no-xcode        不安装Xcode命令行工具"
            echo "  --no-homebrew     不安装Homebrew"
            echo "  --no-devtools     不安装开发工具"
            echo "  --no-appstore     不安装App Store应用"
            echo "  --no-macos        不配置macOS系统设置"
            echo "  --1password-ssh   配置1Password SSH代理集成"
            echo "  --verbose         显示详细输出"
            echo "  --yes             跳过所有确认提示"
            echo "  --no-env-check    跳过环境检查"
            exit 0
            ;;
        --resume)
            RESUME_MODE=true
            if [[ -d "$STATUS_DIR" ]]; then
                echo "正在从上次中断的位置继续安装..."
                
                # 获取上次安装的状态信息
                if [[ -f "$STATUS_DIR/last_step" ]]; then
                    LAST_STEP=$(cat "$STATUS_DIR/last_step")
                    LAST_TIME=$(cat "$STATUS_DIR/last_time" 2>/dev/null || echo "未知时间")
                    echo "上次安装于 $LAST_TIME 中断在步骤: $LAST_STEP"
                fi
                
                # 加载模块完成状态
                if [[ -f "$STATUS_DIR/xcode_done" ]]; then INSTALL_XCODE=false; fi
                if [[ -f "$STATUS_DIR/homebrew_done" ]]; then INSTALL_HOMEBREW=false; fi
                if [[ -f "$STATUS_DIR/devtools_done" ]]; then INSTALL_DEVTOOLS=false; fi
                if [[ -f "$STATUS_DIR/appstore_done" ]]; then INSTALL_APPSTORE=false; fi
                if [[ -f "$STATUS_DIR/macos_done" ]]; then CONFIGURE_MACOS=false; fi
                if [[ -f "$STATUS_DIR/1password_ssh_done" ]]; then CONFIGURE_1PASSWORD_SSH=false; fi
                
                # 加载用户自定义选项
                if [[ -f "$STATUS_DIR/brew_params" ]]; then
                    BREW_PARAMS=$(cat "$STATUS_DIR/brew_params")
                fi
                if [[ -f "$STATUS_DIR/macos_params" ]]; then
                    MACOS_PARAMS=$(cat "$STATUS_DIR/macos_params")
                fi
                if [[ -f "$STATUS_DIR/appstore_params" ]]; then
                    APPSTORE_PARAMS=$(cat "$STATUS_DIR/appstore_params")
                fi
                
                echo "将继续以下未完成的步骤:"
                $INSTALL_XCODE && echo "- 安装Xcode命令行工具"
                $INSTALL_HOMEBREW && echo "- 安装Homebrew包管理器"
                $INSTALL_DEVTOOLS && echo "- 安装开发工具和应用程序"
                $INSTALL_APPSTORE && echo "- 安装App Store应用"
                $CONFIGURE_MACOS && echo "- 配置macOS系统设置"
                $CONFIGURE_1PASSWORD_SSH && echo "- 配置1Password SSH代理集成"
            else
                echo "未找到上次的安装状态，将从头开始安装"
                RESUME_MODE=false
            fi
            ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

# 创建日志目录
mkdir -p "$LOG_DIR"
mkdir -p "$STATUS_DIR"

# 初始化状态目录
init_status_dir() {
    # 清理旧状态文件
    rm -rf "$STATUS_DIR"/*
    
    # 记录初始状态
    echo "init" > "$STATUS_DIR/last_step"
    date "+%Y-%m-%d %H:%M:%S" > "$STATUS_DIR/last_time"
    echo "$(sw_vers -productVersion 2>/dev/null || echo 'unknown')" > "$STATUS_DIR/os_version"
    echo "$(uname -m 2>/dev/null || echo 'unknown')" > "$STATUS_DIR/cpu_arch"
    echo "$TIMESTAMP" > "$STATUS_DIR/install_id"
    date "+%Y-%m-%d %H:%M:%S" > "$STATUS_DIR/start_time"
}

# 更新安装状态
update_status() {
    local step=$1
    local completed=$2
    shift 2
    local params=("$@")
    
    # 更新最后完成的步骤和时间
    echo "$step" > "$STATUS_DIR/last_step"
    date "+%Y-%m-%d %H:%M:%S" > "$STATUS_DIR/last_time"
    
    # 如果步骤完成，创建对应的标记文件
    if [[ "$completed" == "true" ]]; then
        case "$step" in
            "env_check") touch "$STATUS_DIR/env_check_done" ;;
            "xcode") touch "$STATUS_DIR/xcode_done" ;;
            "rosetta") touch "$STATUS_DIR/rosetta_done" ;;
            "homebrew") touch "$STATUS_DIR/homebrew_done" ;;
            "devtools") 
                touch "$STATUS_DIR/devtools_done"
                # 保存brew参数
                if [[ -n "$BREW_PARAMS" ]]; then
                    echo "$BREW_PARAMS" > "$STATUS_DIR/brew_params"
                fi
                ;;
            "appstore") 
                touch "$STATUS_DIR/appstore_done"
                # 保存appstore参数
                if [[ -n "$APPSTORE_PARAMS" ]]; then
                    echo "$APPSTORE_PARAMS" > "$STATUS_DIR/appstore_params"
                fi
                ;;
            "macos") 
                touch "$STATUS_DIR/macos_done"
                # 保存macos参数
                if [[ -n "$MACOS_PARAMS" ]]; then
                    echo "$MACOS_PARAMS" > "$STATUS_DIR/macos_params"
                fi
                ;;
            "1password_ssh") touch "$STATUS_DIR/1password_ssh_done" ;;
        esac
    fi
}

# 初始化日志
setup_logging() {
    echo "=== 开始Mac开发环境设置 $(date) ===" > "$MAIN_LOG"
    
    # 如果开启详细模式，同时输出到终端和日志
    if $VERBOSE; then
        exec &> >(tee -a "$MAIN_LOG")
    else
        # 否则只记录到日志，但仍在终端显示关键信息
        # 使用更兼容的重定向语法
        exec > "$MAIN_LOG" 2>&1
    fi
}

# 显示状态消息
show_status() {
    local message=$1
    echo -e "\n=== $message ==="
    # 确保即使非详细模式也在终端显示
    if ! $VERBOSE; then
        echo -e "=== $message ===" >&2
    fi
}

# 请求确认
confirm() {
    if $SKIP_CONFIRMATION; then
        return 0
    fi
    
    local message=$1
    read -p "$message [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 错误处理
handle_error() {
    local exit_code=$?
    echo "错误: 命令失败，退出代码: $exit_code"
    echo "查看日志获取详细信息: $MAIN_LOG"
    
    # 记录错误信息
    echo "$exit_code" > "$STATUS_DIR/error_code"
    date "+%Y-%m-%d %H:%M:%S" > "$STATUS_DIR/error_time"
    
    echo "可以使用 './install.sh --resume' 从上次中断的位置继续安装"
    exit $exit_code
}

# 设置错误捕获
trap handle_error ERR

# 初始化日志
setup_logging

# 如果不是恢复模式，初始化状态目录
if ! $RESUME_MODE; then
    init_status_dir
fi

# 显示欢迎信息
show_status "开始Mac开发环境设置"

# 运行环境检查
if ! $SKIP_ENV_CHECK; then
    show_status "检查环境状态"
    echo "运行环境检查以确保系统满足安装要求..."
    bash "$SCRIPT_DIR/check-environment.sh"
    
    if ! confirm "是否继续安装? (如果环境检查显示严重问题，建议先解决这些问题)"; then
        echo "安装已取消"
        exit 0
    fi
    
    update_status "env_check" "true"
fi

# 确认安装计划
if ! $SKIP_CONFIRMATION; then
    echo -e "\n将执行以下安装步骤:"
    $INSTALL_XCODE && echo "- 安装Xcode命令行工具"
    $INSTALL_HOMEBREW && echo "- 安装Homebrew包管理器"
    $INSTALL_DEVTOOLS && echo "- 安装开发工具和应用程序"
    $INSTALL_APPSTORE && echo "- 安装App Store应用"
    $CONFIGURE_MACOS && echo "- 配置macOS系统设置"
    $CONFIGURE_1PASSWORD_SSH && echo "- 配置1Password SSH代理集成"
    
    if ! confirm "是否继续安装?"; then
        echo "安装已取消"
        exit 0
    fi
fi

# 检查是否已安装Xcode Command Line Tools
if $INSTALL_XCODE; then
    show_status "检查Xcode Command Line Tools"
    
    if xcode-select -p &>/dev/null; then
        echo "Xcode Command Line Tools已安装"
    else
        echo "正在安装Xcode Command Line Tools..."
        xcode-select --install
        
        echo "请等待Xcode Command Line Tools安装完成，然后按任意键继续..."
        read -n 1
    fi
    
    update_status "xcode" "true"
fi

# 检查并安装Rosetta 2（仅适用于Apple Silicon Mac）
show_status "检查是否需要安装Rosetta 2"

# 检测是否为Apple Silicon Mac
if [[ "$(uname -m)" == "arm64" ]]; then
    echo "检测到Apple Silicon Mac，检查Rosetta 2状态..."
    
    # 检查Rosetta 2是否已安装
    if /usr/bin/pgrep -q oahd; then
        echo "Rosetta 2已安装"
    else
        echo "正在安装Rosetta 2..."
        # 使用softwareupdate命令安装Rosetta 2，自动同意许可协议
        /usr/sbin/softwareupdate --install-rosetta --agree-to-license
        
        if /usr/bin/pgrep -q oahd; then
            echo "Rosetta 2安装成功"
        else
            echo "警告：Rosetta 2可能未成功安装，某些Intel应用可能无法运行"
        fi
    fi
    
    update_status "rosetta" "true"
else
    echo "检测到Intel Mac，不需要安装Rosetta 2"
fi

# 检查是否已安装Homebrew
if $INSTALL_HOMEBREW; then
    show_status "检查Homebrew"
    
    if command -v brew &>/dev/null; then
        echo "Homebrew已安装，正在更新..."
        brew update
    else
        echo "正在安装Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 根据芯片类型添加Homebrew到PATH
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    update_status "homebrew" "true"
fi

# 运行Homebrew必备软件安装脚本
if $INSTALL_DEVTOOLS; then
    show_status "安装开发工具"
    
    # 检查用户是否想要自定义安装
    if ! $SKIP_CONFIRMATION; then
        if confirm "是否要自定义开发工具安装 (否则将安装所有推荐工具)?"; then
            read -p "跳过核心命令行工具? [y/N] " skip_core
            [[ "$skip_core" =~ ^[Yy] ]] && BREW_PARAMS="$BREW_PARAMS --no-core"
            
            read -p "跳过编程语言? [y/N] " skip_langs
            [[ "$skip_langs" =~ ^[Yy] ]] && BREW_PARAMS="$BREW_PARAMS --no-languages"
            
            read -p "跳过数据库工具? [y/N] " skip_db
            [[ "$skip_db" =~ ^[Yy] ]] && BREW_PARAMS="$BREW_PARAMS --no-databases"
            
            read -p "跳过应用程序? [y/N] " skip_apps
            [[ "$skip_apps" =~ ^[Yy] ]] && BREW_PARAMS="$BREW_PARAMS --no-apps"
            
            read -p "跳过开发字体? [y/N] " skip_fonts
            [[ "$skip_fonts" =~ ^[Yy] ]] && BREW_PARAMS="$BREW_PARAMS --no-fonts"
            
            read -p "启用快速(并行)安装模式? [y/N] " fast_mode
            [[ "$fast_mode" =~ ^[Yy] ]] && BREW_PARAMS="$BREW_PARAMS --fast"
        fi
    fi
    
    # 运行Homebrew安装脚本
    bash "$SCRIPT_DIR/brew-essentials.sh" $BREW_PARAMS
    
    update_status "devtools" "true"
fi

# 安装App Store应用
if $INSTALL_APPSTORE; then
    show_status "安装App Store应用"
    
    # 检查用户是否想要自定义安装
    if ! $SKIP_CONFIRMATION; then
        if confirm "是否要自定义App Store应用安装 (否则将安装所有推荐应用)?"; then
            read -p "是否仅执行App Store登录? [y/N] " sign_in_only
            [[ "$sign_in_only" =~ ^[Yy] ]] && APPSTORE_PARAMS="$APPSTORE_PARAMS --sign-in-only"
            
            read -p "是否仅显示应用列表而不安装? [y/N] " show_only
            [[ "$show_only" =~ ^[Yy] ]] && APPSTORE_PARAMS="$APPSTORE_PARAMS --show-only"
        fi
    else
        # 如果全局跳过确认，也跳过App Store安装中的确认
        APPSTORE_PARAMS="--auto-confirm"
    fi
    
    # 运行App Store应用安装脚本
    bash "$SCRIPT_DIR/appstore-apps.sh" $APPSTORE_PARAMS
    
    # 保存参数并更新状态
    if [[ -n "$APPSTORE_PARAMS" ]]; then
        echo "$APPSTORE_PARAMS" > "$STATUS_DIR/appstore_params"
    fi
    update_status "appstore" "true"
fi

# 运行macOS系统设置脚本
if $CONFIGURE_MACOS; then
    show_status "配置macOS系统设置"
    
    # 检查用户是否想要自定义系统设置
    if ! $SKIP_CONFIRMATION; then
        if confirm "是否要自定义macOS系统设置 (否则将应用所有推荐设置)?"; then
            read -p "跳过UI/UX设置? [y/N] " skip_ui
            [[ "$skip_ui" =~ ^[Yy] ]] && MACOS_PARAMS="$MACOS_PARAMS --no-ui"
            
            read -p "跳过Finder设置? [y/N] " skip_finder
            [[ "$skip_finder" =~ ^[Yy] ]] && MACOS_PARAMS="$MACOS_PARAMS --no-finder"
            
            read -p "跳过Dock设置? [y/N] " skip_dock
            [[ "$skip_dock" =~ ^[Yy] ]] && MACOS_PARAMS="$MACOS_PARAMS --no-dock"
            
            read -p "跳过终端设置? [y/N] " skip_terminal
            [[ "$skip_terminal" =~ ^[Yy] ]] && MACOS_PARAMS="$MACOS_PARAMS --no-terminal"
            
            read -p "跳过开发者设置? [y/N] " skip_dev
            [[ "$skip_dev" =~ ^[Yy] ]] && MACOS_PARAMS="$MACOS_PARAMS --no-dev"
        else
            # 如果不自定义，添加--auto-apply但不跳过重启确认
            MACOS_PARAMS="--auto-apply"
        fi
    else
        # 如果全局跳过确认，也跳过macOS设置中的确认，但不跳过重启确认
        MACOS_PARAMS="--auto-apply"
    fi
    
    # 运行macOS设置脚本
    bash "$SCRIPT_DIR/macos-defaults.sh" $MACOS_PARAMS
    
    update_status "macos" "true"
fi

# 配置1Password SSH代理集成
if $CONFIGURE_1PASSWORD_SSH; then
    show_status "配置1Password SSH代理集成"
    
    # 检查1Password是否已安装
    if ! [ -d "/Applications/1Password.app" ]; then
        echo "警告: 未检测到1Password应用，将跳过SSH代理设置"
        echo "如需配置，请先安装1Password，然后重新运行此脚本并使用 --1password-ssh 选项"
    else
        # 询问是否继续配置
        if ! $SKIP_CONFIRMATION; then
            if confirm "是否继续配置1Password SSH代理集成? (需要1Password应用已安装)"; then
                # 运行1Password SSH代理设置脚本
                bash "$SCRIPT_DIR/1password-ssh-setup.sh"
                update_status "1password_ssh" "true"
            else
                echo "已跳过1Password SSH代理配置"
            fi
        else
            # 如果全局跳过确认，直接运行脚本
            bash "$SCRIPT_DIR/1password-ssh-setup.sh"
            update_status "1password_ssh" "true"
        fi
    fi
fi

show_status "Mac开发环境设置完成"
echo "所有步骤已完成!"
echo "详细安装日志保存在: $MAIN_LOG"
echo "建议重启系统以确保所有设置生效"

# 提示重启
if ! $SKIP_CONFIRMATION; then
    if confirm "是否立即重启系统?"; then
        sudo shutdown -r now
    fi
fi