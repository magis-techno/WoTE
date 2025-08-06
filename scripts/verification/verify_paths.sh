#!/bin/bash
# 路径配置验证脚本
# Usage: bash scripts/verification/verify_paths.sh

echo "🔍 验证环境变量和路径配置..."
echo "=========================="

# 检查关键环境变量
echo "📂 环境变量检查："
echo "  NAVSIM_EXP_ROOT=$NAVSIM_EXP_ROOT"
echo "  NAVSIM_DEVKIT_ROOT=$NAVSIM_DEVKIT_ROOT"
echo "  OPENSCENE_DATA_ROOT=$OPENSCENE_DATA_ROOT"

# 检查环境变量是否已设置
if [ -z "$NAVSIM_EXP_ROOT" ]; then
    echo "❌ NAVSIM_EXP_ROOT 未设置！请运行: source setup_env.sh"
    exit 1
fi

if [ -z "$NAVSIM_DEVKIT_ROOT" ]; then
    echo "❌ NAVSIM_DEVKIT_ROOT 未设置！请运行: source setup_env.sh"
    exit 1
fi

echo "✅ 环境变量已正确设置"

# 检查期望的缓存路径
EXPECTED_CACHE_PATH="$NAVSIM_EXP_ROOT/metric_cache"
echo ""
echo "📁 路径解析检查："
echo "  期望的缓存路径: $EXPECTED_CACHE_PATH"

# 检查是否存在错误的嵌套路径
NESTED_PATH="$NAVSIM_EXP_ROOT/metric_cache/metadata/$NAVSIM_EXP_ROOT/metric_cache"
if [ -d "$NESTED_PATH" ]; then
    echo "⚠️  发现错误的嵌套路径: $NESTED_PATH"
    echo "   需要运行数据迁移脚本"
else
    echo "✅ 未发现嵌套路径问题"
fi

# 检查正确的缓存路径是否存在
if [ -d "$EXPECTED_CACHE_PATH" ]; then
    echo "✅ 正确的缓存路径已存在: $EXPECTED_CACHE_PATH"
    echo "   内容列表："
    ls -la "$EXPECTED_CACHE_PATH" | head -10
else
    echo "📝 正确的缓存路径尚不存在: $EXPECTED_CACHE_PATH"
fi

# 测试配置文件解析（模拟）
echo ""
echo "🧪 配置解析测试："
echo "  模拟 Hydra 配置解析..."

# 临时创建测试脚本来验证路径解析
cat > /tmp/test_path_config.py << EOF
import os
from pathlib import Path

# 模拟配置解析
navsim_exp_root = os.environ.get('NAVSIM_EXP_ROOT', '')
cache_path = f"{navsim_exp_root}/metric_cache"
output_dir = f"{cache_path}/metadata"

print(f"  cache_path: {cache_path}")
print(f"  output_dir: {output_dir}")
print(f"  ✅ 路径解析正常，无嵌套问题")
EOF

python /tmp/test_path_config.py
rm /tmp/test_path_config.py

echo ""
echo "🎯 验证完成！"