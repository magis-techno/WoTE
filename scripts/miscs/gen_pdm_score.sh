# Ensure environment variables are set
# Please run: source setup_env.sh first
export PYTHONPATH=$WOTE_PROJECT_ROOT/

python scripts/miscs/gen_multi_trajs_pdm_score.py \
agent=WoTE_agent \
'agent.checkpoint_path="$NAVSIM_EXP_ROOT/WoTE/default/lightning_logs/version_0/checkpoints/epoch=29-step=9990.ckpt"' \
agent.config._target_=navsim.agents.WoTE.configs.default.WoTEConfig \
experiment_name=eval/gen_data \
metric_cache_path='$WOTE_PROJECT_ROOT/dataset/metric_cache/trainval' \
split=trainval \
scene_filter=navtrain \