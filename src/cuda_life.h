#ifndef CUDA_LIFE_H
#define CUDA_LIFE_H

#include <cstdint>
#include <vector>

class CUDALife {
public:
    int width;
    int height;
    uint8_t* d_grid;
    uint8_t* d_next_grid;
    bool use_shared_mem;

    CUDALife(int w, int h, bool use_shared = false);
    ~CUDALife();

    // Upload data from host CPU to GPU device memory
    void upload(const uint8_t* host_data);

    // Download data from GPU device memory to host CPU
    void download(uint8_t* host_data);

    // Perform 1 generation step on GPU
    void step();

    // Run N generations on GPU and measure execution time in milliseconds (excluding H2D/D2H)
    double run_benchmark(int iterations);

    // Reallocate for new dimensions
    void resize(int new_w, int new_h);
};

#endif // CUDA_LIFE_H
