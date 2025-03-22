#!/bin/bash

# macOS下配置1Password SSH代理的脚本
# 此脚本遵循1Password官方文档的最佳实践
# https://developer.1password.com/docs/ssh/

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 辅助函数
print_header() {
    echo -e "${BLUE}===== $1 =====${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "$1"
}

# 开始脚本
clear
print_header "1Password SSH代理设置脚本 - 官方最佳实践"
print_info "此脚本将帮助您按照1Password官方文档设置SSH代理和Git集成"
print_info "参考：https://developer.1password.com/docs/ssh/get-started"
echo ""

# 第一步：检查1Password是否已安装
print_header "步骤1: 检查1Password安装"
if ! [ -d "/Applications/1Password.app" ]; then
    print_error "未检测到1Password应用程序"
    print_info "请先安装1Password应用并创建账户:"
    print_info "https://1password.com/downloads/mac/"
    exit 1
else
    print_success "1Password应用已安装"
fi

# 第二步：确保1Password SSH代理已启用
print_header "步骤2: 启用SSH代理"
print_info "按照官方文档，您需要在1Password应用中启用SSH代理:"
print_info "1. 打开1Password应用"
print_info "2. 在菜单栏中选择 1Password > 设置(⌘,)"
print_info "3. 选择"开发者"选项卡"
print_info "4. 点击"设置SSH代理""
print_info "5. 勾选"使用SSH代理"选项"
print_info "6. 建议勾选"显示密钥名称"选项，便于识别密钥"
print_info "7. 根据需要调整授权选项（何时以及多久请求一次批准）"
echo ""
print_info "为确保SSH代理持续可用，还应配置以下选项:"
print_info "1. 在1Password设置中选择"通用"选项卡"
print_info "2. 勾选"在菜单栏中显示1Password"选项"
print_info "3. 勾选"登录时启动"选项"
echo ""
read -p "已完成以上步骤？(y/n): " enabled_agent
if [[ $enabled_agent != "y" ]]; then
    print_warning "请先完成上述配置，然后再次运行此脚本"
    exit 1
fi

# 第三步：配置SSH客户端使用1Password SSH代理
print_header "步骤3: 配置SSH客户端"
SSH_CONFIG_FILE="$HOME/.ssh/config"

# 创建.ssh目录(如果不存在)
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# 备份现有的SSH配置(如果存在)
if [ -f "$SSH_CONFIG_FILE" ]; then
    backup_file="$SSH_CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SSH_CONFIG_FILE" "$backup_file"
    chmod 600 "$backup_file"
    print_success "已备份现有SSH配置到 $backup_file"
fi

# 添加1Password SSH代理配置到SSH配置文件
# 使用官方文档中指定的路径
if grep -q "1Password SSH" "$SSH_CONFIG_FILE" 2>/dev/null; then
    print_warning "SSH配置已包含1Password设置，将验证路径是否正确..."
    if ! grep -q "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" "$SSH_CONFIG_FILE"; then
        print_warning "现有配置可能使用了不正确的路径，将更新..."
        # 创建临时文件
        temp_file=$(mktemp)
        # 过滤掉旧的1Password配置并添加新配置
        sed '/1Password SSH/,/agent.sock/d' "$SSH_CONFIG_FILE" > "$temp_file"
        cat >> "$temp_file" << 'EOL'
# 1Password SSH配置
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
EOL
        # 替换原文件
        mv "$temp_file" "$SSH_CONFIG_FILE"
        chmod 600 "$SSH_CONFIG_FILE"
        print_success "已更新1Password SSH代理配置使用官方路径"
    else
        print_success "现有配置使用了正确的1Password SSH代理路径"
    fi
else
    cat >> "$SSH_CONFIG_FILE" << 'EOL'
# 1Password SSH配置
Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
EOL
    chmod 600 "$SSH_CONFIG_FILE"
    print_success "已将1Password SSH代理配置添加到SSH配置"
fi

