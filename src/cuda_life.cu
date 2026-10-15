#include "cuda_life.h"
#include <cuda_runtime.h>
#include <iostream>
#include <stdexcept>
#include <algorithm>

#define BLOCK_DIM_X 16
#define BLOCK_DIM_Y 16

// Standard Coalesced Global Memory Kernel
__global__ void life_kernel_global(const uint8_t* __restrict__ src, uint8_t* __restrict__ dst, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    int x_left  = (x == 0) ? (width - 1) : (x - 1);
    int x_right = (x == width - 1) ? 0 : (x + 1);
    int y_up    = (y == 0) ? (height - 1) : (y - 1);
    int y_down  = (y == height - 1) ? 0 : (y + 1);

    int row_up   = y_up * width;
    int row_curr = y * width;
    int row_down = y_down * width;

    int neighbors = 
        src[row_up   + x_left] + src[row_up   + x] + src[row_up   + x_right] +
        src[row_curr + x_left]                     + src[row_curr + x_right] +
        src[row_down + x_left] + src[row_down + x] + src[row_down + x_right];

    uint8_t current = src[row_curr + x];
    dst[row_curr + x] = (neighbors == 3) || (neighbors == 2 && current == 1) ? 1 : 0;
}

// Optimized Shared Memory Tiled Kernel (Tile size 16x16 with 1-pixel halo = 18x18)
__global__ void life_kernel_shared(const uint8_t* __restrict__ src, uint8_t* __restrict__ dst, int width, int height) {
    __shared__ uint8_t tile[BLOCK_DIM_Y + 2][BLOCK_DIM_X + 2];

    int tx = threadIdx.x;
    int ty = threadIdx.y;
    int gx = blockIdx.x * blockDim.x + tx;
    int gy = blockIdx.y * blockDim.y + ty;

    int sm_x = tx + 1;
    int sm_y = ty + 1;

    // Load center
    if (gx < width && gy < height) {
        tile[sm_y][sm_x] = src[gy * width + gx];
    } else {
        tile[sm_y][sm_x] = 0;
    }

    // Load halo left & right
    if (tx == 0) {
        int left_gx = (gx == 0) ? (width - 1) : (gx - 1);
        tile[sm_y][0] = (gy < height) ? src[gy * width + left_gx] : 0;
    }
    if (tx == blockDim.x - 1 || gx == width - 1) {
        int right_gx = (gx == width - 1) ? 0 : (gx + 1);
        tile[sm_y][sm_x + 1] = (gy < height) ? src[gy * width + right_gx] : 0;
    }

    // Load halo top & bottom
    if (ty == 0) {
        int up_gy = (gy == 0) ? (height - 1) : (gy - 1);
        tile[0][sm_x] = (gx < width) ? src[up_gy * width + gx] : 0;
    }
    if (ty == blockDim.y - 1 || gy == height - 1) {
        int down_gy = (gy == height - 1) ? 0 : (gy + 1);
        tile[sm_y + 1][sm_x] = (gx < width) ? src[down_gy * width + gx] : 0;
    }

    // Load 4 corners
    if (tx == 0 && ty == 0) {
        int left_gx = (gx == 0) ? (width - 1) : (gx - 1);
        int up_gy   = (gy == 0) ? (height - 1) : (gy - 1);
        tile[0][0]  = src[up_gy * width + left_gx];
    }
    if (tx == blockDim.x - 1 && ty == 0) {
        int right_gx = (gx == width - 1) ? 0 : (gx + 1);
        int up_gy    = (gy == 0) ? (height - 1) : (gy - 1);
        tile[0][sm_x + 1] = src[up_gy * width + right_gx];
    }
    if (tx == 0 && ty == blockDim.y - 1) {
        int left_gx = (gx == 0) ? (width - 1) : (gx - 1);
        int down_gy = (gy == height - 1) ? 0 : (gy + 1);
        tile[sm_y + 1][0] = src[down_gy * width + left_gx];
    }
    if (tx == blockDim.x - 1 && ty == blockDim.y - 1) {
        int right_gx = (gx == width - 1) ? 0 : (gx + 1);
        int down_gy  = (gy == height - 1) ? 0 : (gy + 1);
        tile[sm_y + 1][sm_x + 1] = src[down_gy * width + right_gx];
    }

    __syncthreads();

    if (gx < width && gy < height) {
        int neighbors =
            tile[sm_y - 1][sm_x - 1] + tile[sm_y - 1][sm_x] + tile[sm_y - 1][sm_x + 1] +
            tile[sm_y    ][sm_x - 1]                         + tile[sm_y    ][sm_x + 1] +
            tile[sm_y + 1][sm_x - 1] + tile[sm_y + 1][sm_x] + tile[sm_y + 1][sm_x + 1];

        uint8_t current = tile[sm_y][sm_x];
        dst[gy * width + gx] = (neighbors == 3) || (neighbors == 2 && current == 1) ? 1 : 0;
    }
}

