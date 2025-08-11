#!/usr/bin/env python3
import os
from pathlib import Path
import sys
import numpy as np
from typing import Optional

PRINT_SAMPLES = 10


def print_header(title: str):
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)


def env_path(name: str) -> Path:
    val = os.environ.get(name, "")
    print(f"{name} = {val}")
    return Path(val) if val else Path("")


def safe_load_npy_dict(path: Path):
    try:
        arr = np.load(str(path), allow_pickle=True)
        # np.save(dict) → np.load returns a numpy object. Try to convert to dict
        if isinstance(arr, np.ndarray) and arr.dtype == object:
            obj = arr.item() if arr.size == 1 else arr
            if isinstance(obj, dict):
                return obj
        if isinstance(arr, dict):
            return arr
        # fallback: try .item()
        try:
            return arr.item()
        except Exception:
            return None
    except Exception as e:
        print(f"! Failed to load {path}: {e}")
        return None


def summarize_tokens(name: str, tokens: set[str]):
    print(f"{name}: count = {len(tokens)}")
    if tokens:
        sample = list(tokens)[:PRINT_SAMPLES]
        print(f"{name} samples (up to {PRINT_SAMPLES}): {sample}")


def extract_token_from_cache_path(line: str) -> Optional[str]:
    # Expect .../<log_name>/<scenario_type>/<token>/metric_cache.pkl[.xz]
    parts = Path(line.strip()).parts
    if len(parts) < 2:
        return None
    # filename is last; token is parent dir name
    token = Path(line.strip()).parent.name
    return token if token else None


def main():
    print_header("Environment")
    openscene_root = env_path("OPENSCENE_DATA_ROOT")
    exp_root = env_path("NAVSIM_EXP_ROOT")
    project_root = env_path("WOTE_PROJECT_ROOT")

    print_header("Anchors (trajectory_anchors_256.npy)")
    anchors_path = openscene_root / "extra_data/planning_vb/trajectory_anchors_256.npy"
    print(f"anchors_path = {anchors_path}")
    if anchors_path.exists():
        try:
            anchors = np.load(str(anchors_path), allow_pickle=True)
            print(f"anchors shape = {getattr(anchors, 'shape', None)}; dtype = {getattr(anchors, 'dtype', None)}")
        except Exception as e:
            print(f"! Failed to read anchors: {e}")
    else:
        print("! Anchors file not found")

    print_header("Formatted PDM scores (formatted_pdm_score_256.npy)")
    formatted_path = openscene_root / "extra_data/planning_vb/formatted_pdm_score_256.npy"
    print(f"formatted_path = {formatted_path}")
    formatted_tokens: set[str] = set()
    if formatted_path.exists():
        formatted = safe_load_npy_dict(formatted_path)
        if isinstance(formatted, dict):
            formatted_tokens = set(k for k in formatted.keys() if isinstance(k, str))
            summarize_tokens("formatted_tokens", formatted_tokens)
        else:
            print("! formatted file exists but could not parse as dict")
    else:
        print("! formatted file not found")

    print_header("Metric cache metadata")
    cache_root = exp_root / "metric_cache"
    metadata_dir = cache_root / "metadata"
    print(f"cache_root = {cache_root}")
    print(f"metadata_dir = {metadata_dir}")

    cache_tokens: set[str] = set()
    if metadata_dir.exists() and metadata_dir.is_dir():
        csvs = sorted([p for p in metadata_dir.iterdir() if p.suffix == ".csv" or ".csv" in p.name])
        print(f"metadata csv files = {[str(p.name) for p in csvs]}")
        if csvs:
            # per loader code, it reads the first csv and skips header
            csv_path = csvs[0]
            try:
                lines = csv_path.read_text(encoding="utf-8", errors="ignore").splitlines()
                print(f"{csv_path.name}: total lines = {len(lines)}")
                payload = lines[1:] if len(lines) > 1 else []
                # Try to parse token from each path line
                for ln in payload[:50000]:  # cap to avoid huge memory if extremely large
                    if not ln:
                        continue
                    tok = extract_token_from_cache_path(ln)
                    if tok:
                        cache_tokens.add(tok)
                summarize_tokens("cache_tokens (unique)", cache_tokens)
            except Exception as e:
                print(f"! Failed to read metadata csv: {e}")
        else:
            print("! No metadata csv found in metadata dir")
    else:
        print("! metadata dir missing")

    print_header("Set relations (formatted vs cache)")
    if cache_tokens:
        only_cache = cache_tokens - formatted_tokens
        only_formatted = formatted_tokens - cache_tokens
        both = cache_tokens & formatted_tokens
        print(f"both count     = {len(both)}")
        print(f"only_cache     = {len(only_cache)}")
        print(f"only_formatted = {len(only_formatted)}")
        if only_cache:
            print(f"only_cache samples: {list(only_cache)[:PRINT_SAMPLES]}")
        if only_formatted:
            print(f"only_formatted samples: {list(only_formatted)[:PRINT_SAMPLES]}")
    else:
        print("cache_tokens empty; skip set relations")

    print_header("Summary")
    print("- Anchors: {}".format("OK" if anchors_path.exists() else "MISSING"))
    print("- Formatted scores: {} (tokens={})".format(
        "OK" if formatted_path.exists() else "MISSING", len(formatted_tokens)))
    print("- Metric cache: {} (metadata csv dir exists: {})".format(
        "OK" if cache_root.exists() else "MISSING", metadata_dir.exists()))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(1)