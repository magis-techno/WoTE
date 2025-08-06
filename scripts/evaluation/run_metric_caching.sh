# Configuration: Choose the split to cache
# SPLIT=test
SPLIT=trainval

echo "🔄 Generating metric cache for split: $SPLIT"
echo "📁 Cache will be saved to: $NAVSIM_EXP_ROOT/metric_cache"

# Create cache directory if it doesn't exist
mkdir -p "$NAVSIM_EXP_ROOT/metric_cache"

python $NAVSIM_DEVKIT_ROOT/planning/script/run_metric_caching.py \
split=$SPLIT \
cache.cache_path="$NAVSIM_EXP_ROOT/metric_cache" \
scene_filter.frame_interval=1 \

echo "✅ Metric caching completed for split: $SPLIT"
