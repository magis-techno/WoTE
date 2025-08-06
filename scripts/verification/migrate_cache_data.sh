#!/bin/bash
# 缓存数据迁移脚本
# Usage: bash scripts/verification/migrate_cache_data.sh

echo "🚚 缓存数据迁移脚本"
echo "==================="

# 检查环境变量
if [ -z "$NAVSIM_EXP_ROOT" ]; then
    echo "❌ NAVSIM_EXP_ROOT 未设置！请运行: source setup_env.sh"
    exit 1
fi

# 定义路径
CORRECT_CACHE_PATH="$NAVSIM_EXP_ROOT/metric_cache"
WRONG_NESTED_PATH="$NAVSIM_EXP_ROOT/metric_cache/metadata/$NAVSIM_EXP_ROOT/metric_cache"
METADATA_PATH="$NAVSIM_EXP_ROOT/metric_cache/metadata"

echo "📂 路径信息："
echo "  正确缓存路径: $CORRECT_CACHE_PATH"
echo "  错误嵌套路径: $WRONG_NESTED_PATH"
echo "  元数据路径: $METADATA_PATH"

# 检查是否存在错误的嵌套数据
if [ ! -d "$WRONG_NESTED_PATH" ]; then
    echo "✅ 未发现需要迁移的嵌套数据"
    exit 0
fi

echo ""
echo "⚠️  发现嵌套路径数据，开始迁移..."

# 创建正确的目录结构
mkdir -p "$CORRECT_CACHE_PATH"

# 显示要迁移的数据
echo "📋 要迁移的数据："
ls -la "$WRONG_NESTED_PATH"

# 确认是否继续
read -p "❓ 是否继续迁移数据？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "🚫 迁移已取消"
    exit 0
fi

# 执行迁移
echo "🔄 开始迁移数据..."

# 迁移缓存文件（除了 metadata 目录）
cd "$WRONG_NESTED_PATH"
for item in *; do
    if [ "$item" != "metadata" ] && [ -e "$item" ]; then
        echo "  迁移: $item"
        mv "$item" "$CORRECT_CACHE_PATH/"
    fi
done

# 迁移元数据文件
if [ -d "$WRONG_NESTED_PATH/metadata" ]; then
    echo "  迁移 metadata 目录内容..."
    cd "$WRONG_NESTED_PATH/metadata"
    for item in *; do
        if [ -e "$item" ]; then
            echo "    迁移元数据: $item"
            mv "$item" "$METADATA_PATH/"
        fi
    done
fi

# 清理空的错误目录
echo "🧹 清理空目录..."
rmdir "$WRONG_NESTED_PATH/metadata" 2>/dev/null
rmdir "$WRONG_NESTED_PATH" 2>/dev/null

# 尝试删除嵌套的父目录（如果为空）
NESTED_PARENT=$(dirname "$WRONG_NESTED_PATH")
if [ "$NESTED_PARENT" != "$METADATA_PATH" ]; then
    rmdir "$NESTED_PARENT" 2>/dev/null
fi

echo ""
echo "✅ 数据迁移完成！"
echo "📊 迁移后的目录结构："
echo "  $CORRECT_CACHE_PATH:"
ls -la "$CORRECT_CACHE_PATH" | head -5
echo "  $METADATA_PATH:"
ls -la "$METADATA_PATH" | head -5

echo ""
echo "🎯 建议：运行验证脚本确认迁移结果"
echo "   bash scripts/verification/verify_paths.sh"