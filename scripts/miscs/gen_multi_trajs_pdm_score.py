import pandas as pd
from tqdm import tqdm
import traceback
import numpy as np

import hydra
from hydra.utils import instantiate
from omegaconf import DictConfig

from pathlib import Path
from typing import Any, Dict, List, Union, Tuple
from dataclasses import asdict
from datetime import datetime
import logging
import lzma
import pickle
import os
import uuid

from nuplan.planning.script.builders.logging_builder import build_logger
from nuplan.planning.utils.multithreading.worker_utils import worker_map

from navsim.planning.script.builders.worker_pool_builder import build_worker
from navsim.common.dataloader import MetricCacheLoader
from navsim.agents.abstract_agent import AbstractAgent
from navsim.evaluate.pdm_score import pdm_score, pdm_score_multi_trajs
from navsim.planning.simulation.planner.pdm_planner.simulation.pdm_simulator import (
    PDMSimulator
)
from navsim.planning.simulation.planner.pdm_planner.scoring.pdm_scorer import PDMScorer
from navsim.common.dataloader import SceneLoader, SceneFilter
from navsim.planning.metric_caching.metric_cache import MetricCache
from navsim.common.dataclasses import SensorConfig
from navsim.common.dataclasses import AgentInput, Trajectory
from nuplan.planning.simulation.trajectory.trajectory_sampling import TrajectorySampling


logger = logging.getLogger(__name__)

num_clusters = 256
num_horizons = 4
compute_state_only = False
if compute_state_only:
    print("Computing state only")

CONFIG_PATH = os.path.join(os.environ.get('WOTE_PROJECT_ROOT', ''), 'navsim/planning/script/config/pdm_scoring')
CONFIG_NAME = "default_run_pdm_score"
@hydra.main(config_path=CONFIG_PATH, config_name=CONFIG_NAME)
def main(cfg: DictConfig) -> None:
    build_logger(cfg)
    worker = build_worker(cfg)

    scene_loader = SceneLoader(
        sensor_blobs_path=None,
        data_path=Path(cfg.navsim_log_path),
        scene_filter=instantiate(cfg.scene_filter),
        sensor_config=SensorConfig.build_no_sensors(),
    )

    # Load metric cache index
    metric_cache_loader = MetricCacheLoader(Path(cfg.metric_cache_path))

    # Determine already-formatted tokens (to support resume)
    formatted_path = os.path.join(
        os.environ.get('OPENSCENE_DATA_ROOT', ''), f'extra_data/planning_vb/formatted_pdm_score_{num_clusters}.npy'
    )
    done_tokens: set[str] = set()
    if os.path.exists(formatted_path):
        try:
            existing = np.load(formatted_path, allow_pickle=True)
            # try to coerce to dict
            if isinstance(existing, np.ndarray) and existing.dtype == object:
                try:
                    existing = existing.item()
                except Exception:
                    existing = {}
            if isinstance(existing, dict):
                done_tokens = set(k for k in existing.keys() if isinstance(k, str))
                logger.info("Found existing formatted file with %d tokens; will skip them.", len(done_tokens))
            else:
                logger.warning("Existing formatted file found but could not parse as dict; proceeding without resume.")
        except Exception as e:
            logger.warning("Failed to read existing formatted file: %s; proceeding without resume.", e)

    # Compute candidate tokens and remaining to evaluate
    all_candidates = set(scene_loader.tokens) & set(metric_cache_loader.tokens)
    remaining_tokens = list(all_candidates - done_tokens)
    logger.info(
        "Tokens - in_cache: %d, done(formatted): %d, remaining: %d",
        len(all_candidates), len(done_tokens), len(remaining_tokens)
    )

    # Build data points per log with filtered remaining tokens
    data_points: List[Dict[str, Any]] = []
    for log_file, tokens_list in scene_loader.get_tokens_list_per_log().items():
        filtered = list(set(tokens_list) & set(remaining_tokens))
        if filtered:
            data_points.append({
                "cfg": cfg,
                "log_file": log_file,
                "tokens": filtered,
            })

    logger.info("Starting pdm scoring of %s scenarios (remaining only)...", sum(len(dp["tokens"]) for dp in data_points))

    single_eval = getattr(cfg, 'single_eval', False)
    # single-threaded worker_map
    if single_eval:
        print("Running single-threaded worker_map")
        score_rows = run_pdm_score(data_points)
    else:
        # multi-threaded worker_map
        score_rows: List[Tuple[Dict[str, Any], int, int]] = worker_map(worker, run_pdm_score, data_points)

    # Call the refactored function
    if compute_state_only:
        pdm_score_df = format_and_save_ego_states(score_rows, num_clusters, cfg.output_dir)
    else:
        pdm_score_df = format_and_save_scores(score_rows, num_clusters, cfg.output_dir)


def format_and_save_ego_states(score_rows, num_clusters, output_dir):
    # Format score_rows into dictionary
    score_dict = {}
    for row in tqdm(score_rows):
        value = {}
        for k, v in row.items():
            if k == 'token':
                continue
            # Rename 'trajectory_scores' to 'simulated_ego_states'
            new_key = 'simulated_ego_states_rel' if k == 'trajectory_scores' else k
            value[new_key] = v
        key = row['token']
        score_dict[key] = value

    # Save formatted score_rows using numpy
    save_path = os.path.join(os.environ.get('WOTE_PROJECT_ROOT', ''), f'simulated_ego_states_{num_clusters}_trainval.npy')
    np.save(save_path, score_dict, allow_pickle=True)


