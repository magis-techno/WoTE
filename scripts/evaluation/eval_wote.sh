# Define - ensure environment variables are set
# Please run: source setup_env.sh first
export PYTHONPATH=$WOTE_PROJECT_ROOT/
export NUPLAN_MAP_VERSION="nuplan-maps-v1.0"
export NUPLAN_MAPS_ROOT="$NUPLAN_MAPS_ROOT"
export NAVSIM_EXP_ROOT="$NAVSIM_EXP_ROOT"
export NAVSIM_DEVKIT_ROOT="$NAVSIM_DEVKIT_ROOT"
export OPENSCENE_DATA_ROOT="$OPENSCENE_DATA_ROOT"

CONFIG_NAME=default

# evaluation: ensure the metric cache exists for the chosen split (test/trainval)
python ./navsim/planning/script/run_pdm_score.py \
agent=WoTE_agent \
agent.checkpoint_path='${oc.env:NAVSIM_EXP_ROOT}/WoTE/default/lightning_logs/version_0/checkpoints/epoch=29-step=19950.ckpt' \
agent.config._target_=navsim.agents.WoTE.configs.${CONFIG_NAME}.WoTEConfig \
experiment_name=eval/WoTE/${CONFIG_NAME}/ \
split=test \
scene_filter=navtest
