#include "cpu_life.h"
#include <cstdlib>
#include <cstring>
#include <random>

CPULife::CPULife(int w, int h) : width(w), height(h), grid(w * h, 0), next_grid(w * h, 0) {}

void CPULife::randomize(float density, unsigned int seed) {
    std::mt19937 gen(seed);
    std::uniform_real_distribution<float> dis(0.0f, 1.0f);
    for (int i = 0; i < width * height; ++i) {
        grid[i] = (dis(gen) < density) ? 1 : 0;
    }
}

void CPULife::clear() {
    std::fill(grid.begin(), grid.end(), 0);
    std::fill(next_grid.begin(), next_grid.end(), 0);
}

void CPULife::set_cell(int x, int y, uint8_t state) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
        grid[y * width + x] = state;
    }
}

uint8_t CPULife::get_cell(int x, int y) const {
    if (x >= 0 && x < width && y >= 0 && y < height) {
        return grid[y * width + x];
    }
    return 0;
}

void CPULife::step() {
    const int w = width;
    const int h = height;
    const uint8_t* __restrict__ src = grid.data();
    uint8_t* __restrict__ dst = next_grid.data();

    for (int y = 0; y < h; ++y) {
        int y_up   = (y == 0) ? (h - 1) * w : (y - 1) * w;
        int y_curr = y * w;
        int y_down = (y == h - 1) ? 0 : (y + 1) * w;

        for (int x = 0; x < w; ++x) {
            int x_left  = (x == 0) ? (w - 1) : (x - 1);
            int x_right = (x == w - 1) ? 0 : (x + 1);

            int neighbors = 
                src[y_up   + x_left] + src[y_up   + x] + src[y_up   + x_right] +
                src[y_curr + x_left]                   + src[y_curr + x_right] +
                src[y_down + x_left] + src[y_down + x] + src[y_down + x_right];

            uint8_t current = src[y_curr + x];
            dst[y_curr + x] = (neighbors == 3) || (neighbors == 2 && current == 1) ? 1 : 0;
        }
    }

    grid.swap(next_grid);
}

double CPULife::run_benchmark(int iterations) {
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        step();
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> duration = end - start;
    return duration.count();
}