def format_and_save_scores(score_rows, num_clusters, output_dir):
    """
    Formats the score rows into a dictionary, merges with existing file if present,
    saves them, and outputs a summary DataFrame.
    """
    # Build new results dict
    new_dict: Dict[str, Any] = {}
    for row in tqdm(score_rows):
        key = row['token']
        value = {k: v for k, v in row.items() if k != 'token'}
        new_dict[key] = value

    save_path = os.path.join(os.environ.get('OPENSCENE_DATA_ROOT', ''), f'extra_data/planning_vb/formatted_pdm_score_{num_clusters}.npy')

    # Merge with existing if any (resume-friendly)
    merged: Dict[str, Any] = {}
    existing_count = 0
    if os.path.exists(save_path):
        try:
            existing = np.load(save_path, allow_pickle=True)
            if isinstance(existing, np.ndarray) and existing.dtype == object:
                try:
                    existing = existing.item()
                except Exception:
                    existing = {}
            if isinstance(existing, dict):
                merged.update(existing)
                existing_count = len(existing)
            else:
                logger.warning("Existing formatted file present but not a dict; overwriting with new results only.")
        except Exception as e:
            logger.warning("Failed loading existing formatted file (%s); overwriting with new results only.", e)

    # Update with new results (new overwrites same-token entries if any)
    merged.update(new_dict)

    # Save merged results
    np.save(save_path, merged, allow_pickle=True)
    logger.info("Saved formatted scores to %s (existing=%d, added=%d, total=%d)",
                save_path, existing_count, len(new_dict), len(merged))

    # Build summary DataFrame from new rows only
    pdm_score_df = pd.DataFrame(score_rows)
    num_successful_scenarios = pdm_score_df.get("valid", pd.Series([], dtype=bool)).sum() if not pdm_score_df.empty else 0
    num_failed_scenarios = len(pdm_score_df) - num_successful_scenarios
    if not pdm_score_df.empty and "token" in pdm_score_df.columns and "valid" in pdm_score_df.columns:
        average_row = pdm_score_df.drop(columns=[c for c in ["token", "valid"] if c in pdm_score_df.columns]).mean(skipna=True)
        average_row["token"] = "average"
        average_row["valid"] = pdm_score_df["valid"].all()
        pdm_score_df.loc[len(pdm_score_df)] = average_row

    timestamp = datetime.now().strftime("%Y.%m.%d.%H.%M.%S")
    try:
        pdm_score_df.to_csv(Path(output_dir) / f"{timestamp}.csv")
    except Exception:
        # Avoid failing the run due to CSV writing issues
        pass

    logger.info(
        "Finished evaluation batch. Successful: %d, Failed: %d. CSV written to: %s",
        num_successful_scenarios, num_failed_scenarios, str(Path(output_dir) / f"{timestamp}.csv")
    )

    return pdm_score_df


def run_pdm_score(args: List[Dict[str, Union[List[str], DictConfig]]]) -> List[Dict[str, Any]]:
    node_id = int(os.environ.get("NODE_RANK", 0))
    thread_id = str(uuid.uuid4())
    logger.info(f"Starting worker in thread_id={thread_id}, node_id={node_id}")

    log_names = [a["log_file"] for a in args]
    tokens = [t for a in args for t in a["tokens"]]
    cfg: DictConfig = args[0]["cfg"]

    simulator: PDMSimulator = instantiate(cfg.simulator)
    scorer: PDMScorer = instantiate(cfg.scorer)

    # proposal_sampling
    proposal_sampling = simulator.proposal_sampling
    proposal_sampling.time_horizon = num_horizons
    proposal_sampling.num_poses = int(num_horizons * 10)

    scorer.proposal_sampling = proposal_sampling
    simulator.proposal_sampling = proposal_sampling

    assert simulator.proposal_sampling == scorer.proposal_sampling, "Simulator and scorer proposal sampling has to be identical"

    metric_cache_loader = MetricCacheLoader(Path(cfg.metric_cache_path))
    scene_filter: SceneFilter =instantiate(cfg.scene_filter)
    scene_filter.log_names = log_names
    scene_filter.tokens = tokens
    scene_loader = SceneLoader(
        sensor_blobs_path=Path(cfg.sensor_blobs_path),
        data_path=Path(cfg.navsim_log_path),
        scene_filter=scene_filter,
        sensor_config=SensorConfig.build_no_sensors(),
    )
    predefined_trajectories = load_predefined_trajectories()

    tokens_to_evaluate = list(set(scene_loader.tokens) & set(metric_cache_loader.tokens))
    pdm_results: List[Dict[str, Any]] = []
    for idx, (token) in tqdm(enumerate(tokens_to_evaluate)):
        score_row: Dict[str, Any] = {"token": token, "valid": True}
        metric_cache_path = metric_cache_loader.metric_cache_paths[token]
        with lzma.open(metric_cache_path, "rb") as f:
            metric_cache: MetricCache = pickle.load(f)

        trajectory_scores = []

        pdm_result = pdm_score_multi_trajs(
            metric_cache=metric_cache,
            model_trajectory_list=predefined_trajectories,
            future_sampling=proposal_sampling,
            simulator=simulator,
            scorer=scorer,
        )
        if compute_state_only:
            trajectory_scores.append(pdm_result)
        else:
            trajectory_scores.append(asdict(pdm_result))
        
        # Update the score_row with the computed scores
        score_row["trajectory_scores"] = trajectory_scores

        pdm_results.append(score_row)
    return pdm_results


def load_predefined_trajectories() -> List[Any]:
    """
    Load 256 pre-defined trajectories from the given path.
    Assumes that the trajectories are stored in a serialized format (e.g., pickle).
    """

    path = os.path.join(os.environ.get('OPENSCENE_DATA_ROOT', ''), f'extra_data/planning_vb/trajectory_anchors_{num_clusters}.npy')
    with open(path, "rb") as f:
        trajectories = np.load(f)
    return trajectories


if __name__ == "__main__":
    main()