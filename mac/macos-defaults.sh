#!/bin/bash
# macos-defaults.sh - 配置macOS系统默认设置
# 针对开发环境优化的系统配置

# 配置变量
BACKUP_DIR="$HOME/.macos_defaults_backup"
CONFIG_FILE="${1:-config.yml}"  # 允许通过参数指定配置文件
LOG_FILE="$HOME/macos_defaults_log.txt"

# 可配置选项
CONFIGURE_UI=true
CONFIGURE_FINDER=true
CONFIGURE_DOCK=true
CONFIGURE_TERMINAL=true
CONFIGURE_DEV=true
SKIP_CONFIRMATION=false
BACKUP_SETTINGS=true

# 解析命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --config=*) CONFIG_FILE="${1#*=}" ;;
        --no-ui) CONFIGURE_UI=false ;;
        --no-finder) CONFIGURE_FINDER=false ;;
        --no-dock) CONFIGURE_DOCK=false ;;
        --no-terminal) CONFIGURE_TERMINAL=false ;;
        --no-dev) CONFIGURE_DEV=false ;;
        --no-backup) BACKUP_SETTINGS=false ;;
        --yes) SKIP_CONFIRMATION=true ;;
        --help) 
            echo "用法: ./macos-defaults.sh [选项]"
            echo "选项:"
            echo "  --config=文件     指定配置文件路径 (默认: config.yml)"
            echo "  --no-ui           不配置UI/UX设置"
            echo "  --no-finder       不配置Finder设置"
            echo "  --no-dock         不配置Dock设置"
            echo "  --no-terminal     不配置终端设置"
            echo "  --no-dev          不配置开发者设置"
            echo "  --no-backup       不备份当前设置"
            echo "  --yes             跳过所有确认提示"
            echo "  --restore         恢复之前备份的设置"
            exit 0
            ;;
        --restore) 
            echo "正在恢复备份的设置..."
            if [[ -d "$BACKUP_DIR" ]]; then
                for file in "$BACKUP_DIR"/*.plist; do
                    domain=$(basename "$file" .plist)
                    defaults import "$domain" "$file"
                done
                echo "设置已恢复"
            else
                echo "错误: 备份目录不存在"
                exit 1
            fi
            exit 0
            ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
    shift
done

# 设置日志
exec &> >(tee -a "$LOG_FILE")
echo "===== macOS系统设置配置开始 $(date) =====" > "$LOG_FILE"

# 备份当前设置
backup_settings() {
    if $BACKUP_SETTINGS; then
        echo "备份当前系统设置..."
        mkdir -p "$BACKUP_DIR"
        
        # 备份关键域的设置
        defaults domains | tr -d ' ' | tr ',' '\n' | while read domain; do
            if [[ -n "$domain" ]]; then
                defaults export "$domain" "$BACKUP_DIR/$domain.plist" 2>/dev/null || true
            fi
        done
        
        echo "设置已备份到 $BACKUP_DIR"
    fi
}

# 设置函数，添加检查和恢复功能
set_default() {
    local domain=$1
    local key=$2
    local value=$3
    local type=$4
    local description=$5
    
    # 显示设置描述
    echo "设置: $description"
    
    # 备份原始值
    if $BACKUP_SETTINGS; then
        local original_value
        original_value=$(defaults read "$domain" "$key" 2>/dev/null || echo "not_set")
        echo "$domain:$key:$original_value" >> "$BACKUP_DIR/values.txt"
    fi
    
    # 应用新设置
    if [[ "$type" == "bool" ]]; then
        defaults write "$domain" "$key" -bool "$value"
    elif [[ "$type" == "int" ]]; then
        defaults write "$domain" "$key" -int "$value"
    elif [[ "$type" == "float" ]]; then
        defaults write "$domain" "$key" -float "$value"
    elif [[ "$type" == "string" ]]; then
        defaults write "$domain" "$key" -string "$value"
    else
        defaults write "$domain" "$key" "$value"
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

# 显示设置组标题
show_section() {
    echo ""
    echo "===== $1 ====="
}

# 开始执行
echo "===== 开始配置macOS系统设置 ====="

# 关闭系统偏好设置以防止它们覆盖我们的设置
osascript -e 'tell application "System Preferences" to quit'

# 请求管理员权限
sudo -v

# 保持sudo权限直到脚本结束
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# 备份当前设置
backup_settings

# 提示用户确认
if ! $SKIP_CONFIRMATION; then
    if ! confirm "此脚本将修改多项系统设置。继续?"; then
        echo "已取消"
        exit 0
    fi
fi

###############################################################################
# 一般UI/UX设置                                                              #
###############################################################################
if $CONFIGURE_UI; then
    show_section "一般UI/UX设置"

    # 设置计算机名称
    if ! $SKIP_CONFIRMATION; then
        read -p "输入您希望的计算机名称 (留空跳过): " COMPUTER_NAME
        if [ -n "$COMPUTER_NAME" ]; then
            echo "设置计算机名称为: $COMPUTER_NAME"
            sudo scutil --set ComputerName "$COMPUTER_NAME"
            sudo scutil --set HostName "$COMPUTER_NAME"
            sudo scutil --set LocalHostName "$COMPUTER_NAME"
            sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$COMPUTER_NAME"
        fi
    fi

    # 禁用开机声音
    set_default "SystemAudioVolume" " " "string" "禁用开机声音"

    # 设置侧边栏图标大小为中等
    set_default "NSGlobalDomain" "NSTableViewDefaultSizeMode" "2" "int" "设置侧边栏图标大小为中等"

    # 始终显示滚动条
    set_default "NSGlobalDomain" "AppleShowScrollBars" "Always" "string" "始终显示滚动条"

    # 禁用"您确定要打开此应用程序吗？"对话框
    set_default "com.apple.LaunchServices" "LSQuarantine" "false" "bool" "禁用应用程序打开确认对话框"

    # 默认保存到磁盘(而不是iCloud)
    set_default "NSGlobalDomain" "NSDocumentSaveNewDocumentsToCloud" "false" "bool" "默认保存到磁盘而非iCloud"
fi

###############################################################################
# Finder设置                                                                 #
###############################################################################
if $CONFIGURE_FINDER; then
    show_section "Finder设置"

    # 显示所有文件扩展名
    set_default "NSGlobalDomain" "AppleShowAllExtensions" "true" "bool" "显示所有文件扩展名"

    # 显示状态栏
    set_default "com.apple.finder" "ShowStatusBar" "true" "bool" "显示状态栏"

    # 显示路径栏
    set_default "com.apple.finder" "ShowPathbar" "true" "bool" "显示路径栏"

    # 将完整POSIX路径显示为Finder窗口标题
    set_default "com.apple.finder" "_FXShowPosixPathInTitle" "true" "bool" "在Finder窗口标题显示完整路径"

    # 在按名称排序时将文件夹保持在顶部
    set_default "com.apple.finder" "_FXSortFoldersFirst" "true" "bool" "排序时文件夹置顶"

    # 执行搜索时，默认搜索当前文件夹
    set_default "com.apple.finder" "FXDefaultSearchScope" "SCcf" "string" "搜索默认在当前文件夹"

    # 禁用更改文件扩展名时的警告
    set_default "com.apple.finder" "FXEnableExtensionChangeWarning" "false" "bool" "禁用更改扩展名警告"

    # 启用目录的弹簧加载
    set_default "NSGlobalDomain" "com.apple.springing.enabled" "true" "bool" "启用目录的弹簧加载"

    # 避免在网络或USB卷上创建.DS_Store文件
    set_default "com.apple.desktopservices" "DSDontWriteNetworkStores" "true" "bool" "避免在网络卷上创建.DS_Store"
    set_default "com.apple.desktopservices" "DSDontWriteUSBStores" "true" "bool" "避免在USB卷上创建.DS_Store"

    # 显示~/Library文件夹
    chflags nohidden ~/Library && echo "显示~/Library文件夹"

    # 显示/Volumes文件夹
    sudo chflags nohidden /Volumes && echo "显示/Volumes文件夹"
fi

###############################################################################
# Dock、Dashboard和热角设置                                                  #
###############################################################################
if $CONFIGURE_DOCK; then
    show_section "Dock设置"

    # 设置Dock自动隐藏
    set_default "com.apple.dock" "autohide" "true" "bool" "启用Dock自动隐藏"

    # 减少Dock自动隐藏的延迟
    set_default "com.apple.dock" "autohide-delay" "0" "float" "减少Dock自动隐藏延迟"

    # 使隐藏应用程序的Dock图标半透明
    set_default "com.apple.dock" "showhidden" "true" "bool" "使隐藏应用的Dock图标半透明"

    # 不在Dock中显示最近使用的应用程序
    set_default "com.apple.dock" "show-recents" "false" "bool" "不显示最近使用的应用"

    # 将Dock项目的图标大小设置为36像素
    set_default "com.apple.dock" "tilesize" "36" "int" "设置Dock图标大小为36像素"

    # 不根据最近使用情况自动重新排列空间
    set_default "com.apple.dock" "mru-spaces" "false" "bool" "不自动重排空间"
fi

###############################################################################
# 终端和iTerm 2设置                                                          #
###############################################################################
if $CONFIGURE_TERMINAL; then
    show_section "终端设置"

    # 在Terminal.app中仅使用UTF-8
    set_default "com.apple.terminal" "StringEncodings" "-array 4" "" "Terminal仅使用UTF-8"

    # 在Terminal.app中启用安全键盘输入
    set_default "com.apple.terminal" "SecureKeyboardEntry" "true" "bool" "启用安全键盘输入"

    # 下载iTerm2 Solarized Dark主题
    if [ -d ~/Downloads ]; then
        if confirm "下载iTerm2 Solarized Dark主题?"; then
            curl -o ~/Downloads/Solarized-Dark.itermcolors https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Solarized%20Dark.itermcolors
            echo "iTerm2 Solarized Dark主题已下载到~/Downloads/Solarized-Dark.itermcolors"
            echo "您可以在iTerm2首选项中导入此主题"
        fi
    fi
fi

###############################################################################
# 开发者设置                                                                 #
###############################################################################
if $CONFIGURE_DEV; then
    show_section "开发者设置"

    # 启用开发者模式
    if confirm "启用开发者模式?"; then
        sudo /usr/sbin/DevToolsSecurity -enable
        echo "已启用开发者模式"
    fi

    # 在Safari中启用WebKit开发者工具
    set_default "com.apple.Safari" "IncludeDevelopMenu" "true" "bool" "在Safari中启用开发菜单"
    set_default "com.apple.Safari" "WebKitDeveloperExtrasEnabledPreferenceKey" "true" "bool" "启用WebKit开发者工具"
    set_default "com.apple.Safari" "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" "true" "bool" "启用WebKit2开发者工具"

    # 为Web视图添加显示Web检查器的上下文菜单项
    set_default "NSGlobalDomain" "WebKitDeveloperExtras" "true" "bool" "为Web视图启用开发者功能"

    # 禁用自动大写、智能破折号等
    set_default "NSGlobalDomain" "NSAutomaticCapitalizationEnabled" "false" "bool" "禁用自动大写"
    set_default "NSGlobalDomain" "NSAutomaticDashSubstitutionEnabled" "false" "bool" "禁用智能破折号"
    set_default "NSGlobalDomain" "NSAutomaticPeriodSubstitutionEnabled" "false" "bool" "禁用智能句点"
    set_default "NSGlobalDomain" "NSAutomaticQuoteSubstitutionEnabled" "false" "bool" "禁用智能引号"
    set_default "NSGlobalDomain" "NSAutomaticSpellingCorrectionEnabled" "false" "bool" "禁用自动拼写纠正"

    # 在菜单栏中显示电池百分比
    set_default "com.apple.menuextra.battery" "ShowPercent" "YES" "string" "显示电池百分比"

    # 启用键盘导航以在所有控件之间移动焦点
    set_default "NSGlobalDomain" "AppleKeyboardUIMode" "3" "int" "启用全键盘控制"

    # 加速键盘重复速率
    set_default "NSGlobalDomain" "KeyRepeat" "2" "int" "加快键盘重复速率"
    set_default "NSGlobalDomain" "InitialKeyRepeat" "15" "int" "减少键盘重复延迟"
fi

###############################################################################
# 重启受影响的应用程序                                                       #
###############################################################################
show_section "应用变更"

if confirm "是否立即重启受影响的应用程序?"; then
    for app in "Dock" "Finder" "Safari" "SystemUIServer" "Terminal" "iTerm" "iTerm2"; do
        killall "${app}" &> /dev/null || true
    done
    echo "已重启受影响的应用程序"
else
    echo "设置已应用，但需要重启应用或系统才能完全生效"
fi

echo "===== macOS系统设置配置完成 ====="
echo "注意：某些更改需要注销/重启才能生效。"
echo "如需恢复设置，请运行: $0 --restore"
echo "详细日志已保存到: $LOG_FILE"