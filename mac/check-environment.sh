#!/bin/bash
# check-environment.sh - 检测当前Mac开发环境状态
# 用于安装前或安装后的系统检查

# 设置输出颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # 恢复正常颜色

# 系统配置阈值
MIN_MEMORY_GB=8
WARN_DISK_SPACE_GB=20
RECOMMENDED_DISK_SPACE_GB=50
MIN_MACOS_MAJOR=11

# 全局变量
SKIP_BREW_DOCTOR=false
SKIP_VSCODE=false
CHECK_NETWORK=true
VERBOSE=true
SHOW_HELP=false
START_TIME=$(date +%s)

# 使用说明
show_help() {
    echo "用法: ./check-environment.sh [选项]"
    echo "选项:"
    echo "  -h, --help           显示此帮助信息"
    echo "  -q, --quiet          静默模式，减少输出"
    echo "  -s, --skip-brew      跳过brew doctor检查 (节省时间)"
    echo "  -n, --no-network     跳过网络连接检查"
    echo "  --skip-vscode        跳过VS Code扩展检查"
    exit 0
}

# 输出带时间的日志
log() {
    local level=$1
    local message=$2
    local color=$NC
    local prefix=""
    
    case $level in
        "info") 
            color=$GREEN
            prefix="[信息]"
            ;;
        "warn") 
            color=$YELLOW
            prefix="[警告]"
            ;;
        "error") 
            color=$RED
            prefix="[错误]"
            ;;
        "step") 
            color=$BLUE
            prefix="[步骤]"
            ;;
    esac
    
    if [[ $VERBOSE == true || $level == "error" || $level == "step" ]]; then
        echo -e "${color}${prefix} ${message}${NC}"
    fi
}

# 解析命令行参数
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) SHOW_HELP=true; shift ;;
            -q|--quiet) VERBOSE=false; shift ;;
            -s|--skip-brew) SKIP_BREW_DOCTOR=true; shift ;;
            -n|--no-network) CHECK_NETWORK=false; shift ;;
            --skip-vscode) SKIP_VSCODE=true; shift ;;
            *) log "error" "未知选项: $1"; show_help; shift ;;
        esac
    done
    
    if [[ $SHOW_HELP == true ]]; then
        show_help
    fi
}

# 计算运行时间
calculate_runtime() {
    local end_time=$(date +%s)
    local runtime=$((end_time - START_TIME))
    echo "总运行时间: ${runtime}秒"
}

# 获取macOS版本信息 (缓存避免重复调用)
get_macos_version() {
    if [[ -z "$MACOS_VERSION" ]]; then
        MACOS_VERSION=$(sw_vers -productVersion)
        MACOS_MAJOR=$(echo $MACOS_VERSION | cut -d. -f1)
        MACOS_MINOR=$(echo $MACOS_VERSION | cut -d. -f2)
    fi
}

# 检查macOS版本
check_macos_version() {
    log "step" "===== 系统信息 ====="
    sw_vers
    
    # 获取macOS版本信息并缓存
    get_macos_version
    
    if [[ $MACOS_MAJOR -lt $MIN_MACOS_MAJOR ]]; then
        log "warn" "此脚本设计用于macOS ${MIN_MACOS_MAJOR}.0 (Big Sur)或更高版本"
        log "warn" "当前运行的是macOS $MACOS_VERSION"
        log "warn" "某些功能可能不工作，建议升级系统"
    else
        log "info" "当前macOS版本($MACOS_VERSION)受支持"
    fi
}

