import os, json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from matplotlib.cm import get_cmap

import hydra
from hydra.utils import instantiate
import numpy as np
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.cluster import MiniBatchKMeans

from tqdm import tqdm
from navsim.common.dataloader import SceneLoader
from navsim.common.dataclasses import SceneFilter, SensorConfig

SPLIT = "trainval"  # ["mini", "test", "trainval"]
FILTER = "navtrain"  # ["navtrain", "navtest", "all_scenes", ]
num_poses = 8 # 0.5s * 8 = 4s
# 定义 K-means 的聚类数目
K = 256

# 设置数据路径
OPENSCENE_DATA_ROOT = Path(os.environ["OPENSCENE_DATA_ROOT"])
EXTRA_DATA_DIR = OPENSCENE_DATA_ROOT / "extra_data"
PLANNING_VB_DIR = EXTRA_DATA_DIR / "planning_vb"

# 确保目录存在
EXTRA_DATA_DIR.mkdir(exist_ok=True)
PLANNING_VB_DIR.mkdir(exist_ok=True)

"""
save navtrain future trajectories as numpy array
"""
# 定义文件路径
future_trajectories_file = EXTRA_DATA_DIR / f"future_trajectories_list_{SPLIT}_{FILTER}.npy"

# 检查是否已存在预处理的轨迹数据
if future_trajectories_file.exists():
    print(f"Loading existing future trajectories from {future_trajectories_file}")
    future_trajectories_list = np.load(str(future_trajectories_file))
else:
    print("Future trajectories file not found. Collecting from dataset...")
    print("This will take approximately 10 minutes...")
    
    # 初始化 hydra 配置
    hydra.initialize(config_path="../../navsim/planning/script/config/common/scene_filter")
    cfg = hydra.compose(config_name=FILTER)
    scene_filter: SceneFilter = instantiate(cfg)

    # 创建场景加载器
    scene_loader = SceneLoader(
            OPENSCENE_DATA_ROOT / f"navsim_logs/{SPLIT}",
            OPENSCENE_DATA_ROOT / f"sensor_blobs/{SPLIT}",
            scene_filter,
            sensor_config=SensorConfig.build_no_sensors(),
            # sensor_config=SensorConfig.build_all_sensors(),
    )

    future_trajectories_list = []  # 用于记录所有 future_trajectory

    print("Collecting future trajectories...")
    for token in tqdm(scene_loader.tokens):
            scene = scene_loader.get_scene_from_token(token)
            future_trajectory = scene.get_future_trajectory(
                            num_trajectory_frames=num_poses, 
                    ).poses
            future_trajectories_list.append(future_trajectory)

    # 保存到正确的路径
    print(f"Saving future trajectories to {future_trajectories_file}")
    np.save(str(future_trajectories_file), future_trajectories_list)
    print("Future trajectories saved!")

# 确保数据已加载
future_trajectories_list = np.array(future_trajectories_list)
print(f"Processing {len(future_trajectories_list)} trajectories for K-means clustering...")

np.set_printoptions(suppress=True)
# 将 future_trajectories_list 转换为 numpy 数组，并展平每条轨迹
N = len(future_trajectories_list)
future_trajectories_array = np.array(future_trajectories_list)  # (N, 8, 3)
flattened_trajectories = future_trajectories_array.reshape(N, -1).astype(np.float32)  # (N, 24)

print(f"Running K-means clustering with K={K}...")
# 使用 MiniBatchKMeans 进行聚类
kmeans = MiniBatchKMeans(n_clusters=K, random_state=0, batch_size=1000)
kmeans.fit(flattened_trajectories)

# 获取每条轨迹的聚类标签和聚类中心
labels = kmeans.labels_  # 每条轨迹对应的聚类标签
trajectory_anchors = kmeans.cluster_centers_  # 聚类中心，形状为 (K, 24)


# 将聚类中心转换回原始轨迹的形状 (8, 3)
trajectory_anchors = trajectory_anchors.reshape(K, 8, 3)

# save trajectory_anchors as numpy array
trajectory_anchors_file = PLANNING_VB_DIR / f"trajectory_anchors_{K}.npy"
print(f"Saving trajectory anchors to {trajectory_anchors_file}")
np.save(str(trajectory_anchors_file), trajectory_anchors)

""""
Visualization code
"""
print("Generating visualizations...")
# 重新加载数据进行可视化
trajectory_anchors = np.load(str(trajectory_anchors_file))

# Visualize all cluster centers on a single plot
fig, ax = plt.subplots(figsize=(15, 15))
cmap = get_cmap('hsv', K)  # Use colormap to distinguish between different trajectories

for i in range(K):
        trajectory = trajectory_anchors[i]
        ax.plot(trajectory[:, 0], trajectory[:, 1], marker='o', color=cmap(i), label=f'Cluster {i}', alpha=0.6, linewidth=1.5)

ax.set_title('All Cluster Centers')
ax.set_xlabel('X Position')
ax.set_ylabel('Y Position')
ax.grid(False)
plt.tight_layout()
vis_file_1 = PLANNING_VB_DIR / f"trajectory_anchors_{K}_no_grid.png"
print(f"Saving visualization to {vis_file_1}")
plt.savefig(str(vis_file_1))

# Generate highlighted visualization
print("Generating highlighted cluster visualization...")
# Data already loaded from trajectory_anchors_file

# Create a figure for plotting
fig, ax = plt.subplots(figsize=(15, 15))

highlight_idx = 57  # Choose the trajectory to highlight
cmap = get_cmap('hsv', K)  # Use colormap for distinguishing if needed

# Convert RGB (115, 137, 177) to a normalized value in [0, 1]
background_color = (115/255, 137/255, 177/255)

# Plot each trajectory
for i in range(K):
    trajectory = trajectory_anchors[i]
    if i == highlight_idx:
        ax.plot(trajectory[:, 0], trajectory[:, 1], marker='o', color='red', label=f'Highlighted Cluster {i}', alpha=0.9, linewidth=5)
    else:
        ax.plot(trajectory[:, 0], trajectory[:, 1], color=background_color, alpha=0.9, linewidth=5)

# Set plot properties
ax.set_title('Highlighted Cluster with Background Clusters')
ax.set_xlabel('X Position')
ax.set_ylabel('Y Position')
ax.legend(loc='upper right')
ax.grid(False)

# Adjust layout and save the figure
plt.tight_layout()
vis_file_2 = PLANNING_VB_DIR / f"trajectory_anchors_{K}_highlighted_{highlight_idx}.png"
plt.savefig(str(vis_file_2))
print(f"Saved highlighted figure to {vis_file_2}")

print("\n✅ K-means trajectory clustering completed successfully!")
print(f"📁 Generated files:")
print(f"   - Future trajectories: {future_trajectories_file}")
print(f"   - Trajectory anchors: {trajectory_anchors_file}")
print(f"   - Visualization 1: {vis_file_1}")
print(f"   - Visualization 2: {vis_file_2}")

