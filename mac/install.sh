#!/bin/bash

# Mac开发环境设置主脚本
# 作者：zhiyue
# 日期：2025-03-05

# 获取脚本目录和仓库根目录路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/*}"
LOG_DIR="$HOME/.dev_env_setup_logs"
MAIN_LOG="$LOG_DIR/setup_$(date +%Y%m%d%H%M%S).log"
CONFIG_FILE="${REPO_ROOT}/config.yml"
STATUS_FILE="$LOG_DIR/setup_status.json"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

# 可配置选项
INSTALL_XCODE=true
INSTALL_HOMEBREW=true
INSTALL_DEVTOOLS=true
CONFIGURE_MACOS=true
CONFIGURE_GIT=true
INSTALL_VSCODE_EXT=true
VERBOSE=false
SKIP_CONFIRMATION=false
SKIP_ENV_CHECK=false
RESUME_MODE=false

# 确保jq可用（用于JSON处理）
ensure_jq() {
    if ! command -v jq &> /dev/null; then
        echo "检测到缺少必要工具 jq，尝试安装..."
        if command -v brew &> /dev/null; then
            brew install jq
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        else
            echo "警告: 无法自动安装 jq，将使用备用方法处理状态文件"
            return 1
        fi
    fi
    return 0
}

# 支持命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-xcode) INSTALL_XCODE=false ;;
        --no-homebrew) INSTALL_HOMEBREW=false ;;
        --no-devtools) INSTALL_DEVTOOLS=false ;;
        --no-macos) CONFIGURE_MACOS=false ;;
        --no-git) CONFIGURE_GIT=false ;;
        --no-vscode) INSTALL_VSCODE_EXT=false ;;
        --config=*) CONFIG_FILE="${1#*=}" ;;
        --verbose) VERBOSE=true ;;
        --yes) SKIP_CONFIRMATION=true ;;
        --no-env-check) SKIP_ENV_CHECK=true ;;
        --help)
            echo "用法: ./install.sh [选项]"
            echo "选项:"
            echo "  --no-xcode        不安装Xcode命令行工具"
            echo "  --no-homebrew     不安装Homebrew"
            echo "  --no-devtools     不安装开发工具"
            echo "  --no-macos        不配置macOS系统设置"
            echo "  --no-git          不配置Git"
            echo "  --no-vscode       不安装VS Code扩展"
            echo "  --config=文件     指定配置文件路径"
            echo "  --verbose         显示详细输出"
            echo "  --yes             跳过所有确认提示"
            echo "  --no-env-check    跳过环境检查"
            echo "  --resume          从上次中断的位置继续"
            exit 0
            ;;
        --resume)
            RESUME_MODE=true
            if [[ -f "$STATUS_FILE" ]]; then
                echo "正在从上次中断的位置继续安装..."
                
                # 尝试使用jq解析JSON状态文件
                if ensure_jq; then
                    # 加载各个模块的安装状态
                    INSTALL_XCODE=$(jq -r '.steps.xcode.completed // "false"' "$STATUS_FILE")
                    INSTALL_HOMEBREW=$(jq -r '.steps.homebrew.completed // "false"' "$STATUS_FILE")
                    INSTALL_DEVTOOLS=$(jq -r '.steps.devtools.completed // "false"' "$STATUS_FILE")
                    CONFIGURE_MACOS=$(jq -r '.steps.macos.completed // "false"' "$STATUS_FILE")
                    CONFIGURE_GIT=$(jq -r '.steps.git.completed // "false"' "$STATUS_FILE")
                    INSTALL_VSCODE_EXT=$(jq -r '.steps.vscode.completed // "false"' "$STATUS_FILE")
                    
                    # 加载用户定制选项
                    local brew_params=$(jq -r '.user_choices.brew_params // ""' "$STATUS_FILE")
                    local macos_params=$(jq -r '.user_choices.macos_params // ""' "$STATUS_FILE")
                    
                    # 显示恢复信息
                    local last_step=$(jq -r '.last_completed_step // "none"' "$STATUS_FILE")
                    local timestamp=$(jq -r '.last_update_time // "unknown"' "$STATUS_FILE")
                    echo "上次安装于 $timestamp 中断在步骤: $last_step"
                    
                    # 转换布尔值：如果已完成（true），则将安装标志设为false跳过该步骤
                    [[ "$INSTALL_XCODE" == "true" ]] && INSTALL_XCODE=false
                    [[ "$INSTALL_HOMEBREW" == "true" ]] && INSTALL_HOMEBREW=false
                    [[ "$INSTALL_DEVTOOLS" == "true" ]] && INSTALL_DEVTOOLS=false
                    [[ "$CONFIGURE_MACOS" == "true" ]] && CONFIGURE_MACOS=false
                    [[ "$CONFIGURE_GIT" == "true" ]] && CONFIGURE_GIT=false
                    [[ "$INSTALL_VSCODE_EXT" == "true" ]] && INSTALL_VSCODE_EXT=false
                    
                    echo "将继续以下未完成的步骤:"
                    $INSTALL_XCODE && echo "- 安装Xcode命令行工具"
                    $INSTALL_HOMEBREW && echo "- 安装Homebrew包管理器"
                    $INSTALL_DEVTOOLS && echo "- 安装开发工具和应用程序"
                    $CONFIGURE_MACOS && echo "- 配置macOS系统设置"
                    $CONFIGURE_GIT && echo "- 配置Git"
                    $INSTALL_VSCODE_EXT && echo "- 安装VS Code扩展"
                else
                    # 备用方式：尝试作为shell脚本解析
                    echo "警告: 使用备用方式读取状态文件"
                    source "$STATUS_FILE"
                    echo "已加载状态: INSTALL_XCODE=$INSTALL_XCODE, INSTALL_HOMEBREW=$INSTALL_HOMEBREW..."
                fi
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

