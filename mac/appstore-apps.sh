#!/bin/bash
# appstore-apps.sh - 使用mas-cli安装Mac App Store应用
# 作者：zhiyue
# 日期：2025-03-25

# 配置变量
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# 使用与主脚本相同的日志目录
LOG_DIR="$HOME/.dev_env_setup_logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG_FILE="$LOG_DIR/appstore_$(date +%Y%m%d%H%M%S).log"
APPSTORE_CONFIG="${SCRIPT_DIR}/Brewfiles/appstore.apps"
FAILED_APPS=() # 存储安装失败的应用
SKIPPED_APPS=() # 存储已安装的应用

# 解析命令行参数
SKIP_CONFIRMATION=false
SHOW_ONLY=false
SIGN_IN_ONLY=false
LIST_ONLY=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --auto-confirm) SKIP_CONFIRMATION=true ;;
        --show-only) SHOW_ONLY=true ;;
        --sign-in-only) SIGN_IN_ONLY=true ;;
        --list) LIST_ONLY=true ;;
        --help) 
            echo "用法: ./appstore-apps.sh [选项]"
            echo "选项:"
            echo "  --auto-confirm  自动确认安装所有应用，不提示"
            echo "  --show-only     只显示将要安装的应用，不安装"
            echo "  --sign-in-only  只执行登录App Store步骤，不安装应用"
            echo "  --list          列出当前已安装的App Store应用"
            echo "  --help          显示此帮助信息"
            exit 0
            ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

# 设置日志
setup_logging() {
    # 创建新的日志文件
    echo "===== App Store应用安装日志 $(date) =====" > "$LOG_FILE"
    # 同时将输出发送到终端和日志文件
    exec &> >(tee -a "$LOG_FILE")
}

# 带重试功能的命令执行函数
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

# 检查是否已安装mas-cli
check_mas_installed() {
    if ! command -v mas &> /dev/null; then
        echo "错误: mas-cli未安装，请先运行brew-essentials.sh安装mas"
        echo "可以使用以下命令单独安装mas: brew install mas"
        return 1
    fi
    return 0
}

# 检查App Store登录状态
check_appstore_signin() {
    echo "检查App Store登录状态..."
    if mas account &> /dev/null; then
        echo "已登录App Store: $(mas account)"
        return 0
    else
        echo "未登录App Store"
        return 1
    fi
}

# 登录App Store（交互式）
signin_appstore() {
    # 简单检查一下初始状态，如果已登录就直接返回
    if mas account &> /dev/null; then
        echo "已登录App Store: $(mas account)"
        return 0
    fi
    
    echo "======================================"
    echo "需要登录App Store才能安装应用"
    echo "请打开App Store应用并登录您的Apple ID账户"
    echo "======================================"
    
    # 打开App Store应用
    open -a "App Store"
    
    if ! $SKIP_CONFIRMATION; then
        echo "完成登录后请按任意键继续..."
        read -n 1 -s
    else
        echo "自动模式：请确保登录App Store（等待10秒）..."
        sleep 10
    fi
    
    echo "继续安装流程..."
    return 0
}

# 列出已安装的App Store应用
list_installed_apps() {
    echo "===== 已安装的App Store应用 ====="
    mas list
}