# 第四步：提示创建或导入SSH密钥
print_header "步骤4: SSH密钥管理"
print_info "按照官方文档，您需要在1Password中创建或导入SSH密钥:"
print_info "创建新的SSH密钥:"
print_info "1. 打开1Password应用，解锁并导航到您的Personal、Private或Employee保险库"
print_info "2. 选择"新项目 > SSH密钥""
print_info "3. 选择"添加私钥 > 生成新密钥""
print_info "4. 选择密钥类型：Ed25519(推荐)或RSA"
print_info "5. 点击"生成"并保存"
echo ""
print_info "导入现有SSH密钥:"
print_info "1. 打开1Password应用，解锁并导航到您的保险库"
print_info "2. 选择"新项目 > SSH密钥""
print_info "3. 选择"添加私钥 > 从文件导入""
print_info "4. 选择您的私钥文件并保存"
echo ""
print_info "注意: 1Password SSH代理只能使用以下条件的密钥:"
print_info "- 必须使用SSH Key项目类型创建或导入"
print_info "- 必须是Ed25519或RSA密钥类型"
print_info "- 必须存储在SSH代理配置访问的保险库中(默认为Personal/Private/Employee)"
print_info "- 必须是活动项目(未归档或删除)"
echo ""
read -p "您是否已在1Password中创建或导入SSH密钥？(y/n): " has_ssh_keys
if [[ $has_ssh_keys != "y" ]]; then
    print_warning "请先在1Password中创建或导入SSH密钥"
    print_info "然后继续执行脚本的其余步骤"
else
    print_success "确认已有SSH密钥在1Password中"
fi

# 第五步：上传公钥到Git平台
print_header "步骤5: 上传公钥"
print_info "按照官方文档，您可以使用1Password浏览器扩展上传公钥:"
print_info "1. 确保已安装1Password浏览器扩展(Safari、Chrome、Firefox、Edge或Brave)"
print_info "2. 访问您的Git平台的SSH密钥设置页面(如GitHub, GitLab等)"
print_info "3. 点击标题或密钥字段"
print_info "4. 选择1Password图标，然后选择您刚创建的SSH密钥"
print_info "5. 1Password将自动填充公钥和标题"
print_info "6. 点击平台上的"添加SSH密钥"按钮保存"
echo ""
print_info "手动方法:"
print_info "1. 在1Password中打开您的SSH密钥项目"
print_info "2. 复制公钥"
print_info "3. 粘贴到Git平台的SSH密钥设置页面"
print_info "4. 点击平台上的"添加SSH密钥"按钮保存"
echo ""
read -p "您是否已将公钥上传到Git平台？(y/n): " uploaded_key
if [[ $uploaded_key != "y" ]]; then
    print_warning "请先上传公钥到您的Git平台"
    print_info "您可以稍后再完成这一步"
else
    print_success "确认已上传公钥到Git平台"
fi

# 第六步：设置Git配置使用SSH签名提交
print_header "步骤6: 配置Git签名"
read -p "是否配置Git使用SSH密钥进行提交签名？(y/n): " configure_git_signing
if [[ $configure_git_signing != "y" ]]; then
    print_info "跳过Git签名配置"
