#!/bin/bash
# 恢复metric caching任务
# Usage: bash scripts/verification/resume_caching.sh

echo "🔄 恢复Metric Caching任务"
echo "========================"

# 检查环境变量
if [ -z "$NAVSIM_EXP_ROOT" ] || [ -z "$WOTE_PROJECT_ROOT" ]; then
    echo "❌ 环境变量未设置，请先运行: source setup_env.sh"
    exit 1
fi

# 首先检查当前状态
echo "📊 检查当前缓存状态..."
bash scripts/verification/check_partial_cache.sh

echo ""
read -p "❓ 是否要先迁移错误路径中的数据？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚚 开始迁移数据..."
    bash scripts/verification/migrate_cache_data.sh
    if [ $? -ne 0 ]; then
        echo "❌ 数据迁移失败"
        exit 1
    fi
    echo "✅ 数据迁移完成"
fi

echo ""
echo "🔄 准备恢复metric caching..."
echo "💡 NavSim会自动检测已缓存的文件并跳过，实现断点续传"

# 确认继续
read -p "❓ 是否现在继续运行metric caching？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 开始运行metric caching..."
    echo "⏰ 开始时间: $(date)"
    
    # 记录开始时间
    start_time=$(date +%s)
    
    # 运行metric caching
    bash scripts/evaluation/run_metric_caching.sh
    
    # 记录结束时间
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo ""
    echo "⏰ 完成时间: $(date)"
    echo "⏱️  总耗时: ${duration} 秒"
    
    # 检查最终状态
    echo ""
    echo "📊 最终状态检查:"
    bash scripts/verification/verify_paths.sh
else
    echo "🚫 已取消恢复操作"
    echo "💡 稍后可以手动运行: bash scripts/evaluation/run_metric_caching.sh"
fi