# 从配置文件读取App Store应用列表
# 格式: mas "应用名称" id=应用ID
read_appstore_apps() {
    local config_file="$1"
    declare -gA APPSTORE_APPS=()
    
    if [ ! -f "$config_file" ]; then
        echo "错误: 找不到App Store应用配置文件: $config_file"
        return 1
    fi
    
    echo "从配置文件读取App Store应用列表: $config_file"
    
    while IFS= read -r line; do
        # 跳过注释行和空行
        if [[ "$line" =~ ^[[:space:]]*# || -z "${line// /}" ]]; then
            continue
        fi
        
        # 提取应用名称和ID
        if [[ "$line" =~ mas[[:space:]]+\"([^\"]+)\"[[:space:]]+id=([0-9]+) ]]; then
            local app_name="${BASH_REMATCH[1]}"
            local app_id="${BASH_REMATCH[2]}"
            APPSTORE_APPS[$app_id]="$app_name"
            echo "已添加应用: $app_name (ID: $app_id)"
        else
            echo "警告: 跳过不符合格式的行: $line"
        fi
    done < "$config_file"
    
    echo "共读取 ${#APPSTORE_APPS[@]} 个App Store应用"
    return 0
}

# 显示将要安装的应用
show_apps_to_install() {
    echo "===== 将要安装的App Store应用 ====="
    for app_id in "${!APPSTORE_APPS[@]}"; do
        echo "- ${APPSTORE_APPS[$app_id]} (ID: $app_id)"
    done
    echo "共 ${#APPSTORE_APPS[@]} 个应用"
}

# 安装单个App Store应用
install_app() {
    local app_id="$1"
    local app_name="$2"
    
    # 检查应用是否已安装
    if mas list | grep -q "^$app_id"; then
        echo "应用 $app_name (ID: $app_id) 已安装，跳过"
        SKIPPED_APPS+=("$app_name (ID: $app_id)")
        return 0
    fi
    
    echo "正在安装 $app_name (ID: $app_id)..."
    if ! retry_command "mas install $app_id" 3 15; then
        echo "警告: 安装 $app_name 失败，将继续安装其他应用"
        FAILED_APPS+=("$app_name (ID: $app_id)")
        return 1
    fi
    
    return 0
}

# 安装所有App Store应用
install_all_apps() {
    echo "===== 开始安装App Store应用 ====="
    local total_apps=${#APPSTORE_APPS[@]}
    local current=1
    
    for app_id in "${!APPSTORE_APPS[@]}"; do
        echo "[$current/$total_apps] 处理应用: ${APPSTORE_APPS[$app_id]}"
        install_app "$app_id" "${APPSTORE_APPS[$app_id]}"
        current=$((current+1))
    done
    
    echo "===== App Store应用安装完成 ====="
}

# 主函数
main() {
    setup_logging
    echo "===== Mac App Store应用安装工具 ====="
    
    # 检查mas-cli是否已安装
    if ! check_mas_installed; then
        exit 1
    fi
    
    # 读取应用列表
    if ! read_appstore_apps "$APPSTORE_CONFIG"; then
        echo "错误: 无法读取App Store应用列表，退出"
        exit 1
    fi
    
    # 检查应用列表是否为空
    if [ ${#APPSTORE_APPS[@]} -eq 0 ]; then
        echo "警告: 应用列表为空，没有找到符合格式的应用条目"
        echo "请确认 $APPSTORE_CONFIG 文件包含有效的应用条目"
        echo "格式示例: mas \"应用名称\" id=应用ID"
        exit 0
    fi
    
    # 处理只列出已安装应用的情况
    if $LIST_ONLY; then
        list_installed_apps
        exit 0
    fi
    
    # 处理只显示将安装应用的情况
    if $SHOW_ONLY; then
        show_apps_to_install
        exit 0
    fi
    
    # 处理登录
    if ! signin_appstore; then
        if $SIGN_IN_ONLY; then
            echo "登录处理完成，退出"
            exit 0
        else
            echo "警告: 未能确认App Store登录状态，某些应用可能无法安装"
        fi
    elif $SIGN_IN_ONLY; then
        echo "登录处理完成，退出"
        exit 0
    fi
    
    # 显示将要安装的应用并请求确认
    show_apps_to_install
    
    if ! $SKIP_CONFIRMATION; then
        read -p "是否继续安装这些应用? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            echo "已取消安装"
            exit 0
        fi
    fi
    
    # 安装应用
    install_all_apps
    
    # 显示安装结果摘要
    echo "===== App Store应用安装摘要 ====="
    echo "请求安装: ${#APPSTORE_APPS[@]} 个应用"
    
    # 显示跳过的应用列表
    if [ ${#SKIPPED_APPS[@]} -gt 0 ]; then
        echo "===== 已安装的应用(已跳过) ====="
        for app in "${SKIPPED_APPS[@]}"; do
            echo "- $app"
        done
        echo "总计: ${#SKIPPED_APPS[@]} 个应用已安装"
    fi
    
    # 显示失败的应用列表
    if [ ${#FAILED_APPS[@]} -gt 0 ]; then
        echo "===== 安装失败的应用 ====="
        for app in "${FAILED_APPS[@]}"; do
            echo "- $app"
        done
        echo "你可以稍后尝试手动安装这些应用"
        echo "总计: ${#FAILED_APPS[@]} 个应用安装失败"
    else
        if [ ${#SKIPPED_APPS[@]} -eq ${#APPSTORE_APPS[@]} ]; then
            echo "所有应用已经安装，未执行任何新安装"
        else
            echo "所有新应用安装成功！"
        fi
    fi
    
    echo "详细安装日志保存在: $LOG_FILE"
}

# 执行主函数
main
