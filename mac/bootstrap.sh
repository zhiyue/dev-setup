#!/bin/bash

# Mac开发环境一键安装脚本
# 作者：zhiyue
# 日期：2025-03-06

# 显示横幅
echo "=================================================="
echo "       Mac开发环境设置 - 一键安装脚本"
echo "=================================================="
echo ""

# 临时目录
TEMP_DIR=$(mktemp -d -t dev-setup-XXXXX)
REPO_NAME="dev-setup"
REPO_URL="https://github.com/zhiyue/dev-setup/archive/main.zip"
LOG_FILE="/tmp/dev-setup-bootstrap.log"

# 清理函数
cleanup() {
  echo "清理临时文件..."
  rm -rf "$TEMP_DIR"
  echo "完成。"
}

# 错误处理
handle_error() {
  echo "错误: 安装过程中出现问题"
  echo "详细日志请查看: $LOG_FILE"
  cleanup
  exit 1
}

# 设置错误捕获
trap handle_error ERR

echo "准备安装Mac开发环境..."
echo "将下载必要的文件并运行安装脚本"
echo ""

# 检查curl命令是否存在
command -v curl >/dev/null 2>&1 || { echo "错误: 需要curl但未安装。macOS应该自带curl，请检查系统。"; exit 1; }

# 创建日志文件
echo "=== 开始安装 $(date) ===" > "$LOG_FILE"

echo "1. 下载安装文件..."
curl -L "$REPO_URL" -o "$TEMP_DIR/$REPO_NAME.zip" 2>&1 | tee -a "$LOG_FILE"

echo "2. 解压文件..."
# 使用macOS自带的命令解压ZIP文件，而不是依赖unzip
cd "$TEMP_DIR"
mkdir -p extracted
# 使用ditto命令 (macOS自带)
ditto -xk --noqtn "$REPO_NAME.zip" extracted 2>&1 | tee -a "$LOG_FILE"

# 找到解压后的目录名（处理可能的不同版本）
EXTRACTED_DIR=$(find "$TEMP_DIR/extracted" -type d -name "$REPO_NAME*" | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
  echo "错误: 无法找到解压后的目录" | tee -a "$LOG_FILE"
  handle_error
fi

echo "3. 准备运行安装脚本..."

# 移动到Mac目录
cd "$EXTRACTED_DIR/mac"

# 检查安装脚本是否存在
if [ ! -f "install.sh" ]; then
  echo "错误: 找不到必要的安装脚本" | tee -a "$LOG_FILE"
  handle_error
fi

# 设置脚本执行权限
chmod +x *.sh

echo "4. 运行安装脚本..."
echo "注意: 接下来将开始正式安装过程，请根据提示进行操作"
echo ""

# 询问是否要查看可用选项
read -p "是否查看安装选项？[y/N] " show_options
if [[ "$show_options" =~ ^[Yy] ]]; then
  ./install.sh --help
  echo ""
  
  # 逐个询问并设置参数
  install_params=""
  
  # 询问是否跳过Xcode Command Line Tools安装
  read -p "是否跳过Xcode命令行工具安装？[y/N] " skip_xcode
  [[ "$skip_xcode" =~ ^[Yy] ]] && install_params="$install_params --no-xcode"
  
  # 询问是否跳过Homebrew安装
  read -p "是否跳过Homebrew安装？[y/N] " skip_homebrew
  [[ "$skip_homebrew" =~ ^[Yy] ]] && install_params="$install_params --no-homebrew"
  
  # 询问是否跳过开发工具安装
  read -p "是否跳过开发工具安装？[y/N] " skip_devtools
  [[ "$skip_devtools" =~ ^[Yy] ]] && install_params="$install_params --no-devtools"
  
  # 询问是否跳过macOS系统设置
  read -p "是否跳过macOS系统设置？[y/N] " skip_macos
  [[ "$skip_macos" =~ ^[Yy] ]] && install_params="$install_params --no-macos"
  
  # 询问是否显示详细输出
  read -p "是否显示详细安装输出？[y/N] " verbose
  [[ "$verbose" =~ ^[Yy] ]] && install_params="$install_params --verbose"
  
  # 询问是否跳过所有确认提示
  read -p "是否跳过所有确认提示？[y/N] " skip_confirmation
  [[ "$skip_confirmation" =~ ^[Yy] ]] && install_params="$install_params --yes"
  
  # 询问是否跳过环境检查
  read -p "是否跳过环境检查？[y/N] " skip_env_check
  [[ "$skip_env_check" =~ ^[Yy] ]] && install_params="$install_params --no-env-check"
  
  echo ""
  echo "将使用以下参数进行安装: $install_params"
  read -p "是否继续？[Y/n] " continue_install
  
  if [[ ! "$continue_install" =~ ^[Nn] ]]; then
    if [ -n "$install_params" ]; then
      # 将参数字符串拆分为数组 - 使用更兼容的方式
      OLD_IFS="$IFS"
      IFS=' '
      param_array=($install_params)
      IFS="$OLD_IFS"
      # 使用"${param_array[@]}"传递所有参数
      ./install.sh "${param_array[@]}"
    else
      # 直接运行安装脚本
      ./install.sh
    fi
  else
    echo "安装已取消"
    cleanup
    exit 0
  fi
else
  # 直接运行安装脚本
  ./install.sh
fi

# 安装完成后清理
cleanup

echo ""
echo "安装已完成！"
echo "详细日志请查看: $LOG_FILE"
