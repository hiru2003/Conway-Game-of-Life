#include <iostream>
#include <iomanip>
#include <fstream>
#include <vector>
#include "cpu_life.h"
#include "cuda_life.h"
#include <cuda_runtime.h>

void print_gpu_info() {
    int device_count = 0;
    cudaGetDeviceCount(&device_count);
    if (device_count == 0) {
        std::cerr << "No CUDA devices found!" << std::endl;
        return;
    }
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    std::cout << "========================================================\n";
    std::cout << " GPU Device: " << prop.name << "\n";
    std::cout << " Compute Capability: " << prop.major << "." << prop.minor << "\n";
    std::cout << " Global Memory: " << (prop.totalGlobalMem / (1024 * 1024)) << " MB\n";
    std::cout << " Multiprocessors (SMs): " << prop.multiProcessorCount << "\n";
    std::cout << " Max Threads Per Block: " << prop.maxThreadsPerBlock << "\n";
    std::cout << "========================================================\n\n";
}

int main(int argc, char** argv) {
    int iterations = 100;
    if (argc > 1) {
        iterations = std::atoi(argv[1]);
    }

    std::cout << "=== Conway's Game of Life HPC Benchmark (" << iterations << " Iterations) ===\n\n";
    print_gpu_info();

    std::vector<int> grid_sizes = {128, 256, 512, 1024, 2048, 4096};

    std::ofstream csv_file("results.csv");
    csv_file << "GridSize,TotalCells,CPU_Time_ms,CUDA_Global_ms,CUDA_Shared_ms,Speedup_Global,Speedup_Shared\n";

    std::cout << std::left 
              << std::setw(12) << "Grid Size"
              << std::setw(14) << "Total Cells"
              << std::setw(16) << "CPU Time (ms)"
              << std::setw(18) << "CUDA Global (ms)"
              << std::setw(18) << "CUDA Shared (ms)"
              << std::setw(16) << "Speedup (Glob)"
              << std::setw(16) << "Speedup (Shrd)"
              << "\n";
    std::cout << std::string(110, '-') << "\n";

    // Warm up CUDA driver & context
    {
        CUDALife warmup(64, 64);
        warmup.run_benchmark(10);
    }

    for (int size : grid_sizes) {
        CPULife cpu(size, size);
        cpu.randomize(0.30f, 1337);

        // Warm up & run CPU
        double cpu_time = cpu.run_benchmark(iterations);

        // CUDA Global
        CUDALife cuda_glob(size, size, false);
        cuda_glob.upload(cpu.grid.data());
        double cuda_glob_time = cuda_glob.run_benchmark(iterations);

        // CUDA Shared
        CUDALife cuda_shared(size, size, true);
        cuda_shared.upload(cpu.grid.data());
        double cuda_shared_time = cuda_shared.run_benchmark(iterations);

        double speedup_glob = cpu_time / cuda_glob_time;
        double speedup_shrd = cpu_time / cuda_shared_time;

        long long total_cells = static_cast<long long>(size) * size;

        std::cout << std::left 
                  << std::setw(12) << (std::to_string(size) + "x" + std::to_string(size))
                  << std::setw(14) << total_cells
                  << std::setw(16) << std::fixed << std::setprecision(2) << cpu_time
                  << std::setw(18) << std::fixed << std::setprecision(2) << cuda_glob_time
                  << std::setw(18) << std::fixed << std::setprecision(2) << cuda_shared_time
                  << std::setw(16) << std::fixed << std::setprecision(2) << (std::to_string(speedup_glob).substr(0, 5) + "x")
                  << std::setw(16) << std::fixed << std::setprecision(2) << (std::to_string(speedup_shrd).substr(0, 5) + "x")
                  << "\n";

        csv_file << size << "," << total_cells << "," 
                 << cpu_time << "," << cuda_glob_time << "," << cuda_shared_time << ","
                 << speedup_glob << "," << speedup_shrd << "\n";
    }

    csv_file.close();
    std::cout << std::string(110, '-') << "\n";
    std::cout << "\n[✓] Benchmark complete. Results saved to results.csv\n";
    
    // Automatically generate and overwrite plot image files
    std::cout << "[*] Generating updated high-resolution chart images...\n";
    int res = system("python3 plot_results.py");
    (void)res;
    return 0;
}