# 初始化状态文件
init_status_file() {
    if ensure_jq; then
        # 创建全新的JSON状态文件
        cat > "$STATUS_FILE" <<EOL
{
  "install_id": "${TIMESTAMP}",
  "start_time": "$(date +"%Y-%m-%d %H:%M:%S")",
  "last_update_time": "$(date +"%Y-%m-%d %H:%M:%S")",
  "last_completed_step": "init",
  "steps": {
    "env_check": { "completed": false, "time": "" },
    "xcode": { "completed": false, "time": "" },
    "homebrew": { "completed": false, "time": "" },
    "devtools": { "completed": false, "time": "" },
    "macos": { "completed": false, "time": "" },
    "git": { "completed": false, "time": "" },
    "vscode": { "completed": false, "time": "" }
  },
  "user_choices": {
    "brew_params": "",
    "macos_params": ""
  },
  "system_info": {
    "os_version": "$(sw_vers -productVersion 2>/dev/null || echo 'unknown')",
    "cpu_arch": "$(uname -m 2>/dev/null || echo 'unknown')"
  }
}
EOL
    else
        # 备用方式：创建shell格式的状态文件
        echo "#!/bin/bash" > "$STATUS_FILE"
        echo "# 自动生成的安装状态文件 - $(date)" >> "$STATUS_FILE"
        echo "INSTALL_XCODE=true" >> "$STATUS_FILE"
        echo "INSTALL_HOMEBREW=true" >> "$STATUS_FILE"
        echo "INSTALL_DEVTOOLS=true" >> "$STATUS_FILE"
        echo "CONFIGURE_MACOS=true" >> "$STATUS_FILE"
        echo "CONFIGURE_GIT=true" >> "$STATUS_FILE"
        echo "INSTALL_VSCODE_EXT=true" >> "$STATUS_FILE"
        echo "BREW_PARAMS=\"\"" >> "$STATUS_FILE"
        echo "MACOS_PARAMS=\"\"" >> "$STATUS_FILE"
        echo "LAST_STEP=\"init\"" >> "$STATUS_FILE"
        echo "TIMESTAMP=\"$(date +"%Y-%m-%d %H:%M:%S")\"" >> "$STATUS_FILE"
    fi
}

