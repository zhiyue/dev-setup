#!/bin/bash
# macos-defaults.sh - 配置macOS系统默认设置
# 针对开发环境优化的系统配置

set -e  # 如果任何命令失败，立即退出脚本

echo "===== 开始配置macOS系统设置 ====="

# 关闭系统偏好设置以防止它们覆盖我们的设置
osascript -e 'tell application "System Preferences" to quit'

# 请求管理员权限
sudo -v

# 保持sudo权限直到脚本结束
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###############################################################################
# 一般UI/UX设置                                                              #
###############################################################################

# 设置计算机名称
read -p "输入您希望的计算机名称: " COMPUTER_NAME
if [ -n "$COMPUTER_NAME" ]; then
    sudo scutil --set ComputerName "$COMPUTER_NAME"
    sudo scutil --set HostName "$COMPUTER_NAME"
    sudo scutil --set LocalHostName "$COMPUTER_NAME"
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$COMPUTER_NAME"
fi

# 禁用开机声音
sudo nvram SystemAudioVolume=" "

# 设置侧边栏图标大小为中等
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2

# 始终显示滚动条
defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

# 禁用"您确定要打开此应用程序吗？"对话框
defaults write com.apple.LaunchServices LSQuarantine -bool false

# 默认保存到磁盘(而不是iCloud)
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

###############################################################################
# Finder设置                                                                 #
###############################################################################

# 显示所有文件扩展名
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# 显示状态栏
defaults write com.apple.finder ShowStatusBar -bool true

# 显示路径栏
defaults write com.apple.finder ShowPathbar -bool true

# 将完整POSIX路径显示为Finder窗口标题
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# 在按名称排序时将文件夹保持在顶部
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# 执行搜索时，默认搜索当前文件夹
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# 禁用更改文件扩展名时的警告
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# 启用目录的弹簧加载
defaults write NSGlobalDomain com.apple.springing.enabled -bool true

# 避免在网络或USB卷上创建.DS_Store文件
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# 显示~/Library文件夹
chflags nohidden ~/Library

# 显示/Volumes文件夹
sudo chflags nohidden /Volumes

###############################################################################
# Dock、Dashboard和热角设置                                                  #
###############################################################################

# 设置Dock自动隐藏
defaults write com.apple.dock autohide -bool true

# 减少Dock自动隐藏的延迟
defaults write com.apple.dock autohide-delay -float 0

# 使隐藏应用程序的Dock图标半透明
defaults write com.apple.dock showhidden -bool true

# 不在Dock中显示最近使用的应用程序
defaults write com.apple.dock show-recents -bool false

# 将Dock项目的图标大小设置为36像素
defaults write com.apple.dock tilesize -int 36

# 不根据最近使用情况自动重新排列空间
defaults write com.apple.dock mru-spaces -bool false

###############################################################################
# 终端和iTerm 2设置                                                          #
###############################################################################

# 在Terminal.app中仅使用UTF-8
defaults write com.apple.terminal StringEncodings -array 4

# 在Terminal.app中启用安全键盘输入
defaults write com.apple.terminal SecureKeyboardEntry -bool true

# 下载iTerm2 Solarized Dark主题
if [ -d ~/Downloads ]; then
    curl -o ~/Downloads/Solarized-Dark.itermcolors https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Solarized%20Dark.itermcolors
    echo "iTerm2 Solarized Dark主题已下载到~/Downloads/Solarized-Dark.itermcolors"
    echo "您可以在iTerm2首选项中导入此主题"
fi

###############################################################################
# 开发者设置                                                                 #
###############################################################################

# 启用开发者模式
sudo /usr/sbin/DevToolsSecurity -enable

# 在Safari中启用WebKit开发者工具
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# 为Web视图添加显示Web检查器的上下文菜单项
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# 禁用自动大写、智能破折号等
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# 在菜单栏中显示电池百分比
defaults write com.apple.menuextra.battery ShowPercent -string "YES"

# 启用键盘导航以在所有控件之间移动焦点
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# 加速键盘重复速率
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

###############################################################################
# 重启受影响的应用程序                                                       #
###############################################################################

for app in "Dock" "Finder" "Safari" "SystemUIServer" "Terminal" "iTerm" "iTerm2"; do
    killall "${app}" &> /dev/null || true
done

echo "===== macOS系统设置配置完成 ====="
echo "注意：某些更改需要注销/重启才能生效。"