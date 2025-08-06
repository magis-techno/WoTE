#!/bin/bash
# 分析缓存状态脚本
# Usage: bash scripts/verification/analyze_cache_status.sh

echo "🔍 深度分析Metric Cache状态"
echo "=========================="

if [ -z "$NAVSIM_EXP_ROOT" ]; then
    echo "❌ NAVSIM_EXP_ROOT 未设置！请运行: source setup_env.sh"
    exit 1
fi

CACHE_PATH="$NAVSIM_EXP_ROOT/metric_cache"
METADATA_PATH="$NAVSIM_EXP_ROOT/metric_cache/metadata"

echo "📊 缓存文件统计:"

# 统计pkl文件
pkl_count=$(find "$CACHE_PATH" -name "*.pkl" 2>/dev/null | wc -l)
echo "  总PKL文件数: $pkl_count"

# 检查缓存目录结构
if [ -d "$CACHE_PATH" ]; then
    echo ""
    echo "📁 缓存目录结构分析:"
    
    # 统计日志目录数
    log_dirs=$(find "$CACHE_PATH" -maxdepth 1 -type d ! -path "$CACHE_PATH" ! -path "$METADATA_PATH" | wc -l)
    echo "  日志目录数: $log_dirs"
    
    # 示例目录结构
    echo "  目录结构示例:"
    find "$CACHE_PATH" -maxdepth 3 -type d | head -5 | sed 's|^|    |'
    
    # 检查每个日志目录的场景数
    echo ""
    echo "📈 各日志目录场景统计 (前10个):"
    find "$CACHE_PATH" -maxdepth 1 -type d ! -path "$CACHE_PATH" ! -path "$METADATA_PATH" | head -10 | while read dir; do
        if [ -d "$dir" ]; then
            scenes=$(find "$dir" -name "*.pkl" 2>/dev/null | wc -l)
            basename_dir=$(basename "$dir")
            printf "  %s: %d 场景\n" "$basename_dir" "$scenes"
        fi
    done
fi

# 检查元数据状态
echo ""
echo "📋 元数据状态:"
if [ -d "$METADATA_PATH" ]; then
    csv_files=$(find "$METADATA_PATH" -name "*.csv" 2>/dev/null | wc -l)
    echo "  元数据CSV文件数: $csv_files"
    
    if [ $csv_files -gt 0 ]; then
        echo "  CSV文件列表:"
        find "$METADATA_PATH" -name "*.csv" | sed 's|^|    |'
        
        # 读取CSV文件中的条目数
        for csv_file in $(find "$METADATA_PATH" -name "*.csv"); do
            if [ -f "$csv_file" ]; then
                csv_lines=$(($(wc -l < "$csv_file") - 1))  # 减去header行
                echo "    $(basename "$csv_file"): $csv_lines 条记录"
            fi
        done
    fi
else
    echo "  元数据目录不存在"
fi

# 计算实际进度
echo ""
echo "🎯 任务状态评估:"

if [ -d "$METADATA_PATH" ] && [ $(find "$METADATA_PATH" -name "*.csv" 2>/dev/null | wc -l) -gt 0 ]; then
    echo "  ✅ 元数据CSV存在 → 缓存任务已完成！"
    
    # 验证CSV记录数与PKL文件数是否匹配
    csv_total=0
    for csv_file in $(find "$METADATA_PATH" -name "*.csv"); do
        if [ -f "$csv_file" ]; then
            csv_lines=$(($(wc -l < "$csv_file") - 1))
            csv_total=$((csv_total + csv_lines))
        fi
    done
    
    echo "  📊 数据一致性检查:"
    echo "    PKL文件数: $pkl_count"
    echo "    CSV记录数: $csv_total"
    
    if [ $pkl_count -eq $csv_total ]; then
        echo "    ✅ 数据一致！"
    else
        echo "    ⚠️  数据不一致，可能有问题"
    fi
    
else
    echo "  ⏳ 缓存任务仍在进行中..."
    echo "  💡 PKL文件会先生成，CSV元数据在最后生成"
fi

# 估算trainval数据集的实际规模
echo ""
echo "💭 关于数据集规模:"
echo "  NavSim trainval 数据集包含约50万+ 场景"
echo "  你的 $pkl_count PKL文件说明缓存任务规模巨大"
echo "  337% 的进度显然是估算错误，实际应接近100%"

# 检查最近的活动
echo ""
echo "⏰ 最近活动检查:"
recent_files=$(find "$CACHE_PATH" -name "*.pkl" -newermt "10 minutes ago" 2>/dev/null | wc -l)
echo "  最近10分钟新增文件: $recent_files"

if [ $recent_files -eq 0 ]; then
    echo "  💤 可能已停止或完成"
else
    echo "  🔄 仍在活跃处理中"
fi