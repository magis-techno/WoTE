SPLIT=test
# SPLIT=trainval

python $NAVSIM_DEVKIT_ROOT/planning/script/run_metric_caching.py \
split=$SPLIT \
cache.cache_path='$NAVSIM_EXP_ROOT/metric_cache' \
scene_filter.frame_interval=1 \
