#!/bin/bash
# 智能断点续传缓存脚本
# Usage: bash scripts/verification/smart_resume_caching.sh

echo "🚀 智能断点续传Metric Caching"
echo "============================="

# 检查环境变量
if [ -z "$NAVSIM_EXP_ROOT" ] || [ -z "$WOTE_PROJECT_ROOT" ]; then
    echo "❌ 环境变量未设置，请先运行: source setup_env.sh"
    exit 1
fi

CACHE_PATH="$NAVSIM_EXP_ROOT/metric_cache"

# 统计已缓存的文件
echo "📊 统计当前缓存状态..."
if [ -d "$CACHE_PATH" ]; then
    total_cached=$(find "$CACHE_PATH" -name "*.pkl" | wc -l)
    echo "  已缓存场景数: $total_cached"
    
    # 显示最新缓存的文件（确认是否在正确路径）
    echo "  最新缓存文件:"
    find "$CACHE_PATH" -name "*.pkl" -printf '%T@ %p\n' | sort -nr | head -3 | cut -d' ' -f2-
else
    total_cached=0
    echo "  缓存目录不存在"
fi

echo ""
echo "🔍 预估缓存进度..."

# 根据split估算总场景数
SPLIT=${1:-trainval}
case $SPLIT in
    "trainval")
        estimated_total=175000  # 大概的trainval场景数
        ;;
    "test")
        estimated_total=45000   # 大概的test场景数
        ;;
    *)
        estimated_total=0
        ;;
esac

if [ $estimated_total -gt 0 ] && [ $total_cached -gt 0 ]; then
    progress=$((total_cached * 100 / estimated_total))
    echo "  估算进度: $total_cached / ~$estimated_total ($progress%)"
fi

echo ""
echo "💡 NavSim缓存机制说明:"
echo "  ✅ 每个场景会检查 .pkl 文件是否存在"
echo "  ✅ 存在则跳过该场景的处理"
echo "  ⚠️  但多进程启动时仍会扫描所有场景列表"
echo "  ⚠️  这导致看起来没有断点续传，实际上有跳过机制"

echo ""
read -p "❓ 了解机制后，是否继续运行缓存？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 开始运行metric caching (支持跳过已缓存场景)..."
    echo "⏰ 开始时间: $(date)"
    
    # 记录开始时的缓存数量
    start_cached=$total_cached
    start_time=$(date +%s)
    
    # 运行缓存
    bash scripts/evaluation/run_metric_caching.sh
    
    # 统计结果
    end_time=$(date +%s)
    end_cached=$(find "$CACHE_PATH" -name "*.pkl" 2>/dev/null | wc -l)
    new_cached=$((end_cached - start_cached))
    duration=$((end_time - start_time))
    
    echo ""
    echo "📊 缓存完成统计:"
    echo "  开始时已缓存: $start_cached"
    echo "  结束时总缓存: $end_cached"
    echo "  新增缓存数: $new_cached"
    echo "  总耗时: ${duration}秒"
    
    if [ $new_cached -gt 0 ]; then
        avg_time=$((duration / new_cached))
        echo "  平均每场景: ${avg_time}秒"
    fi
    
    # 检查元数据CSV
    metadata_count=$(find "$NAVSIM_EXP_ROOT/metric_cache/metadata" -name "*.csv" 2>/dev/null | wc -l)
    echo "  元数据CSV文件: $metadata_count"
    
    if [ $metadata_count -gt 0 ]; then
        echo "✅ 缓存任务完全完成！"
    else
        echo "⚠️  缓存进行中或未完全完成"
    fi
    
else
    echo "🚫 已取消运行"
    echo ""
    echo "💡 提示："
    echo "  - 已有 $total_cached 个场景已缓存，不会重复处理"
    echo "  - 可随时重新运行，NavSim会自动跳过已缓存的场景"
    echo "  - 元数据CSV文件只在全部完成后生成"
fi