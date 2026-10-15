#ifndef CPU_LIFE_H
#define CPU_LIFE_H

#include <vector>
#include <cstdint>
#include <chrono>

class CPULife {
public:
    int width;
    int height;
    std::vector<uint8_t> grid;
    std::vector<uint8_t> next_grid;

    CPULife(int w, int h);

    // Initialize with random density (e.g. 0.2 = 20% alive)
    void randomize(float density = 0.25f, unsigned int seed = 42);

    // Clear all cells
    void clear();

    // Set individual cell
    void set_cell(int x, int y, uint8_t state);
    uint8_t get_cell(int x, int y) const;

    // Advance 1 generation
    void step();

    // Run N generations and measure execution time in milliseconds
    double run_benchmark(int iterations);
};

#endif // CPU_LIFE_H