else
    # 提示查看可用的SSH密钥
    print_info "请在1Password中查看您的SSH密钥信息，以便下一步操作："
    print_info "1. 打开1Password应用"
    print_info "2. 找到您的SSH密钥项目"
    print_info "3. 记下您想用于签名的SSH密钥名称"
    echo ""
    
    # 配置Git使用SSH进行提交签名
    git config --global gpg.format ssh
    
    read -p "是否让1Password自动配置Git签名(推荐)？(y/n): " auto_configure
    if [[ $auto_configure == "y" ]]; then
        print_info "请注意，您需要手动在1Password中进行以下操作:"
        print_info "1. 打开1Password应用，找到您的SSH密钥"
        print_info "2. 在SSH密钥详情页面，点击"..."选项"
        print_info "3. 选择"使用此密钥签名Git提交""
        print_info "4. 按照1Password提供的说明完成配置"
        print_info ""
        print_info "这个自动过程将正确设置您的Git配置，包括:"
        print_info "- 将gpg.format设置为ssh"
        print_info "- 将user.signingkey设置为正确的SSH密钥格式"
        print_success "1Password将自动完成Git签名配置"
    else
        print_info "手动配置Git签名..."
        # 提示用户输入要使用的SSH密钥
        read -p "请输入您想用于Git签名的SSH密钥名称(在1Password中显示的名称): " key_identifier
        
        if [ -z "$key_identifier" ]; then
            print_warning "未提供密钥名称，跳过配置"
        else
            # 正确格式化SSH密钥标识
            git config --global user.signingkey "key::${key_identifier}"
            print_success "已配置Git使用指定的SSH密钥('${key_identifier}')进行签名"
        fi
    fi
    
    # 默认为所有提交启用签名
    read -p "是否为所有Git提交默认启用签名？(y/n): " enable_signing
    if [[ $enable_signing == "y" ]]; then
        git config --global commit.gpgsign true
        print_success "已为所有提交启用SSH签名"
    else
        print_info "未启用默认签名，您可以使用'git commit -S'手动签名提交"
    fi
fi

# 第七步：测试SSH代理连接
print_header "步骤7: 测试SSH代理连接"
print_info "正在测试1Password SSH代理连接..."

# 设置环境变量以专门测试1Password SSH代理
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# 测试SSH代理
ssh-add -l 2>/dev/null
if [ $? -eq 0 ]; then
    print_success "已成功连接到1Password SSH代理！"
    print_info "显示可用的SSH密钥:"
    ssh-add -l
else
    print_warning "连接到1Password SSH代理时出现问题"
    print_info "请确保:"
    print_info "1. 1Password应用已打开并解锁"
    print_info "2. SSH代理已启用(在1Password偏好设置 > 开发者中)"
    print_info "3. 在1Password中至少有一个符合条件的SSH密钥"
    print_info "4. 您已重新启动1Password应用(如果刚刚启用了SSH代理)"
fi

# 提供使用建议
print_header "完成设置"
print_info "您现在已经完成了按照1Password官方文档的建议配置SSH代理和Git集成"
print_info ""
print_info "【使用建议】"
print_info "1. 使用SSH连接:"
print_info "   $ ssh user@hostname"
print_info "   首次连接时，1Password会要求您批准访问SSH密钥"
print_info ""
print_info "2. Git操作:"
print_info "   $ git clone git@github.com:username/repository.git"
print_info "   $ git push origin main"
print_info "   1Password会在需要时处理身份验证"
print_info ""
print_info "3. 签名Git提交(如已配置):"
print_info "   $ git commit -S -m \"您的提交信息\""
print_info "   如启用了默认签名，则可简化为:"
print_info "   $ git commit -m \"您的提交信息\""
print_info ""
print_info "4. 查看可用的SSH密钥:"
print_info "   $ ssh-add -l"
print_info ""
print_info "【排错指南】"
print_info "• 如果遇到"Permission denied"错误:"
print_info "  1. 确保公钥已添加到目标服务器/平台"
print_info "  2. 确保1Password已解锁且SSH代理已启用"
print_info "  3. 使用ssh -vv命令查看详细调试信息"
print_info ""
print_info "• 如果1Password没有弹出授权对话框:"
print_info "  1. 确保1Password在菜单栏中显示并正在运行"
print_info "  2. 尝试重新启动1Password应用"
print_info "  3. 检查SSH配置文件中的代理路径是否正确"
print_info ""
print_info "【官方文档参考】"
print_info "• 入门指南: https://developer.1password.com/docs/ssh/get-started"
print_info "• SSH密钥管理: https://developer.1password.com/docs/ssh/manage-keys"
print_info "• 高级使用: https://developer.1password.com/docs/ssh/agent"
print_info ""
print_info "如有疑问，请参考1Password官方文档或联系1Password支持"

exit 0
