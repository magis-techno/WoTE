#!/bin/bash
# Environment setup script for WoTE project
# Usage: source setup_env.sh

echo "Setting up WoTE environment variables..."

# Data-related paths (reuse DiffusionDrive)
export NUPLAN_MAP_VERSION="nuplan-maps-v1.0"
export NUPLAN_MAPS_ROOT="/mnt/sdb/DiffusionDrive/dataset/maps"
export OPENSCENE_DATA_ROOT="/mnt/sdb/DiffusionDrive/dataset"

# WoTE project paths
export WOTE_PROJECT_ROOT="/mnt/sdb/WoTE"
export NAVSIM_EXP_ROOT="$WOTE_PROJECT_ROOT/exp"
export NAVSIM_DEVKIT_ROOT="$WOTE_PROJECT_ROOT/navsim"

echo "Environment variables set:"
echo "  NUPLAN_MAP_VERSION=$NUPLAN_MAP_VERSION"
echo "  NUPLAN_MAPS_ROOT=$NUPLAN_MAPS_ROOT"
echo "  OPENSCENE_DATA_ROOT=$OPENSCENE_DATA_ROOT"
echo "  WOTE_PROJECT_ROOT=$WOTE_PROJECT_ROOT"
echo "  NAVSIM_EXP_ROOT=$NAVSIM_EXP_ROOT"
echo "  NAVSIM_DEVKIT_ROOT=$NAVSIM_DEVKIT_ROOT"
echo "Environment setup complete!"