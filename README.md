# Conway's Game of Life - High-Performance Computing (HPC)

An interactive, high-performance implementation of **Conway's Game of Life** comparing **CPU (Sequential 2D Array)** vs. **CUDA (Parallel GPU Acceleration)** with an integrated dashboard and automated benchmarking suite.

---

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
   - Computes speedups and outputs a clean CSV summary (`benchmark_results.csv`).

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

---

## 📊 Benchmark Results (100 Iterations on NVIDIA GeForce MX350)

| Grid Size | Total Cells | CPU Time (ms) | CUDA Global (ms) | CUDA Shared (ms) | Speedup (Global) | Speedup (Shared) |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **128 × 128** | 16,384 | 18.18 ms | **0.46 ms** | 0.51 ms | **39.44x** | 35.64x |
| **256 × 256** | 65,536 | 76.96 ms | **0.78 ms** | 1.39 ms | **98.12x** | 55.42x |
| **512 × 512** | 262,144 | 285.02 ms | **2.67 ms** | 5.09 ms | **106.8x** | 55.98x |
| **1024 × 1024** | 1,048,576 | 1,064.50 ms | **10.99 ms** | 22.46 ms | **96.88x** | 47.40x |
| **2048 × 2048** | 4,194,304 | 4,682.91 ms | **42.44 ms** | 88.93 ms | **110.3x** | 52.65x |
| **4096 × 4096** | 16,777,216 | 18,402.78 ms | **192.53 ms** | 373.67 ms | **95.58x** | 49.24x |

---

## ⚡ What Makes It High Performance?

1. **Zero Intermediate Memory Transfers (Ping-Pong Buffering):**
   - The entire 100 iterations execute directly on device VRAM using double buffering (`d_grid` and `d_next_grid`). No per-generation Host-to-Device or Device-to-Host transfer overhead occurs during computation.
2. **Coalesced Global Memory Access:**
   - 2D thread blocks ($16 \times 16$) map consecutive thread indices (`threadIdx.x`) directly to adjacent memory addresses in row-major layout, achieving maximum memory bandwidth saturation.
3. **Compact 8-Bit Data Types (`uint8_t`):**
   - Using 1 byte per cell instead of standard 4-byte integers yields a **$4\times$ reduction in required memory bandwidth** and improves L1/L2 cache hit rates.
4. **Row Offset Precomputation (CPU):**
   - Eliminates redundant multiplication in inner loops for boundary wrapping and indexing.