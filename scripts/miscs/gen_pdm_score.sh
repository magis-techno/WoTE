# Ensure environment variables are set
# Please run: source setup_env.sh first
export PYTHONPATH=$WOTE_PROJECT_ROOT/

# Check if metric cache directory exists
METRIC_CACHE_DIR="$NAVSIM_EXP_ROOT/metric_cache"
if [ ! -d "$METRIC_CACHE_DIR" ] || [ ! -d "$METRIC_CACHE_DIR/metadata" ]; then
    echo "❌ Error: Metric cache directory not found at $METRIC_CACHE_DIR"
    echo "📝 Please run metric caching first:"
    echo "   1. For trainval split: Edit scripts/evaluation/run_metric_caching.sh to set SPLIT=trainval"
    echo "   2. Run: bash scripts/evaluation/run_metric_caching.sh"
    echo "   3. Then run this script again"
    exit 1
fi

echo "✅ Metric cache found at $METRIC_CACHE_DIR"

python scripts/miscs/gen_multi_trajs_pdm_score.py \
agent=WoTE_agent \
agent.checkpoint_path="$NAVSIM_EXP_ROOT/WoTE/default/lightning_logs/version_0/checkpoints/epoch=29-step=9990.ckpt" \
agent.config._target_=navsim.agents.WoTE.configs.default.WoTEConfig \
experiment_name=eval/gen_data \
metric_cache_path="$NAVSIM_EXP_ROOT/metric_cache" \
split=trainval \
scene_filter=navtrain