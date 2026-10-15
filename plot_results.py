import os
import csv
import matplotlib.pyplot as plt

def generate_plots():
    csv_file = "results.csv"
    if not os.path.exists(csv_file):
        print(f"Error: {csv_file} not found!")
        return

    grid_sizes = []
    total_cells = []
    cpu_times = []
    cuda_glob_times = []
    cuda_shrd_times = []
    speedup_glob = []
    speedup_shrd = []

    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            grid_sizes.append(f"{row['GridSize']}x{row['GridSize']}")
            total_cells.append(int(row['TotalCells']))
            cpu_times.append(float(row['CPU_Time_ms']))
            cuda_glob_times.append(float(row['CUDA_Global_ms']))
            cuda_shrd_times.append(float(row['CUDA_Shared_ms']))
            speedup_glob.append(float(row['Speedup_Global']))
            speedup_shrd.append(float(row['Speedup_Shared']))

    plt.style.use('seaborn-v0_8-whitegrid' if 'seaborn-v0_8-whitegrid' in plt.style.available else 'default')

    # ==========================================
    # 1. Combined Dual-Panel Benchmark Figure
    # ==========================================
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6), dpi=300)

    # --- Panel 1: Execution Time (Log Scale) ---
    ax1.plot(grid_sizes, cpu_times, marker='o', linewidth=2.5, color='#E74C3C', label='CPU (Sequential 2D Array)')
    ax1.plot(grid_sizes, cuda_glob_times, marker='s', linewidth=2.5, color='#2ECC71', label='CUDA (Global Memory)')
    ax1.plot(grid_sizes, cuda_shrd_times, marker='^', linewidth=2.5, color='#3498DB', label='CUDA (Shared Memory)')
    ax1.set_yscale('log')
    ax1.set_title("Execution Time vs. Grid Size (100 Iterations)", fontsize=13, fontweight='bold', pad=12)
    ax1.set_xlabel("Grid Resolution ($N \\times N$)", fontsize=11, fontweight='bold')
    ax1.set_ylabel("Execution Time (milliseconds, Log Scale)", fontsize=11, fontweight='bold')
    ax1.legend(frameon=True, facecolor='#FFFFFF', edgecolor='#CCCCCC', fontsize=10)
    ax1.grid(True, linestyle='--', alpha=0.6)

    # --- Panel 2: Speedup Factor ---
    x = range(len(grid_sizes))
    width = 0.35
    rects1 = ax2.bar([i - width/2 for i in x], speedup_glob, width, label='CUDA Global Speedup', color='#2ECC71', edgecolor='#27AE60')
    rects2 = ax2.bar([i + width/2 for i in x], speedup_shrd, width, label='CUDA Shared Speedup', color='#3498DB', edgecolor='#2980B9')

    ax2.set_title("GPU Speedup Factor vs. CPU ($T_{CPU} / T_{CUDA}$)", fontsize=13, fontweight='bold', pad=12)
    ax2.set_xlabel("Grid Resolution ($N \\times N$)", fontsize=11, fontweight='bold')
    ax2.set_ylabel("Speedup Multiplier (X times faster)", fontsize=11, fontweight='bold')
    ax2.set_xticks(list(x))
    ax2.set_xticklabels(grid_sizes)
    ax2.legend(frameon=True, facecolor='#FFFFFF', edgecolor='#CCCCCC', fontsize=10)
    ax2.grid(True, linestyle='--', alpha=0.6, axis='y')

    # Add data labels on top of bars
    for rect in rects1:
        h = rect.get_height()
        ax2.annotate(f'{h:.1f}x',
                     xy=(rect.get_x() + rect.get_width() / 2, h),
                     xytext=(0, 3), textcoords="offset points",
                     ha='center', va='bottom', fontsize=8.5, fontweight='bold', color='#1E8449')

    plt.tight_layout()
    output_combined = "hpc_benchmark_summary.png"
    plt.savefig(output_combined, dpi=300, bbox_inches='tight')
    plt.close()

    # ==========================================
    # 2. Individual Plot 1: Execution Time
    # ==========================================
    plt.figure(figsize=(8, 5.5), dpi=300)
    plt.plot(grid_sizes, cpu_times, marker='o', linewidth=2.5, color='#E74C3C', label='CPU (Sequential 2D Array)')
    plt.plot(grid_sizes, cuda_glob_times, marker='s', linewidth=2.5, color='#2ECC71', label='CUDA (Global Memory GPU)')
    plt.plot(grid_sizes, cuda_shrd_times, marker='^', linewidth=2.5, color='#3498DB', label='CUDA (Shared Memory GPU)')
    plt.yscale('log')
    plt.title("Conway's Game of Life: Execution Time (100 Steps)", fontsize=12, fontweight='bold')
    plt.xlabel("Grid Resolution", fontsize=10, fontweight='bold')
    plt.ylabel("Time in Milliseconds (Log Scale)", fontsize=10, fontweight='bold')
    plt.legend(frameon=True, fontsize=10)
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.tight_layout()
    plt.savefig("plot_execution_time.png", dpi=300, bbox_inches='tight')
    plt.close()

    # ==========================================
    # 3. Individual Plot 2: Speedup
    # ==========================================
    plt.figure(figsize=(8, 5.5), dpi=300)
    bars = plt.bar(grid_sizes, speedup_glob, color='#2ECC71', edgecolor='#27AE60', width=0.55)
    plt.title("GPU Speedup over Sequential CPU (100 Steps)", fontsize=12, fontweight='bold')
    plt.xlabel("Grid Resolution", fontsize=10, fontweight='bold')
    plt.ylabel("Speedup (Times Faster)", fontsize=10, fontweight='bold')
    plt.grid(True, linestyle='--', alpha=0.6, axis='y')
    for bar in bars:
        h = bar.get_height()
        plt.annotate(f'{h:.1f}x',
                     xy=(bar.get_x() + bar.get_width() / 2, h),
                     xytext=(0, 4), textcoords="offset points",
                     ha='center', va='bottom', fontsize=9.5, fontweight='bold')
    plt.tight_layout()
    plt.savefig("plot_speedup.png", dpi=300, bbox_inches='tight')
    plt.close()

    print("[✓] Automatically generated and updated plot images:")
    print("    - hpc_benchmark_summary.png (Dual-panel summary for report)")
    print("    - plot_execution_time.png   (Execution time comparison)")
    print("    - plot_speedup.png          (Speedup factor chart)")

if __name__ == "__main__":
    generate_plots()
