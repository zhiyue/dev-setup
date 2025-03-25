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
FAILED_PACKAGES=() # 存储安装失败的包

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
    echo "警告: 命令失败，退出代码: $?" | tee -a "$LOG_FILE"
    echo "继续执行后续步骤，详情请查看日志文件: $LOG_FILE"
}

# 带重试功能的命令执行函数（不中断脚本）
retry_command() {
    local cmd="$1"
    local max_attempts=${2:-3}  # 默认最大尝试次数为3
    local wait_time=${3:-10}    # 默认重试等待时间为10秒
    local attempt=1
    local exit_code=0
    
    while [[ $attempt -le $max_attempts ]]; do
        echo "执行命令: $cmd (尝试 $attempt/$max_attempts)"
        eval "$cmd"
        exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            echo "命令成功执行!"
            return 0
        else
            echo "命令失败，退出代码: $exit_code"
            if [[ $attempt -lt $max_attempts ]]; then
                echo "等待 $wait_time 秒后重试..."
                sleep $wait_time
                # 下次等待时间增加50%
                wait_time=$(( wait_time + wait_time / 2 ))
                attempt=$((attempt + 1))
            else
                echo "已达到最大尝试次数 ($max_attempts)，但将继续执行后续步骤。"
                return $exit_code
            fi
        fi
    done
    
    return $exit_code
}

# 安装单个Brewfile文件中的包（允许部分失败）
install_brewfile() {
    local brewfile="$1"
    local description="$2"
    local force_flag="${3:-}"
    
    if [ ! -f "$brewfile" ]; then
        echo "警告: Brewfile不存在: $brewfile，跳过安装"
        return 1
    fi
    
    echo "===== 安装$description ====="
    echo "使用Brewfile: $brewfile"
    
    # 逐行读取Brewfile并逐个安装包
    # 跳过注释行和空行
    while IFS= read -r line; do
        # 跳过注释行和空行
        if [[ "$line" =~ ^[[:space:]]*# || -z "${line// /}" ]]; then
            continue
        fi
        
        # 提取包类型和名称
        local pkg_type=""
        local pkg_name=""
        
        if [[ "$line" =~ ^tap[[:space:]]+"([^"]+)" ]]; then
            pkg_type="tap"
            pkg_name="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^brew[[:space:]]+"([^"]+)" ]]; then
            pkg_type="brew"
            pkg_name="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^cask[[:space:]]+"([^"]+)" ]]; then
            pkg_type="cask"
            pkg_name="${BASH_REMATCH[1]}"
        else
            echo "跳过不支持的格式: $line"
            continue
        fi
        
        echo "正在安装 $pkg_type: $pkg_name"
        
        # 构建安装命令
        local install_cmd="brew install $pkg_name"
        if [[ "$pkg_type" == "tap" ]]; then
            install_cmd="brew tap $pkg_name"
        elif [[ "$pkg_type" == "cask" ]]; then
            install_cmd="brew install --cask $pkg_name"
        fi
        
        # 添加force重装参数
        if [[ -n "$force_flag" ]]; then
            install_cmd="$install_cmd $force_flag"
        fi
        
        # 尝试安装，如果失败则记录但继续
        if ! retry_command "$install_cmd" 3 10; then
            echo "警告: 安装 $pkg_type: $pkg_name 失败，将继续安装其他包"
            FAILED_PACKAGES+=("$pkg_type: $pkg_name")
        fi
    done < "$brewfile"
    
    echo "===== $description 安装完成 ====="
    return 0
}

# 初始化
setup_logging
echo "===== 开始安装开发必备工具 ====="

# 确保使用最新版本的Homebrew
echo "更新Homebrew..."
retry_command "brew update" 3 10

# 检查并创建 Brewfiles 目录（如果不存在）
if [ ! -d "$BREWFILES_DIR" ]; then
    echo "Brewfiles 目录不存在，创建目录..."
    mkdir -p "$BREWFILES_DIR"
    echo "警告: Brewfiles 目录是新创建的，可能需要手动添加 Brewfile 文件"
fi

# 安装各类包
force_flag=""
if ! $SKIP_EXISTING; then
    force_flag="--force"
fi

if $INSTALL_CORE && [ -f "${BREWFILES_DIR}/core.brewfile" ]; then
    install_brewfile "${BREWFILES_DIR}/core.brewfile" "核心命令行工具" "$force_flag"
fi

if $INSTALL_LANGUAGES && [ -f "${BREWFILES_DIR}/languages.brewfile" ]; then
    install_brewfile "${BREWFILES_DIR}/languages.brewfile" "开发语言和工具" "$force_flag"
fi

if $INSTALL_DATABASES && [ -f "${BREWFILES_DIR}/databases.brewfile" ]; then
    install_brewfile "${BREWFILES_DIR}/databases.brewfile" "数据库工具" "$force_flag"
fi

if $INSTALL_APPS && [ -f "${BREWFILES_DIR}/apps.brewfile" ]; then
    install_brewfile "${BREWFILES_DIR}/apps.brewfile" "应用程序" "$force_flag"
fi

if $INSTALL_FONTS && [ -f "${BREWFILES_DIR}/fonts.brewfile" ]; then
    install_brewfile "${BREWFILES_DIR}/fonts.brewfile" "开发字体" "$force_flag"
fi

# 清理过时的版本
echo "清理过时的包版本..."
retry_command "brew cleanup" 3 5

# 显示安装结果摘要
echo "===== 开发必备工具安装完成 ====="
echo "已安装 $(brew list | wc -l | xargs) 个包"

# 显示失败的包列表
if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo "===== 安装失败的包 ====="
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo "- $pkg"
    done
    echo "你可以稍后尝试手动安装这些包"
    echo "总计: ${#FAILED_PACKAGES[@]} 个包安装失败"
else
    echo "所有包安装成功！"
fi

echo "详细安装日志保存在: $LOG_FILE"