# Dev-Setup 开发环境初始化工具

这个仓库包含用于快速初始化开发环境的自动化脚本，支持Mac和Windows系统。

## 项目概述

Dev-Setup致力于提供一套自动化工具，帮助开发者快速搭建一个完整的开发环境，减少手动配置的时间和精力。

主要功能：
- 自动安装常用开发工具和软件
- 配置系统默认设置
- 优化开发环境

## 仓库结构

```
dev-setup/
├── README.md              # 项目说明文档
├── common/                # 跨平台通用脚本
├── mac/                   # Mac特定脚本
│   ├── install.sh         # Mac主安装脚本
│   ├── brew-essentials.sh # Homebrew必备软件安装
│   └── macos-defaults.sh  # macOS系统设置优化
└── windows/               # Windows特定脚本
    ├── install.ps1        # Windows主安装脚本
    ├── chocolatey-setup.ps1  # Chocolatey安装和配置
    └── windows-features.ps1  # Windows功能配置
```

## Dev-Setup与Dotfiles的关系

dev-setup负责初始化环境，dotfiles负责个性化配置，两者分工明确又能无缝协作。
将dotfiles放在单独的仓库比放入dev-setup更优，因为它提供了：

- 更好的版本控制
- 更高的可移植性
- 更便于分享和协作
- 更清晰的组织结构
- 适应不同的更新频率

### Dev-Setup的特点

- **一次性执行**：主要用于快速设置开发环境
- **特定于环境**：脚本包含与特定操作系统相关的配置
- **更新较少**：除非有新的软件需求，通常不会频繁改动
- **环境初始化**：负责安装工具、配置系统设置等基础工作

### Dotfiles的特点

- **跨项目和跨设备**：dotfiles是通用的，可以在不同机器上复用
- **频繁调整**：根据需求不断修改这些配置
- **个性化强**：反映个人工作习惯，可能需要与他人分享或借鉴
- **配置文件**：包括`.zshrc`、`.vimrc`等个人配置文件

## 使用方法

### Mac系统

```bash
# 克隆仓库
git clone https://github.com/yourusername/dev-setup.git
cd dev-setup/mac

# 运行安装脚本
./install.sh
```

### Windows系统

```powershell
# 克隆仓库
git clone https://github.com/yourusername/dev-setup.git
cd dev-setup\windows

# 以管理员权限运行PowerShell脚本
powershell -ExecutionPolicy Bypass -File install.ps1
```

## 贡献指南

欢迎提交Pull Request或Issue来改进这个项目。

## 许可证

[MIT License](LICENSE)