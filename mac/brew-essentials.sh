#!/bin/bash
# brew-essentials.sh - 通过Homebrew安装开发必备工具
# 包含命令行工具、开发语言、应用程序等

set -e  # 如果任何命令失败，立即退出脚本

echo "===== 开始安装开发必备工具 ====="

# 确保使用最新版本的Homebrew
brew update

# 升级已安装的包
brew upgrade

# 安装命令行工具
echo "安装命令行工具..."
brew install \
    git \
    wget \
    curl \
    tree \
    jq \
    htop \
    tmux \
    vim \
    neovim \
    ripgrep \
    fd \
    fzf \
    bat \
    exa \
    zsh \
    zsh-completions \
    zsh-syntax-highlighting \
    zsh-autosuggestions

# 安装开发语言和工具
echo "安装开发语言和工具..."
brew install \
    python@3.10 \
    python@3.11 \
    node \
    nvm \
    go \
    cmake \
    docker \
    docker-compose \
    kubectl \
    awscli \
    terraform

# 安装数据库工具
echo "安装数据库工具..."
brew install \
    mysql \
    postgresql \
    redis \
    mongodb-community

# 安装应用程序
echo "通过Homebrew Cask安装应用程序..."
brew install --cask \
    visual-studio-code \
    iterm2 \
    docker \
    postman \
    google-chrome \
    firefox \
    slack \
    rectangle \
    alfred \
    stats \
    notion \
    figma \
    jetbrains-toolbox

# 安装开发字体
echo "安装开发字体..."
brew tap homebrew/cask-fonts
brew install --cask \
    font-fira-code \
    font-jetbrains-mono \
    font-hack-nerd-font \
    font-source-code-pro

# 清理过时的版本
brew cleanup

echo "===== 开发必备工具安装完成 ====="

# 显示安装的包数量
echo "已安装 $(brew list | wc -l | xargs) 个包"