# 检查硬件信息
check_hardware() {
    log "step" "===== 硬件信息 ====="
    
    # CPU架构
    cpu_type=$(uname -m)
    if [[ "$cpu_type" == "arm64" ]]; then
        log "info" "CPU: Apple Silicon ($cpu_type)"
    else
        log "info" "CPU: Intel ($cpu_type)"
    fi
    
    # 内存
    ram=$(sysctl hw.memsize | awk '{print $2 / 1024 / 1024 / 1024}')
    ram_gb=$(printf "%.1f GB" $ram)
    if (( $(echo "$ram < $MIN_MEMORY_GB" | bc -l) )); then
        log "warn" "内存: $ram_gb (建议至少${MIN_MEMORY_GB}GB)"
    else
        log "info" "内存: $ram_gb"
    fi
    
    # 磁盘空间 (只调用一次df命令)
    disk_info=$(df -h / | tail -1)
    disk_space=$(echo "$disk_info" | awk '{print $4}')
    disk_space_gb=$(df -g / | tail -1 | awk '{print $4}')
    
    if (( disk_space_gb < WARN_DISK_SPACE_GB )); then
        log "error" "可用磁盘空间: $disk_space (建议至少${WARN_DISK_SPACE_GB}GB)"
    elif (( disk_space_gb < RECOMMENDED_DISK_SPACE_GB )); then
        log "warn" "可用磁盘空间: $disk_space (足够，但建议有${RECOMMENDED_DISK_SPACE_GB}GB以上)"
    else
        log "info" "可用磁盘空间: $disk_space"
    fi
}

# 检查网络连接
check_network() {
    if [[ $CHECK_NETWORK != true ]]; then
        log "info" "跳过网络检查"
        return
    fi
    
    log "step" "===== 网络连接检查 ====="
    
    # 检查DNS解析
    if ping -c 1 google.com &>/dev/null || ping -c 1 baidu.com &>/dev/null; then
        log "info" "DNS解析: 正常"
    else
        log "warn" "DNS解析: 可能存在问题"
    fi
    
    # 检查代理设置
    if [[ -n "$http_proxy" || -n "$https_proxy" || -n "$all_proxy" ]]; then
        log "info" "代理设置: 已配置"
        [[ -n "$http_proxy" ]] && log "info" "  HTTP代理: $http_proxy"
        [[ -n "$https_proxy" ]] && log "info" "  HTTPS代理: $https_proxy"
    else
        log "info" "代理设置: 未配置"
    fi
    
    # 检查github.com的连通性 (对开发者很重要)
    if curl --connect-timeout 5 -s https://github.com > /dev/null; then
        log "info" "GitHub连接: 正常"
    else
        log "warn" "GitHub连接: 可能存在问题，这可能会影响开发工作"
    fi
}

# 检查开发工具状态
check_dev_tools() {
    log "step" "===== 开发工具检查 ====="
    
    # 检查Xcode Command Line Tools
    if xcode-select -p &>/dev/null; then
        log "info" "Xcode Command Line Tools: 已安装"
        log "info" "  路径: $(xcode-select -p)"
    else
        log "error" "Xcode Command Line Tools: 未安装"
        log "info" "  建议运行: xcode-select --install"
    fi
    
    # 检查Homebrew
    if command -v brew &>/dev/null; then
        brew_version=$(brew --version | head -1)
        log "info" "Homebrew: 已安装 ($brew_version)"
        log "info" "  路径: $(which brew)"
        
        # 检查Homebrew状态 (可选跳过以节省时间)
        if [[ $SKIP_BREW_DOCTOR == true ]]; then
            log "info" "  已跳过Homebrew状态检查 (--skip-brew)"
        else
            log "info" "  正在检查Homebrew状态..."
            brew_doctor_output=$(brew doctor 2>&1)
            if [[ "$brew_doctor_output" == *"Your system is ready to brew"* ]]; then
                log "info" "  Homebrew状态: 良好"
            else
                log "warn" "  Homebrew状态: 有问题"
                log "info" "  运行 'brew doctor' 查看详情"
            fi
        fi
    else
        log "error" "Homebrew: 未安装"
        log "info" "  建议安装: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
}

