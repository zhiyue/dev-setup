#!/bin/bash

# Mac开发环境设置主脚本
# 作者：zhiyue
# 日期：2025-03-05

# 获取脚本目录和仓库根目录路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/*}"

echo "=== 开始Mac开发环境设置 ==="

# 检查是否已安装Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    echo "正在安装Xcode Command Line Tools..."
    xcode-select --install
    
    echo "请等待Xcode Command Line Tools安装完成，然后按任意键继续..."
    read -n 1
fi

# 检查是否已安装Homebrew
if ! command -v brew &>/dev/null; then
    echo "正在安装Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # 根据芯片类型添加Homebrew到PATH
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew已安装，正在更新..."
    brew update
fi

# 运行Homebrew必备软件安装脚本
echo "正在安装必备开发工具..."
bash "$SCRIPT_DIR/brew-essentials.sh"

# 运行macOS系统设置脚本
echo "正在配置macOS系统设置..."
bash "$SCRIPT_DIR/macos-defaults.sh"

# 运行共享Git配置脚本
echo "正在配置Git..."
bash "$REPO_ROOT/common/git-config.sh"

# 安装VS Code扩展
if command -v code &>/dev/null; then
    echo "正在安装VS Code扩展..."
    bash "$REPO_ROOT/common/vscode-extensions.sh"
else
    echo "VS Code未安装或不在PATH中，跳过扩展安装"
fi

echo "=== Mac开发环境设置完成 ==="
echo "建议重启系统以确保所有设置生效"