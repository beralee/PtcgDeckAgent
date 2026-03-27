#!/usr/bin/env python3
"""
PTCG Train 价值网络训练脚本。
加载 Godot 导出的 JSON 自博弈数据，训练 MLP 价值网络，导出权重为 GDScript 可读的 JSON。

用法:
    python scripts/training/train_value_net.py \
        --data-dir "path/to/training_data" \
        --output "value_net_weights.json" \
        --epochs 100 --batch-size 256 --lr 0.001 \
        --hidden1 64 --hidden2 32
"""

import argparse
import glob
import json
import os
import sys

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset


class ValueNet(nn.Module):
    def __init__(self, input_dim: int = 30, hidden1: int = 64, hidden2: int = 32):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden1),
            nn.ReLU(),
            nn.Linear(hidden1, hidden2),
            nn.ReLU(),
            nn.Linear(hidden2, 1),
            nn.Sigmoid(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x).squeeze(-1)


def load_data(data_dir: str) -> tuple[np.ndarray, np.ndarray]:
    """加载所有 game_*.json 文件，提取 (features, result) 对。"""
    pattern = os.path.join(data_dir, "game_*.json")
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"[错误] 未找到训练数据文件: {pattern}")
        sys.exit(1)

    all_features = []
    all_results = []
    for fpath in files:
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)
        for record in data.get("records", []):
            features = record.get("features", [])
            result = record.get("result", 0.5)
            if len(features) > 0:
                all_features.append(features)
                all_results.append(result)

    print(f"[数据] 加载 {len(files)} 个文件, {len(all_features)} 条记录")
    return np.array(all_features, dtype=np.float32), np.array(all_results, dtype=np.float32)


def export_weights(model: ValueNet, output_path: str, input_dim: int) -> None:
    """将 PyTorch 模型权重导出为 GDScript 可读的 JSON 格式。"""
    layers = []
    activation_map = {
        "ReLU": "relu",
        "Sigmoid": "sigmoid",
    }

    i = 0
    modules = list(model.net.children())
    while i < len(modules):
        module = modules[i]
        if isinstance(module, nn.Linear):
            activation = "relu"
            if i + 1 < len(modules):
                next_mod = modules[i + 1]
                act_name = type(next_mod).__name__
                activation = activation_map.get(act_name, "relu")
            layer = {
                "out_features": module.out_features,
                "activation": activation,
                "weights": module.weight.detach().cpu().numpy().tolist(),
                "bias": module.bias.detach().cpu().numpy().tolist(),
            }
            layers.append(layer)
        i += 1

    data = {
        "architecture": "mlp",
        "input_dim": input_dim,
        "layers": layers,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"[导出] 权重已保存到 {output_path}")


def main():
    parser = argparse.ArgumentParser(description="PTCG Train 价值网络训练")
    parser.add_argument("--data-dir", required=True, help="训练数据目录")
    parser.add_argument("--output", default="value_net_weights.json", help="输出权重文件路径")
    parser.add_argument("--epochs", type=int, default=100, help="训练轮数")
    parser.add_argument("--batch-size", type=int, default=256, help="批次大小")
    parser.add_argument("--lr", type=float, default=0.001, help="学习率")
    parser.add_argument("--hidden1", type=int, default=64, help="第一隐藏层大小")
    parser.add_argument("--hidden2", type=int, default=32, help="第二隐藏层大小")
    args = parser.parse_args()

    features, results = load_data(args.data_dir)
    input_dim = features.shape[1]

    # 80/20 划分
    n = len(features)
    indices = np.random.permutation(n)
    split = int(n * 0.8)
    train_idx, val_idx = indices[:split], indices[split:]

    train_x = torch.from_numpy(features[train_idx])
    train_y = torch.from_numpy(results[train_idx])
    val_x = torch.from_numpy(features[val_idx])
    val_y = torch.from_numpy(results[val_idx])

    train_loader = DataLoader(
        TensorDataset(train_x, train_y),
        batch_size=args.batch_size,
        shuffle=True,
    )

    model = ValueNet(input_dim, args.hidden1, args.hidden2)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    criterion = nn.BCELoss()

    print(f"[训练] input_dim={input_dim}, hidden1={args.hidden1}, hidden2={args.hidden2}")
    print(f"[训练] 训练集={len(train_idx)}, 验证集={len(val_idx)}, epochs={args.epochs}")

    for epoch in range(args.epochs):
        model.train()
        train_loss = 0.0
        train_count = 0
        for batch_x, batch_y in train_loader:
            optimizer.zero_grad()
            pred = model(batch_x)
            loss = criterion(pred, batch_y)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * len(batch_x)
            train_count += len(batch_x)

        if (epoch + 1) % 10 == 0 or epoch == 0:
            model.eval()
            with torch.no_grad():
                val_pred = model(val_x)
                val_loss = criterion(val_pred, val_y).item()
            print(f"  Epoch {epoch+1:3d}: train_loss={train_loss/train_count:.4f}, val_loss={val_loss:.4f}")

    export_weights(model, args.output, input_dim)
    print("[完成]")


if __name__ == "__main__":
    main()
