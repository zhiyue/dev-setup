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
  read -p "请输入安装参数 (直接回车使用默认设置): " install_args
  ./install.sh $install_args
else
  # 直接运行安装脚本
  ./install.sh
fi

# 安装完成后清理
cleanup

echo ""
echo "安装已完成！"
echo "详细日志请查看: $LOG_FILE"
