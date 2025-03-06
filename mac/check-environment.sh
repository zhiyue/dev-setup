#!/bin/bash
# check-environment.sh - 检测当前Mac开发环境状态
# 用于安装前或安装后的系统检查

# 设置输出颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # 恢复正常颜色

# 获取macOS版本
check_macos_version() {
    echo "===== 系统信息 ====="
    sw_vers
    
    # 检查macOS版本是否受支持
    macos_version=$(sw_vers -productVersion)
    macos_major=$(echo $macos_version | cut -d. -f1)
    macos_minor=$(echo $macos_version | cut -d. -f2)
    
    if [[ $macos_major -lt 11 ]]; then
        echo -e "${RED}警告: 此脚本设计用于macOS 11.0 (Big Sur)或更高版本${NC}"
        echo "当前运行的是macOS $macos_version"
        echo "某些功能可能不工作，建议升级系统"
    else
        echo -e "${GREEN}当前macOS版本($macos_version)受支持${NC}"
    fi
}

# 检查硬件信息
check_hardware() {
    echo -e "\n===== 硬件信息 ====="
    
    # CPU架构
    cpu_type=$(uname -m)
    if [[ "$cpu_type" == "arm64" ]]; then
        echo -e "CPU: ${GREEN}Apple Silicon ($cpu_type)${NC}"
    else
        echo -e "CPU: Intel ($cpu_type)"
    fi
    
    # 内存
    ram=$(sysctl hw.memsize | awk '{print $2 / 1024 / 1024 / 1024 " GB"}')
    if (( $(echo "$ram < 8" | bc -l) )); then
        echo -e "内存: ${YELLOW}$ram (建议至少8GB)${NC}"
    else
        echo -e "内存: ${GREEN}$ram${NC}"
    fi
    
    # 磁盘空间
    disk_space=$(df -h / | tail -1 | awk '{print $4}')
    disk_space_gb=$(df -g / | tail -1 | awk '{print $4}')
    if (( disk_space_gb < 20 )); then
        echo -e "可用磁盘空间: ${RED}$disk_space (建议至少20GB)${NC}"
    elif (( disk_space_gb < 50 )); then
        echo -e "可用磁盘空间: ${YELLOW}$disk_space (足够，但建议有50GB以上)${NC}"
    else
        echo -e "可用磁盘空间: ${GREEN}$disk_space${NC}"
    fi
}

# 检查开发工具状态
check_dev_tools() {
    echo -e "\n===== 开发工具检查 ====="
    
    # 检查Xcode Command Line Tools
    if xcode-select -p &>/dev/null; then
        echo -e "Xcode Command Line Tools: ${GREEN}已安装${NC}"
        echo "  路径: $(xcode-select -p)"
    else
        echo -e "Xcode Command Line Tools: ${RED}未安装${NC}"
    fi
    
    # 检查Homebrew
    if command -v brew &>/dev/null; then
        brew_version=$(brew --version | head -1)
        echo -e "Homebrew: ${GREEN}已安装${NC} ($brew_version)"
        echo "  路径: $(which brew)"
        
        # 检查Homebrew状态
        echo "  正在检查Homebrew状态..."
        brew_doctor_output=$(brew doctor 2>&1)
        if [[ "$brew_doctor_output" == *"Your system is ready to brew"* ]]; then
            echo -e "  Homebrew状态: ${GREEN}良好${NC}"
        else
            echo -e "  Homebrew状态: ${YELLOW}有问题${NC}"
            echo "  运行 'brew doctor' 查看详情"
        fi
    else
        echo -e "Homebrew: ${RED}未安装${NC}"
    fi
}

# 检查已安装的主要工具
check_installed_tools() {
    echo -e "\n===== 已安装工具检查 ====="
    
    # 定义要检查的工具列表
    tools=(
        "git"
        "python3"
        "node"
        "go"
        "docker"
        "code" # VS Code
    )
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            version=$($tool --version 2>&1 | head -1)
            echo -e "$tool: ${GREEN}已安装${NC} ($version)"
        else
            echo -e "$tool: ${RED}未安装${NC}"
        fi
    done
    
    # 检查Shell配置
    echo -e "\n===== Shell配置 ====="
    current_shell=$(echo $SHELL | xargs basename)
    echo "当前Shell: $current_shell"
    
    if [[ "$current_shell" == "zsh" ]]; then
        if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
            echo -e "Oh My Zsh: ${GREEN}已安装${NC}"
        else
            echo -e "Oh My Zsh: ${YELLOW}未安装${NC} (可选但推荐)"
        fi
    fi
}

# 检查VS Code扩展
check_vscode_extensions() {
    echo -e "\n===== VS Code扩展检查 ====="
    
    if ! command -v code &>/dev/null; then
        echo -e "VS Code: ${RED}未安装${NC}"
        return
    fi
    
    # 定义常用扩展
    extensions=(
        "ms-python.python"
        "dbaeumer.vscode-eslint"
        "esbenp.prettier-vscode"
        "ms-azuretools.vscode-docker"
        "ms-vscode.cpptools"
    )
    
    # 获取已安装扩展列表
    installed=$(code --list-extensions)
    
    for ext in "${extensions[@]}"; do
        if echo "$installed" | grep -q "$ext"; then
            echo -e "$ext: ${GREEN}已安装${NC}"
        else
            echo -e "$ext: ${YELLOW}未安装${NC}"
        fi
    done
}

# 生成总结
generate_summary() {
    echo -e "\n===== 环境检查总结 ====="
    
    # 检查是否有足够的磁盘空间用于安装
    disk_space_gb=$(df -g / | tail -1 | awk '{print $4}')
    if (( disk_space_gb < 20 )); then
        echo -e "${RED}警告: 磁盘空间不足，可能影响安装${NC}"
        echo "建议清理磁盘后再继续"
    else
        echo -e "${GREEN}磁盘空间足够安装开发环境${NC}"
    fi
    
    # 检查系统版本
    macos_version=$(sw_vers -productVersion)
    macos_major=$(echo $macos_version | cut -d. -f1)
    if [[ $macos_major -lt 11 ]]; then
        echo -e "${YELLOW}建议: 考虑升级到最新的macOS版本以获得更好支持${NC}"
    fi
    
    # 根据检查结果给出建议
    if ! command -v brew &>/dev/null; then
        echo -e "${YELLOW}建议: 安装Homebrew包管理器${NC}"
    fi
    
    if [[ "$current_shell" != "zsh" ]]; then
        echo -e "${YELLOW}建议: 考虑切换到zsh并安装Oh My Zsh${NC}"
    fi
    
    echo -e "\n你可以运行以下命令开始安装:"
    echo -e "${GREEN}./install.sh${NC}"
}

# 主函数
main() {
    echo "===== Mac开发环境检查 ====="
    echo "开始时间: $(date)"
    
    check_macos_version
    check_hardware
    check_dev_tools
    check_installed_tools
    check_vscode_extensions
    generate_summary
    
    echo -e "\n检查完成! 时间: $(date)"
}

# 执行主函数
main