# 更新安装状态
update_status() {
    local step=$1
    local completed=$2
    local additional_data=$3
    
    # 获取当前时间
    local current_time=$(date +"%Y-%m-%d %H:%M:%S")
    
    if ensure_jq; then
        # 使用临时文件避免管道问题
        local temp_file=$(mktemp)
        
        # 更新JSON状态文件
        jq --arg time "$current_time" \
           --arg step "$step" \
           --arg completed "$completed" \
           --arg additional "$additional_data" \
           '.last_update_time = $time | .last_completed_step = $step | .steps[$step].completed = $completed | .steps[$step].time = $time | if $additional != "" then .user_choices += ($additional | fromjson) else . end' \
           "$STATUS_FILE" > "$temp_file" && mv "$temp_file" "$STATUS_FILE"
    else
        # 备用方式：更新shell格式的状态文件
        if [[ "$step" == "INSTALL_XCODE" ]]; then
            sed -i '' "s/INSTALL_XCODE=.*/INSTALL_XCODE=$completed/" "$STATUS_FILE"
        elif [[ "$step" == "INSTALL_HOMEBREW" ]]; then
            sed -i '' "s/INSTALL_HOMEBREW=.*/INSTALL_HOMEBREW=$completed/" "$STATUS_FILE"
        elif [[ "$step" == "INSTALL_DEVTOOLS" ]]; then
            sed -i '' "s/INSTALL_DEVTOOLS=.*/INSTALL_DEVTOOLS=$completed/" "$STATUS_FILE"
        elif [[ "$step" == "CONFIGURE_MACOS" ]]; then
            sed -i '' "s/CONFIGURE_MACOS=.*/CONFIGURE_MACOS=$completed/" "$STATUS_FILE"
        elif [[ "$step" == "CONFIGURE_GIT" ]]; then
            sed -i '' "s/CONFIGURE_GIT=.*/CONFIGURE_GIT=$completed/" "$STATUS_FILE"
        elif [[ "$step" == "INSTALL_VSCODE_EXT" ]]; then
            sed -i '' "s/INSTALL_VSCODE_EXT=.*/INSTALL_VSCODE_EXT=$completed/" "$STATUS_FILE"
        fi
        
        if [[ "$additional_data" == *"brew_params"* ]]; then
            brew_param_value=$(echo "$additional_data" | grep -o '"brew_params":"[^"]*"' | cut -d'"' -f4)
            sed -i '' "s/BREW_PARAMS=.*/BREW_PARAMS=\"$brew_param_value\"/" "$STATUS_FILE"
        fi
        
        if [[ "$additional_data" == *"macos_params"* ]]; then
            macos_param_value=$(echo "$additional_data" | grep -o '"macos_params":"[^"]*"' | cut -d'"' -f4)
            sed -i '' "s/MACOS_PARAMS=.*/MACOS_PARAMS=\"$macos_param_value\"/" "$STATUS_FILE"
        fi
        
        sed -i '' "s/LAST_STEP=.*/LAST_STEP=\"$step\"/" "$STATUS_FILE"
        sed -i '' "s/TIMESTAMP=.*/TIMESTAMP=\"$(date +"%Y-%m-%d %H:%M:%S")\"/" "$STATUS_FILE"
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
        exec &>> "$MAIN_LOG"
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
    
    # 记录错误状态
    if ensure_jq; then
        local temp_file=$(mktemp)
        jq --arg time "$(date +"%Y-%m-%d %H:%M:%S")" \
           --arg error "命令失败，退出代码: $exit_code" \
           '.last_error = $error | .last_error_time = $time' \
           "$STATUS_FILE" > "$temp_file" && mv "$temp_file" "$STATUS_FILE"
    else
        echo "ERROR_CODE=$exit_code" >> "$STATUS_FILE"
        echo "ERROR_TIME=\"$(date +"%Y-%m-%d %H:%M:%S")\"" >> "$STATUS_FILE"
    fi
    
    echo "可以使用 './install.sh --resume' 从上次中断的位置继续安装"
    exit $exit_code
}

# 设置错误捕获
trap handle_error ERR

# 初始化日志
setup_logging

# 如果不是恢复模式，初始化状态文件
if ! $RESUME_MODE; then
    init_status_file
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
fi

# 确认安装计划
if ! $SKIP_CONFIRMATION; then
    echo -e "\n将执行以下安装步骤:"
    $INSTALL_XCODE && echo "- 安装Xcode命令行工具"
    $INSTALL_HOMEBREW && echo "- 安装Homebrew包管理器"
    $INSTALL_DEVTOOLS && echo "- 安装开发工具和应用程序"
    $CONFIGURE_MACOS && echo "- 配置macOS系统设置"
    $CONFIGURE_GIT && echo "- 配置Git"
    $INSTALL_VSCODE_EXT && echo "- 安装VS Code扩展"
    
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
    
    update_status "INSTALL_XCODE" "true"
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
    
    update_status "INSTALL_HOMEBREW" "true"
fi

# 运行Homebrew必备软件安装脚本
if $INSTALL_DEVTOOLS; then
    show_status "安装开发工具"
    
    # 检查用户是否想要自定义安装
    BREW_PARAMS=""
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
    
    update_status "INSTALL_DEVTOOLS" "true" "{\"brew_params\":\"$BREW_PARAMS\"}"
fi

# 运行macOS系统设置脚本
if $CONFIGURE_MACOS; then
    show_status "配置macOS系统设置"
    
    # 检查用户是否想要自定义系统设置
    MACOS_PARAMS=""
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
            # 如果不自定义，添加--yes跳过确认
            MACOS_PARAMS="--yes"
        fi
    else
        # 如果全局跳过确认，也跳过macOS设置中的确认
        MACOS_PARAMS="--yes"
    fi
    
    # 运行macOS设置脚本
    bash "$SCRIPT_DIR/macos-defaults.sh" $MACOS_PARAMS
    
    update_status "CONFIGURE_MACOS" "true" "{\"macos_params\":\"$MACOS_PARAMS\"}"
fi

# 运行共享Git配置脚本
if $CONFIGURE_GIT; then
    show_status "配置Git"
    bash "$REPO_ROOT/common/git-config.sh"
    update_status "CONFIGURE_GIT" "true"
fi

# 安装VS Code扩展
if $INSTALL_VSCODE_EXT; then
    show_status "检查VS Code"
    
    if command -v code &>/dev/null; then
        show_status "安装VS Code扩展"
        bash "$REPO_ROOT/common/vscode-extensions.sh"
    else
        echo "VS Code未安装或不在PATH中，跳过扩展安装"
    fi
    
    update_status "INSTALL_VSCODE_EXT" "true"
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