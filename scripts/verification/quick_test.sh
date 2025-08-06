#!/bin/bash
# 快速测试脚本 - 验证路径修复是否生效
# Usage: bash scripts/verification/quick_test.sh

echo "🚀 快速路径配置测试"
echo "==================="

# 检查环境变量
if [ -z "$NAVSIM_EXP_ROOT" ] || [ -z "$WOTE_PROJECT_ROOT" ]; then
    echo "❌ 环境变量未设置，请先运行: source setup_env.sh"
    exit 1
fi

echo "✅ 环境变量已设置"
echo "  WOTE_PROJECT_ROOT: $WOTE_PROJECT_ROOT"
echo "  NAVSIM_EXP_ROOT: $NAVSIM_EXP_ROOT"

# 检查错误路径是否存在
WRONG_PATH="$WOTE_PROJECT_ROOT/\$NAVSIM_EXP_ROOT"
if [ -d "$WRONG_PATH" ]; then
    echo "⚠️  发现错误路径: $WRONG_PATH"
    echo "   列出内容:"
    ls -la "$WRONG_PATH"
    echo ""
    echo "🔧 建议运行迁移脚本: bash scripts/verification/migrate_cache_data.sh"
else
    echo "✅ 未发现错误路径"
fi

# 检查正确路径
CORRECT_PATH="$NAVSIM_EXP_ROOT/metric_cache"
if [ -d "$CORRECT_PATH" ]; then
    echo "✅ 正确路径存在: $CORRECT_PATH"
    file_count=$(ls -1 "$CORRECT_PATH" 2>/dev/null | wc -l)
    echo "   包含 $file_count 个文件/目录"
else
    echo "📝 正确路径尚不存在: $CORRECT_PATH"
fi

echo ""
echo "🎯 测试完成！"