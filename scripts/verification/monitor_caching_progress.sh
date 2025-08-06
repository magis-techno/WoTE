#!/bin/bash
# 实时监控缓存进度脚本
# Usage: bash scripts/verification/monitor_caching_progress.sh

echo "📊 实时监控Metric Caching进度"
echo "============================"

if [ -z "$NAVSIM_EXP_ROOT" ]; then
    echo "❌ NAVSIM_EXP_ROOT 未设置！请运行: source setup_env.sh"
    exit 1
fi

CACHE_PATH="$NAVSIM_EXP_ROOT/metric_cache"
INTERVAL=${1:-30}  # 默认30秒检查一次

echo "🔍 监控路径: $CACHE_PATH"
echo "⏱️  检查间隔: ${INTERVAL}秒"
echo "🛑 按 Ctrl+C 停止监控"
echo ""

# 初始统计
if [ -d "$CACHE_PATH" ]; then
    initial_count=$(find "$CACHE_PATH" -name "*.pkl" | wc -l)
else
    initial_count=0
    mkdir -p "$CACHE_PATH"
fi

start_time=$(date +%s)
echo "$(date '+%H:%M:%S') - 开始监控，当前缓存: $initial_count 个场景"

# 监控循环
while true; do
    sleep $INTERVAL
    
    current_time=$(date +%s)
    current_count=$(find "$CACHE_PATH" -name "*.pkl" 2>/dev/null | wc -l)
    elapsed=$((current_time - start_time))
    new_files=$((current_count - initial_count))
    
    # 计算速度
    if [ $elapsed -gt 0 ] && [ $new_files -gt 0 ]; then
        speed=$(echo "scale=2; $new_files / ($elapsed / 60)" | bc -l 2>/dev/null || echo "N/A")
        speed_text=" (${speed} 场景/分钟)"
    else
        speed_text=""
    fi
    
    # 显示进度
    elapsed_min=$((elapsed / 60))
    elapsed_sec=$((elapsed % 60))
    printf "$(date '+%H:%M:%S') - 缓存数: %d (+%d) | 耗时: %02d:%02d%s\n" \
           $current_count $new_files $elapsed_min $elapsed_sec "$speed_text"
    
    # 检查是否有元数据文件生成（表示完成）
    metadata_count=$(find "$NAVSIM_EXP_ROOT/metric_cache/metadata" -name "*.csv" 2>/dev/null | wc -l)
    if [ $metadata_count -gt 0 ]; then
        echo "✅ 检测到元数据CSV文件，缓存任务可能已完成！"
        break
    fi
    
    # 检查最近是否有新文件生成（检测进程是否还在工作）
    recent_files=$(find "$CACHE_PATH" -name "*.pkl" -newermt "1 minute ago" 2>/dev/null | wc -l)
    if [ $recent_files -eq 0 ] && [ $elapsed -gt 120 ]; then
        echo "⚠️  最近1分钟无新文件，进程可能已停止"
    fi
done

echo ""
echo "📊 监控结束统计:"
echo "  总新增缓存: $new_files 个场景"
echo "  总耗时: ${elapsed_min}分${elapsed_sec}秒"