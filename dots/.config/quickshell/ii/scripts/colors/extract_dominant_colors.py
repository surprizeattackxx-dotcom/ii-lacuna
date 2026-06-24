#!/usr/bin/env python3
"""Extract dominant colors from an image using k-means clustering."""

import json, sys
import numpy as np

try:
    import cv2
except ImportError:
    print(json.dumps({"colors": [], "error": "cv2 not available"}), file=sys.stderr)
    print(json.dumps({"colors": [{"hex": "#1e1e2e", "pct": 50}, {"hex": "#cdd6f4", "pct": 30}, {"hex": "#89b4fa", "pct": 20}]}))
    sys.exit(0)

def rgb_to_hex(r, g, b):
    return f"#{int(r):02x}{int(g):02x}{int(b):02x}"

def extract_colors(img_path, n_colors=6, resize_dim=200):
    img = cv2.imread(img_path)
    if img is None:
        return []

    h, w = img.shape[:2]
    if max(h, w) > resize_dim:
        scale = resize_dim / max(h, w)
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    pixels = img_rgb.reshape(-1, 3).astype(np.float32)

    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 1.0)
    _, labels, centers = cv2.kmeans(pixels, n_colors, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS)

    counts = np.bincount(labels.flatten())
    total = counts.sum()
    centers = centers.astype(int)

    colors = []
    for i in range(n_colors):
        hex_color = rgb_to_hex(centers[i][0], centers[i][1], centers[i][2])
        pct = float(counts[i]) / total * 100
        colors.append({"hex": hex_color, "pct": round(pct, 1)})

    colors.sort(key=lambda c: c["pct"], reverse=True)
    return colors

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"colors": []}))
        sys.exit(0)

    n_colors = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    colors = extract_colors(sys.argv[1], n_colors)
    print(json.dumps({"colors": colors}))
