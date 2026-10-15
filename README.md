

## 🚀 Key Features & Architecture

1. **Dual Compute Backends:**
   - **CPU Baseline:** Cache-friendly 1D flattened row-major representation with toroidal boundary wrapping and pointer swapping.
   - **CUDA Acceleration:** 2D grid/block thread decomposition ($16\times16$ threads per block) with memory coalescing and GPU VRAM double-buffering.
   - **Shared Memory Tiling Kernel:** $18\times18$ tile-based shared memory implementation with halo boundaries.
2. **Interactive Native GUI + Dashboard (`conway_gui`):**
   - **Simulation Canvas (Left):** Real-time OpenGL rendering with mouse click/drag drawing and preset pattern injection (e.g. Gosper Glider Gun).
   - **HUD Control Dashboard (Right):** Mode switcher (CPU vs CUDA), Kernel Selector (Global vs Shared), Resolution selector ($128\times128$ to $2048\times2048$), Play/Pause, Step, and Live 100-Iteration Benchmarking.
3. **Automated CLI Benchmark Suite (`conway_benchmark`):**
   - Profiles 100 iterations across scaling grid dimensions ($128\times128$ to $4096\times4096$).
   - Computes speedups and outputs a clean CSV summary (`results.csv`).

---

## 🛠️ Compilation

To compile both the benchmark suite and the interactive dashboard:

```bash
make clean
make -j$(nproc)
```

This generates two executable binaries:
- `conway_gui`: The interactive graphical application with side-by-side dashboard.
- `conway_benchmark`: Automated HPC benchmarking tool.

---

## 🎮 How to Run

### 1. Interactive GUI with Dashboard
```bash
./conway_gui
```
- **Controls & Hotkeys:**
  - `Space`: Play / Pause simulation.
  - `Q` or `Esc`: Exit application.
  - **Left Mouse Click / Drag on Grid:** Draw live cells directly onto the board.
  - **Buttons:**
    - Switch between **CPU** and **CUDA** on the fly.
    - Toggle between **CUDA Global** and **CUDA Shared Memory**.
    - Change grid size ($128, 256, 512, 1024, 2048$).
    - Click **`> RUN 100 ITER BENCHMARK <`** to measure exact CPU vs. CUDA speedup for the current board state.

---

### 2. Running the 100-Iteration CLI Benchmark
```bash
./conway_benchmark 100
```

