NVCC = nvcc
CXX = g++
NVCCFLAGS = -O3 -std=c++17 -Xcompiler -Wall,-Wextra,-fopenmp
CXXFLAGS = -O3 -std=c++17 -Wall -Wextra -fopenmp
LDFLAGS = -lX11 -lGL -lGLX -lpthread

OBJ_DIR = build
SRC_DIR = src

SRCS_COMMON = $(SRC_DIR)/cpu_life.cpp $(SRC_DIR)/cuda_life.cu
OBJS_COMMON = $(OBJ_DIR)/cpu_life.o $(OBJ_DIR)/cuda_life.o

TARGET_BENCH = conway_benchmark
TARGET_GUI = conway_gui

all: $(TARGET_BENCH) $(TARGET_GUI)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

$(OBJ_DIR)/cpu_life.o: $(SRC_DIR)/cpu_life.cpp $(SRC_DIR)/cpu_life.h | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/cuda_life.o: $(SRC_DIR)/cuda_life.cu $(SRC_DIR)/cuda_life.h | $(OBJ_DIR)
	$(NVCC) $(NVCCFLAGS) -c $< -o $@

$(TARGET_BENCH): $(OBJS_COMMON) $(SRC_DIR)/benchmark.cu
	$(NVCC) $(NVCCFLAGS) $^ -o $@

$(TARGET_GUI): $(OBJS_COMMON) $(SRC_DIR)/gui_main.cu
	$(NVCC) $(NVCCFLAGS) $^ -o $@ $(LDFLAGS)

clean:
	rm -rf $(OBJ_DIR) $(TARGET_BENCH) $(TARGET_GUI) results.csv

.PHONY: all clean