CUDALife::CUDALife(int w, int h, bool use_shared)
    : width(w), height(h), d_grid(nullptr), d_next_grid(nullptr), use_shared_mem(use_shared) {
    size_t size = static_cast<size_t>(width) * height * sizeof(uint8_t);
    cudaMalloc(&d_grid, size);
    cudaMalloc(&d_next_grid, size);
    cudaMemset(d_grid, 0, size);
    cudaMemset(d_next_grid, 0, size);
}

CUDALife::~CUDALife() {
    if (d_grid) cudaFree(d_grid);
    if (d_next_grid) cudaFree(d_next_grid);
}

void CUDALife::upload(const uint8_t* host_data) {
    size_t size = static_cast<size_t>(width) * height * sizeof(uint8_t);
    cudaMemcpy(d_grid, host_data, size, cudaMemcpyHostToDevice);
}

void CUDALife::download(uint8_t* host_data) {
    size_t size = static_cast<size_t>(width) * height * sizeof(uint8_t);
    cudaMemcpy(host_data, d_grid, size, cudaMemcpyDeviceToHost);
}

void CUDALife::step() {
    dim3 block(BLOCK_DIM_X, BLOCK_DIM_Y);
    dim3 grid((width + BLOCK_DIM_X - 1) / BLOCK_DIM_X, (height + BLOCK_DIM_Y - 1) / BLOCK_DIM_Y);

    if (use_shared_mem) {
        life_kernel_shared<<<grid, block>>>(d_grid, d_next_grid, width, height);
    } else {
        life_kernel_global<<<grid, block>>>(d_grid, d_next_grid, width, height);
    }

    std::swap(d_grid, d_next_grid);
}

double CUDALife::run_benchmark(int iterations) {
    dim3 block(BLOCK_DIM_X, BLOCK_DIM_Y);
    dim3 grid((width + BLOCK_DIM_X - 1) / BLOCK_DIM_X, (height + BLOCK_DIM_Y - 1) / BLOCK_DIM_Y);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);

    for (int i = 0; i < iterations; ++i) {
        if (use_shared_mem) {
            life_kernel_shared<<<grid, block>>>(d_grid, d_next_grid, width, height);
        } else {
            life_kernel_global<<<grid, block>>>(d_grid, d_next_grid, width, height);
        }
        std::swap(d_grid, d_next_grid);
    }

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    return static_cast<double>(milliseconds);
}

void CUDALife::resize(int new_w, int new_h) {
    if (new_w == width && new_h == height) return;
    if (d_grid) cudaFree(d_grid);
    if (d_next_grid) cudaFree(d_next_grid);

    width = new_w;
    height = new_h;
    size_t size = static_cast<size_t>(width) * height * sizeof(uint8_t);
    cudaMalloc(&d_grid, size);
    cudaMalloc(&d_next_grid, size);
    cudaMemset(d_grid, 0, size);
    cudaMemset(d_next_grid, 0, size);
}
