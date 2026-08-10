import sys

import matplotlib.colors as mcolors
import matplotlib.pyplot as plt
import numpy as np
from scipy.integrate import odeint


def aizawa(state, t):
    x, y, z = state
    a, b, c, d, e, f = 0.95, 0.7, 0.6, 3.5, 0.25, 0.1
    dx = (z - b) * x - d * y
    dy = d * x + (z - b) * y
    dz = c + a * z - (z ** 3 / 3) - (x ** 2 + y ** 2) * (1 + e * z) + f * z * x ** 3
    return [dx, dy, dz]

dt = 0.002  
t = np.arange(0, 300, dt)
initial_state = [0.1, 0.0, 0.0]
states = odeint(aizawa, initial_state, t)

x, z = states[:, 0], states[:, 2] 

# Setup (3:2 Landscape)
plt.style.use('dark_background')
fig, ax = plt.subplots(figsize=(15, 10))
fig.patch.set_facecolor('black')
ax.set_facecolor('black')


colors = (z - z.min()) / (z.max() - z.min())
cmap_style = 'hsv' 

ax.scatter(x, z, c=colors, cmap=cmap_style, s=25, alpha=0.02, linewidth=0)

ax.scatter(x, z, c=colors, cmap=cmap_style, s=0.5, alpha=0.6, linewidth=0)

ax.set_xlim(-2.5, 2.5)
ax.set_ylim(-1.0, 2.3)
ax.set_aspect('equal')
ax.axis('off')

plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
plt.savefig("aizawa_attractor.png", dpi=150, facecolor='black')

def chen(state, t):
    x, y, z = state
    a, b, c = 40, 3, 28
    return [a * (y - x), (c - a) * x - x * z + c * y, x * y - b * z]

def dequan_li(state, t):
    x, y, z = state
    a, c, d, e, k, f = 40, 1.833, 0.16, 0.65, 55, 20
    dx = a * (y - x) + d * x * z
    dy = k * x + f * y - x * z
    dz = c * z + x * y - e * x**2
    return [dx, dy, dz]

def newton_leipnik(state, t):
    x, y, z = state
    a, b = 0.4, 0.175
    return [
        -a * x + y + 10 * y * z,
        -x - 0.4 * y + 5 * x * z,
        b * z - 5 * x * y
    ]

def arneodo(state, t):
    x, y, z = state
    a, b, c, d = -5.5, 3.5, -1.0, -1.0 
    return [y, z, -a * x - b * y - z + c * x ** 3]

def bouali(state, t):
    x, y, z = state
    a, b, c, s = 0.3, 1.0, 1.0, 1.0
    return [
        x * (4 - y) + a * z,
        -y * (1 - x ** 2),
        -x * (1.5 - z) - s * z
    ]

p_ocean = mcolors.LinearSegmentedColormap.from_list("ocean", ["#000033", "#00ffff"])
p_magma = mcolors.LinearSegmentedColormap.from_list("magma", ["#c24747", "#ffcc00"])
p_vapor = mcolors.LinearSegmentedColormap.from_list("vapor", ["#240046", "#ff00ff"])
p_krypto = mcolors.LinearSegmentedColormap.from_list("krypto", ["#003300", "#39ff14"])
p_royal = mcolors.LinearSegmentedColormap.from_list("royal", ["#b8860b", "#ffffff"])

configs = [
    {
        "name": "01_Chen_Ocean", "func": chen, "init": [-10, -4, 20],
        "t_max": 100, "dt": 0.005,
        "proj": (0, 2), "cmap": p_ocean, "bg": "#050510"
    },
    {
        "name": "02_DequanLi_Magma", "func": dequan_li, "init": [0.1, 0.1, 0.1],
        "t_max": 100, "dt": 0.002, 
        "proj": (0, 2), "cmap": p_magma, "bg": "#100505" 
    },
    {
        "name": "03_NewtonLeipnik_Vapor", "func": newton_leipnik, "init": [0.349, 0, -0.160],
        "t_max": 400, "dt": 0.01,
        "proj": (0, 2), "cmap": p_vapor, "bg": "#100510"
    },
    {
        "name": "04_Arneodo_Krypto", "func": arneodo, "init": [0.1, 0, 0],
        "t_max": 600, "dt": 0.01,
        "proj": (0, 1), "cmap": p_krypto, "bg": "#051005",
        "rotate": True # ADDED FLAG
    },
    {
        "name": "05_Bouali_Royal", "func": bouali, "init": [1, 0.1, 0.1],
        "t_max": 300, "dt": 0.01,
        "proj": (0, 1), "cmap": p_royal, "bg": "#151515"
    }
]

plt.style.use('dark_background')

for cfg in configs:
    print(f"Rendering {cfg['name']}...")
    
    t = np.arange(0, cfg["t_max"], cfg["dt"])
    states = odeint(cfg["func"], cfg["init"], t)
    
    states = states[1000:]
    
    x = states[:, cfg["proj"][0]]
    y = states[:, cfg["proj"][1]]
    

    if cfg.get("rotate", False):
        x_rot = -y
        y_rot = x
        x, y = x_rot, y_rot
    
    axes = [0, 1, 2]
    [axes.remove(p) for p in cfg["proj"]]
    z_depth = states[:, axes[0]]
    colors = (z_depth - z_depth.min()) / (z_depth.max() - z_depth.min())

    fig, ax = plt.subplots(figsize=(15, 10))
    fig.patch.set_facecolor(cfg["bg"])
    ax.set_facecolor(cfg["bg"])

    ax.scatter(x, y, c=colors, cmap=cfg["cmap"], s=60, alpha=0.05, linewidth=0)
    ax.scatter(x, y, c=colors, cmap=cfg["cmap"], s=0.6, alpha=0.8, linewidth=0)

    # Smart Zoom
    x_min, x_max = np.percentile(x, 1), np.percentile(x, 99)
    y_min, y_max = np.percentile(y, 1), np.percentile(y, 99)
    
    margin_x = (x_max - x_min) * 0.05
    margin_y = (y_max - y_min) * 0.05
    
    ax.set_xlim(x_min - margin_x, x_max + margin_x)
    ax.set_ylim(y_min - margin_y, y_max + margin_y)
    
    ax.set_aspect('equal')
    ax.axis('off')
    
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    plt.savefig(f"{cfg['name']}.png", dpi=150, facecolor=cfg['bg'])
    plt.close()