# 检查已安装的主要工具
check_installed_tools() {
    log "step" "===== 已安装工具检查 ====="
    
    # 定义要检查的工具列表及其用途说明
    declare -A tools_desc=(
        ["git"]="版本控制系统"
        ["python3"]="Python编程语言"
        ["node"]="Node.js JavaScript运行时"
        ["go"]="Go编程语言"
        ["docker"]="容器平台"
        ["code"]="Visual Studio Code"
        ["make"]="构建工具"
        ["gcc"]="GNU编译器集合"
        ["java"]="Java运行时"
    )
    
    # 检查每个工具
    for tool in "${!tools_desc[@]}"; do
        if [[ "$tool" == "code" && $SKIP_VSCODE == true ]]; then
            continue
        fi
        
        desc="${tools_desc[$tool]}"
        if command -v "$tool" &>/dev/null; then
            # 尝试使用不同的方式获取版本，处理潜在错误
            version=$($tool --version 2>/dev/null | head -1 || echo "未知版本")
            log "info" "$tool: 已安装 ($version) - $desc"
        else
            log "warn" "$tool: 未安装 - $desc"
        fi
    done
    
    # 检查Shell配置
    log "step" "===== Shell配置 ====="
    current_shell=$(echo $SHELL | xargs basename)
    log "info" "当前Shell: $current_shell"
    
    if [[ "$current_shell" == "zsh" ]]; then
        if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
            log "info" "Oh My Zsh: 已安装"
        else
            log "warn" "Oh My Zsh: 未安装 (可选但推荐)"
        fi
    fi
}

# 检查VS Code扩展
check_vscode_extensions() {
    if [[ $SKIP_VSCODE == true ]]; then
        log "info" "跳过VS Code扩展检查 (--skip-vscode)"
        return
    fi

    log "step" "===== VS Code扩展检查 ====="
    
    if ! command -v code &>/dev/null; then
        log "warn" "VS Code: 未安装"
        return
    fi
    
    # 定义常用扩展及其用途
    declare -A extensions=(
        ["ms-python.python"]="Python支持"
        ["dbaeumer.vscode-eslint"]="ESLint支持"
        ["esbenp.prettier-vscode"]="代码格式化工具"
        ["ms-azuretools.vscode-docker"]="Docker支持"
        ["ms-vscode.cpptools"]="C/C++支持"
        ["golang.go"]="Go语言支持"
        ["redhat.java"]="Java支持"
        ["ms-vscode-remote.remote-ssh"]="远程SSH开发"
    )
    
    # 获取已安装扩展列表 (只调用一次命令)
    installed=$(code --list-extensions 2>/dev/null)
    
    for ext in "${!extensions[@]}"; do
        desc="${extensions[$ext]}"
        if echo "$installed" | grep -q "$ext"; then
            log "info" "$ext: 已安装 - $desc"
        else
            log "info" "$ext: 未安装 - $desc"
        fi
    done
}

# 生成总结
generate_summary() {
    log "step" "===== 环境检查总结 ====="
    
    # 重新获取关键信息
    get_macos_version
    
    # 检查是否有足够的磁盘空间用于安装
    disk_space_gb=$(df -g / | tail -1 | awk '{print $4}')
    if (( disk_space_gb < WARN_DISK_SPACE_GB )); then
        log "error" "警告: 磁盘空间不足，可能影响安装"
        log "info" "建议清理磁盘后再继续"
    else
        log "info" "磁盘空间足够安装开发环境"
    fi
    
    # 检查系统版本
    if [[ $MACOS_MAJOR -lt $MIN_MACOS_MAJOR ]]; then
        log "warn" "建议: 考虑升级到最新的macOS版本以获得更好支持"
    fi
    
    # 根据检查结果给出建议
    if ! command -v brew &>/dev/null; then
        log "warn" "建议: 安装Homebrew包管理器"
    fi
    
    # 当前shell可能在check_installed_tools函数中已经获取了，但为了安全起见再次获取
    current_shell=$(echo $SHELL | xargs basename)
    if [[ "$current_shell" != "zsh" ]]; then
        log "warn" "建议: 考虑切换到zsh并安装Oh My Zsh"
    fi
    
    log "info" "你可以运行以下命令开始安装:"
    log "info" "./install.sh"
}

# 主函数
main() {
    parse_args "$@"

    echo "===== Mac开发环境检查 ====="
    echo "开始时间: $(date)"
    
    check_macos_version
    check_hardware
    check_network
    check_dev_tools
    check_installed_tools
    check_vscode_extensions
    generate_summary
    
    echo -e "\n检查完成! 时间: $(date)"
    calculate_runtime
}

# 执行主函数，传递所有命令行参数
main "$@"