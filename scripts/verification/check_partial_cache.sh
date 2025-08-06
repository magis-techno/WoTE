#!/bin/bash
# 检查部分完成的缓存状态
# Usage: bash scripts/verification/check_partial_cache.sh

echo "🔍 检查部分完成的缓存状态"
echo "=========================="

# 检查环境变量
if [ -z "$NAVSIM_EXP_ROOT" ] || [ -z "$WOTE_PROJECT_ROOT" ]; then
    echo "❌ 环境变量未设置，请先运行: source setup_env.sh"
    exit 1
fi

# 定义路径
CORRECT_CACHE_PATH="$NAVSIM_EXP_ROOT/metric_cache"
WRONG_NESTED_PATH="$WOTE_PROJECT_ROOT/\$NAVSIM_EXP_ROOT/metric_cache/metadata/\$NAVSIM_EXP_ROOT/metric_cache"
METADATA_PATH="$NAVSIM_EXP_ROOT/metric_cache/metadata"

echo "📂 检查缓存状态..."

# 检查错误路径中的缓存数据
if [ -d "$WRONG_NESTED_PATH" ]; then
    echo "⚠️  错误路径中存在数据: $WRONG_NESTED_PATH"
    file_count=$(ls -1 "$WRONG_NESTED_PATH" 2>/dev/null | wc -l)
    echo "   包含 $file_count 个缓存文件"
    echo "   最新文件:"
    ls -lt "$WRONG_NESTED_PATH" | head -5
    echo ""
else
    echo "✅ 错误路径中无数据"
fi

# 检查正确路径中的缓存数据
if [ -d "$CORRECT_CACHE_PATH" ]; then
    echo "📁 正确路径状态: $CORRECT_CACHE_PATH"
    file_count=$(ls -1 "$CORRECT_CACHE_PATH" 2>/dev/null | wc -l)
    echo "   包含 $file_count 个文件/目录"
    if [ $file_count -gt 0 ]; then
        echo "   内容预览:"
        ls -la "$CORRECT_CACHE_PATH" | head -10
    fi
else
    echo "📝 正确路径尚不存在"
fi

# 检查元数据状态
if [ -d "$METADATA_PATH" ]; then
    echo ""
    echo "📊 元数据状态: $METADATA_PATH"
    metadata_files=$(ls -1 "$METADATA_PATH"/*.csv 2>/dev/null | wc -l)
    echo "   CSV元数据文件数: $metadata_files"
    if [ $metadata_files -gt 0 ]; then
        echo "   最新元数据文件:"
        ls -lt "$METADATA_PATH"/*.csv 2>/dev/null | head -3
    fi
else
    echo "📝 元数据目录尚不存在"
fi

echo ""
echo "🔧 建议操作:"
if [ -d "$WRONG_NESTED_PATH" ]; then
    echo "1. 首先迁移已有的缓存数据到正确位置"
    echo "   bash scripts/verification/migrate_cache_data.sh"
    echo ""
    echo "2. 然后继续运行metric caching（支持断点续传）"
    echo "   bash scripts/evaluation/run_metric_caching.sh"
else
    echo "1. 直接继续运行metric caching（支持断点续传）"
    echo "   bash scripts/evaluation/run_metric_caching.sh"
fi

echo ""
echo "💡 提示: NavSim的缓存系统支持断点续传，会自动跳过已缓存的场景"