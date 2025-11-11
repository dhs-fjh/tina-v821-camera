#!/bin/bash
# 为 Tina V821 SDK 生成 compile_commands.json
# 用于 clangd 代码补全和语法检查

set -e

echo "========================================="
echo "Tina V821 SDK - 生成 clangd 编译数据库"
echo "========================================="

# 检查并加载构建配置
if [ -f ".buildconfig" ]; then
    echo "从 .buildconfig 加载配置..."
    source .buildconfig
elif [ -z "$LICHEE_CHIP" ]; then
    echo "错误: 未初始化构建环境"
    echo "请先运行:"
    echo "  source build/envsetup.sh && lunch"
    echo ""
    echo "然后重新运行此脚本:"
    echo "  ./generate_compile_commands.sh"
    exit 1
fi

echo "当前配置:"
echo "  芯片: $LICHEE_CHIP"
echo "  架构: $LICHEE_ARCH"
echo "  内核: $LICHEE_KERN_VER"
echo ""

# 获取项目根目录
TINA_ROOT=$(pwd)
COMPILE_DB="$TINA_ROOT/compile_commands.json"

echo "正在生成编译数据库..."

# 方法1: 使用 bear (推荐)
if command -v bear &> /dev/null; then
    echo "检测到 bear 工具，使用 bear 生成编译数据库"
    echo "提示: 这会执行一次完整编译，请耐心等待..."

    # 清理旧的编译数据库
    rm -f "$COMPILE_DB"

    # 使用 bear 捕获编译命令
    bear -- ./build.sh

    if [ -f "$COMPILE_DB" ]; then
        echo "✓ 编译数据库已生成: $COMPILE_DB"
        echo "  条目数: $(jq '. | length' "$COMPILE_DB" 2>/dev/null || echo '未知')"
    else
        echo "✗ bear 未能生成编译数据库"
        exit 1
    fi

# 方法2: 内核单独处理（如果只需要内核代码补全）
else
    echo "未找到 bear 工具"
    echo "正在尝试为内核生成编译数据库..."

    # 进入内核目录
    KERNEL_DIR="$TINA_ROOT/kernel/linux-$LICHEE_KERN_VER"

    if [ ! -d "$KERNEL_DIR" ]; then
        echo "错误: 内核目录不存在: $KERNEL_DIR"
        exit 1
    fi

    cd "$KERNEL_DIR"

    # 使用内核自带的脚本生成
    if [ -f "scripts/clang-tools/gen_compile_commands.py" ]; then
        echo "使用内核脚本生成编译数据库..."
        python3 scripts/clang-tools/gen_compile_commands.py -d "$TINA_ROOT/out/$LICHEE_CHIP/kernel/build"

        # 移动到项目根目录
        if [ -f "$KERNEL_DIR/compile_commands.json" ]; then
            mv "$KERNEL_DIR/compile_commands.json" "$COMPILE_DB"
            echo "✓ 内核编译数据库已生成: $COMPILE_DB"
        fi
    else
        echo "错误: 内核脚本不存在"
        echo ""
        echo "请安装 bear 工具:"
        echo "  Ubuntu/Debian: sudo apt-get install bear"
        echo "  Arch Linux: sudo pacman -S bear"
        echo ""
        echo "或者手动生成:"
        echo "  1. 先完整编译一次项目"
        echo "  2. 使用 bear 捕获: bear -- ./build.sh"
        exit 1
    fi
fi

echo ""
echo "========================================="
echo "配置完成！"
echo "========================================="
echo ""
echo "VSCode 使用说明:"
echo "1. 安装 clangd 扩展 (llvm-vs-code-extensions.vscode-clangd)"
echo "2. 禁用 C/C++ 扩展的 IntelliSense (在设置中搜索 'C_Cpp.intelliSenseEngine' 设为 Disabled)"
echo "3. 重启 VSCode 或重新加载窗口"
echo "4. 打开任意 .c/.h 文件，clangd 会自动启动索引"
echo ""
echo "命令行测试:"
echo "  clangd --check=kernel/${LICHEE_KERN_VER}/drivers/base/core.c"
echo ""
