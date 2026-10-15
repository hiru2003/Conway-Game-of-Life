#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <GL/gl.h>
#include <GL/glx.h>
#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <cmath>
#include <cctype>
#include <iomanip>
#include <sstream>
#include <thread>
#include "cpu_life.h"
#include "cuda_life.h"

// Window Dimensions
const int WIN_WIDTH = 1260;
const int WIN_HEIGHT = 740;
const int GRID_VIEW_SIZE = 740;
const int DASH_X = GRID_VIEW_SIZE + 15;
const int DASH_W = WIN_WIDTH - GRID_VIEW_SIZE - 30;

// Crisp 8x13 font bitmap definitions for terminal/HUD clarity
void get_glyph(char c, uint16_t out[13]) {
    for (int i = 0; i < 13; ++i) out[i] = 0;
    c = toupper(c);

    switch (c) {
        case ' ': break;
        case '!': out[2]=0x18; out[3]=0x18; out[4]=0x18; out[5]=0x18; out[6]=0x18; out[7]=0x18; out[9]=0x18; out[10]=0x18; break;
        case '\'': out[2]=0x18; out[3]=0x18; out[4]=0x08; break;
        case '(': out[2]=0x06; out[3]=0x0C; out[4]=0x18; out[5]=0x18; out[6]=0x18; out[7]=0x18; out[8]=0x18; out[9]=0x0C; out[10]=0x06; break;
        case ')': out[2]=0x60; out[3]=0x30; out[4]=0x18; out[5]=0x18; out[6]=0x18; out[7]=0x18; out[8]=0x18; out[9]=0x30; out[10]=0x60; break;
        case '+': out[3]=0x18; out[4]=0x18; out[5]=0x7E; out[6]=0x7E; out[7]=0x18; out[8]=0x18; break;
        case ',': out[8]=0x18; out[9]=0x18; out[10]=0x08; out[11]=0x10; break;
        case '-': out[5]=0x7E; out[6]=0x7E; break;
        case '.': out[8]=0x18; out[9]=0x18; break;
        case '/': out[2]=0x03; out[3]=0x06; out[4]=0x0C; out[5]=0x18; out[6]=0x30; out[7]=0x60; out[8]=0xC0; break;
        case ':': out[3]=0x18; out[4]=0x18; out[7]=0x18; out[8]=0x18; break;
        case '<': out[2]=0x06; out[3]=0x0C; out[4]=0x18; out[5]=0x30; out[6]=0x18; out[7]=0x0C; out[8]=0x06; break;
        case '=': out[3]=0x7E; out[4]=0x7E; out[6]=0x7E; out[7]=0x7E; break;
        case '>': out[2]=0x60; out[3]=0x30; out[4]=0x18; out[5]=0x0C; out[6]=0x18; out[7]=0x30; out[8]=0x60; break;
        case '%': out[2]=0x62; out[3]=0x64; out[4]=0x08; out[5]=0x10; out[6]=0x26; out[7]=0x46; break;
        case '[': out[2]=0x3C; out[3]=0x30; out[4]=0x30; out[5]=0x30; out[6]=0x30; out[7]=0x30; out[8]=0x3C; break;
        case ']': out[2]=0x3C; out[3]=0x0C; out[4]=0x0C; out[5]=0x0C; out[6]=0x0C; out[7]=0x0C; out[8]=0x3C; break;

        // Digits
        case '0': out[2]=0x3C; out[3]=0x66; out[4]=0x6E; out[5]=0x76; out[6]=0x66; out[7]=0x66; out[8]=0x3C; break;
        case '1': out[2]=0x18; out[3]=0x38; out[4]=0x18; out[5]=0x18; out[6]=0x18; out[7]=0x18; out[8]=0x7E; break;
        case '2': out[2]=0x3C; out[3]=0x66; out[4]=0x06; out[5]=0x0C; out[6]=0x18; out[7]=0x30; out[8]=0x7E; break;
        case '3': out[2]=0x3C; out[3]=0x66; out[4]=0x06; out[5]=0x1C; out[6]=0x06; out[7]=0x66; out[8]=0x3C; break;
        case '4': out[2]=0x0C; out[3]=0x1C; out[4]=0x34; out[5]=0x64; out[6]=0x7E; out[7]=0x04; out[8]=0x0E; break;
        case '5': out[2]=0x7E; out[3]=0x60; out[4]=0x7C; out[5]=0x06; out[6]=0x06; out[7]=0x66; out[8]=0x3C; break;
        case '6': out[2]=0x1C; out[3]=0x30; out[4]=0x60; out[5]=0x7C; out[6]=0x66; out[7]=0x66; out[8]=0x3C; break;
        case '7': out[2]=0x7E; out[3]=0x06; out[4]=0x0C; out[5]=0x18; out[6]=0x30; out[7]=0x30; out[8]=0x30; break;
        case '8': out[2]=0x3C; out[3]=0x66; out[4]=0x66; out[5]=0x3C; out[6]=0x66; out[7]=0x66; out[8]=0x3C; break;
        case '9': out[2]=0x3C; out[3]=0x66; out[4]=0x66; out[5]=0x3E; out[6]=0x06; out[7]=0x0C; out[8]=0x38; break;

        // Letters
        case 'A': out[2]=0x18; out[3]=0x3C; out[4]=0x66; out[5]=0x66; out[6]=0x7E; out[7]=0x66; out[8]=0x66; break;
        case 'B': out[2]=0x7C; out[3]=0x66; out[4]=0x66; out[5]=0x7C; out[6]=0x66; out[7]=0x66; out[8]=0x7C; break;
        case 'C': out[2]=0x3C; out[3]=0x66; out[4]=0x60; out[5]=0x60; out[6]=0x60; out[7]=0x66; out[8]=0x3C; break;
        case 'D': out[2]=0x78; out[3]=0x6C; out[4]=0x66; out[5]=0x66; out[6]=0x66; out[7]=0x6C; out[8]=0x78; break;
        case 'E': out[2]=0x7E; out[3]=0x60; out[4]=0x60; out[5]=0x7C; out[6]=0x60; out[7]=0x60; out[8]=0x7E; break;
        case 'F': out[2]=0x7E; out[3]=0x60; out[4]=0x60; out[5]=0x7C; out[6]=0x60; out[7]=0x60; out[8]=0x60; break;
        case 'G': out[2]=0x3C; out[3]=0x66; out[4]=0x60; out[5]=0x6E; out[6]=0x66; out[7]=0x66; out[8]=0x3C; break;
        case 'H': out[2]=0x66; out[3]=0x66; out[4]=0x66; out[5]=0x7E; out[6]=0x66; out[7]=0x66; out[8]=0x66; break;
        case 'I': out[2]=0x7E; out[3]=0x18; out[4]=0x18; out[5]=0x18; out[6]=0x18; out[7]=0x18; out[8]=0x7E; break;
        case 'J': out[2]=0x1E; out[3]=0x06; out[4]=0x06; out[5]=0x06; out[6]=0x06; out[7]=0x66; out[8]=0x3C; break;
        case 'K': out[2]=0x66; out[3]=0x6C; out[4]=0x78; out[5]=0x70; out[6]=0x78; out[7]=0x6C; out[8]=0x66; break;
        case 'L': out[2]=0x60; out[3]=0x60; out[4]=0x60; out[5]=0x60; out[6]=0x60; out[7]=0x60; out[8]=0x7E; break;
        case 'M': out[2]=0x63; out[3]=0x77; out[4]=0x7F; out[5]=0x6B; out[6]=0x63; out[7]=0x63; out[8]=0x63; break;
        case 'N': out[2]=0x66; out[3]=0x76; out[4]=0x7E; out[5]=0x7E; out[6]=0x6E; out[7]=0x66; out[8]=0x66; break;
        case 'O': out[2]=0x3C; out[3]=0x66; out[4]=0x66; out[5]=0x66; out[6]=0x66; out[7]=0x66; out[8]=0x3C; break;
        case 'P': out[2]=0x7C; out[3]=0x66; out[4]=0x66; out[5]=0x7C; out[6]=0x60; out[7]=0x60; out[8]=0x60; break;
        case 'Q': out[2]=0x3C; out[3]=0x66; out[4]=0x66; out[5]=0x66; out[6]=0x6A; out[7]=0x3C; out[8]=0x0E; break;
        case 'R': out[2]=0x7C; out[3]=0x66; out[4]=0x66; out[5]=0x7C; out[6]=0x78; out[7]=0x6C; out[8]=0x66; break;
        case 'S': out[2]=0x3C; out[3]=0x66; out[4]=0x60; out[5]=0x3C; out[6]=0x06; out[7]=0x66; out[8]=0x3C; break;
        case 'T': out[2]=0x7E; out[3]=0x18; out[4]=0x18; out[5]=0x18; out[6]=0x18; out[7]=0x18; out[8]=0x18; break;
        case 'U': out[2]=0x66; out[3]=0x66; out[4]=0x66; out[5]=0x66; out[6]=0x66; out[7]=0x66; out[8]=0x3C; break;
        case 'V': out[2]=0x66; out[3]=0x66; out[4]=0x66; out[5]=0x66; out[6]=0x66; out[7]=0x3C; out[8]=0x18; break;
        case 'W': out[2]=0x63; out[3]=0x63; out[4]=0x63; out[5]=0x6B; out[6]=0x7F; out[7]=0x77; out[8]=0x63; break;
        case 'X': out[2]=0x66; out[3]=0x66; out[4]=0x3C; out[5]=0x18; out[6]=0x3C; out[7]=0x66; out[8]=0x66; break;
        case 'Y': out[2]=0x66; out[3]=0x66; out[4]=0x66; out[5]=0x3C; out[6]=0x18; out[7]=0x18; out[8]=0x18; break;
        case 'Z': out[2]=0x7E; out[3]=0x06; out[4]=0x0C; out[5]=0x18; out[6]=0x30; out[7]=0x60; out[8]=0x7E; break;
        default: break;
    }
}

struct Button {
    int x, y, w, h;
    std::string text;
    int id;
};

void draw_glyph(char c, float x, float y, float scale = 1.0f) {
    uint16_t rows[13];
    get_glyph(c, rows);

    for (int r = 0; r < 13; ++r) {
        uint16_t line = rows[r];
        if (!line) continue;
        for (int b = 0; b < 8; ++b) {
            if (line & (1 << (7 - b))) {
                float px = x + b * scale;
                float py = y + r * scale;
                glRectf(px, py, px + scale, py + scale);
            }
        }
    }
}

void draw_ui_text(const std::string& text, float x, float y, float scale = 1.25f) {
    float cx = x;
    for (char c : text) {
        if (c == ' ') {
            cx += 6.0f * scale;
        } else {
            draw_glyph(c, cx, y, scale);
            cx += 8.5f * scale;
        }
    }
}

void draw_panel(int x, int y, int w, int h, float r, float g, float b, float a = 1.0f) {
    glColor4f(r, g, b, a);
    glRectf(x, y, x + w, y + h);

    glColor4f(r * 1.5f + 0.1f, g * 1.5f + 0.1f, b * 1.5f + 0.12f, 1.0f);
    glLineWidth(1.5f);
    glBegin(GL_LINE_LOOP);
    glVertex2f(x, y);
    glVertex2f(x + w, y);
    glVertex2f(x + w, y + h);
    glVertex2f(x, y + h);
    glEnd();
}

void draw_button(const Button& btn, bool active = false, bool hover = false) {
    if (active) {
        // Emerald active
        glColor3f(0.08f, 0.68f, 0.48f);
        glRectf(btn.x, btn.y, btn.x + btn.w, btn.y + btn.h);
        glColor3f(0.35f, 0.98f, 0.75f);
    } else if (hover) {
        // Hover highlight
        glColor3f(0.24f, 0.28f, 0.38f);
        glRectf(btn.x, btn.y, btn.x + btn.w, btn.y + btn.h);
        glColor3f(0.45f, 0.55f, 0.72f);
    } else {
        // Sleek standard button
        glColor3f(0.15f, 0.18f, 0.25f);
        glRectf(btn.x, btn.y, btn.x + btn.w, btn.y + btn.h);
        glColor3f(0.26f, 0.30f, 0.40f);
    }

    glLineWidth(1.5f);
    glBegin(GL_LINE_LOOP);
    glVertex2f(btn.x, btn.y);
    glVertex2f(btn.x + btn.w, btn.y);
    glVertex2f(btn.x + btn.w, btn.y + btn.h);
    glVertex2f(btn.x, btn.y + btn.h);
    glEnd();

    // Text centering
    float text_width = btn.text.length() * (8.5f * 1.15f);
    float text_x = btn.x + (btn.w - text_width) / 2.0f;
    if (text_x < btn.x + 6) text_x = btn.x + 6;
    float text_y = btn.y + (btn.h - (13.0f * 1.15f)) / 2.0f;

    if (active) {
        glColor3f(1.0f, 1.0f, 1.0f);
    } else if (hover) {
        glColor3f(1.0f, 1.0f, 1.0f);
    } else {
        glColor3f(0.88f, 0.91f, 0.96f);
    }
    draw_ui_text(btn.text, text_x, text_y, 1.15f);
}

int main() {
    Display* dpy = XOpenDisplay(nullptr);
    if (!dpy) {
        std::cerr << "Cannot open X Display!\n";
        return 1;
    }

    int screen = DefaultScreen(dpy);
    GLint att[] = {GLX_RGBA, GLX_DOUBLEBUFFER, GLX_DEPTH_SIZE, 24, None};
    XVisualInfo* vi = glXChooseVisual(dpy, screen, att);
    if (!vi) {
        std::cerr << "No visual found\n";
        return 1;
    }

    XSetWindowAttributes swa;
    swa.colormap = XCreateColormap(dpy, RootWindow(dpy, vi->screen), vi->visual, AllocNone);
    swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask | ButtonReleaseMask | PointerMotionMask | StructureNotifyMask;

    Window win = XCreateWindow(dpy, RootWindow(dpy, vi->screen), 50, 50, WIN_WIDTH, WIN_HEIGHT, 0,
                               vi->depth, InputOutput, vi->visual, CWColormap | CWEventMask, &swa);

    XStoreName(dpy, win, "Conway's Game of Life - HPC Suite (CPU vs CUDA)");
    XMapWindow(dpy, win);

    GLXContext glc = glXCreateContext(dpy, vi, nullptr, GL_TRUE);
    glXMakeCurrent(dpy, win, glc);

    // Initial simulation setup
    int current_grid_size = 256;
    bool is_cuda = true;
    bool use_shared = false;
    bool is_running = true;

    CPULife cpu_life(current_grid_size, current_grid_size);
    cpu_life.randomize(0.28f);

    CUDALife cuda_life(current_grid_size, current_grid_size, use_shared);
    cuda_life.upload(cpu_life.grid.data());

    std::vector<uint32_t> rgba_texture(current_grid_size * current_grid_size);
    GLuint tex_id;
    glGenTextures(1, &tex_id);
    glBindTexture(GL_TEXTURE_2D, tex_id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    // Dashboard Buttons setup
    std::vector<Button> buttons;
    int col_w = (DASH_W - 10) / 2;

    // 1. Backend Selection
    buttons.push_back({DASH_X, 85, col_w, 36, "MODE: CPU", 1});
    buttons.push_back({DASH_X + col_w + 10, 85, col_w, 36, "MODE: CUDA", 2});

    // 2. Kernel Mode
    buttons.push_back({DASH_X, 128, col_w, 32, "GLOBAL MEMORY", 3});
    buttons.push_back({DASH_X + col_w + 10, 128, col_w, 32, "SHARED MEMORY", 4});

    // 3. Grid Resolution
    int res_w = (DASH_W - 24) / 5;
    buttons.push_back({DASH_X, 195, res_w, 32, "128", 10});
    buttons.push_back({DASH_X + (res_w + 6), 195, res_w, 32, "256", 11});
    buttons.push_back({DASH_X + (res_w + 6) * 2, 195, res_w, 32, "512", 12});
    buttons.push_back({DASH_X + (res_w + 6) * 3, 195, res_w, 32, "1024", 13});
    buttons.push_back({DASH_X + (res_w + 6) * 4, 195, res_w, 32, "2048", 14});

    // 4. Simulation Controls
    int ctrl_w = (DASH_W - 16) / 3;
    buttons.push_back({DASH_X, 260, ctrl_w, 36, "PLAY / PAUSE", 20});
    buttons.push_back({DASH_X + ctrl_w + 8, 260, ctrl_w, 36, "STEP (1 GEN)", 21});
    buttons.push_back({DASH_X + (ctrl_w + 8) * 2, 260, ctrl_w, 36, "RANDOMIZE", 22});

    buttons.push_back({DASH_X, 304, col_w, 34, "CLEAR BOARD", 23});
    buttons.push_back({DASH_X + col_w + 10, 304, col_w, 34, "GOSPER GUN", 24});

    // 5. Benchmark Trigger
    buttons.push_back({DASH_X, 365, DASH_W, 42, "RUN 100-ITER BENCHMARK", 30});

    // Metrics & Mouse state
    double last_step_ms = 0.0;
    double last_bench_cpu = 0.0;
    double last_bench_cuda = 0.0;
    double last_bench_speedup = 0.0;
    int generation = 0;
    bool mouse_pressed = false;
    int cur_mouse_x = 0;
    int cur_mouse_y = 0;

    auto update_texture = [&]() {
        const uint8_t* ptr = cpu_life.grid.data();
        int sz = current_grid_size;
        for (int i = 0; i < sz * sz; ++i) {
            uint8_t cell = ptr[i];
            rgba_texture[i] = cell ? 0xFF42E8B0 : 0xFF12141A; // Vibrant teal alive, deep carbon dead
        }
        glBindTexture(GL_TEXTURE_2D, tex_id);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, sz, sz, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba_texture.data());
    };

    update_texture();

    bool running = true;
    while (running) {
        auto frame_start = std::chrono::high_resolution_clock::now();

        while (XPending(dpy)) {
            XEvent xev;
            XNextEvent(dpy, &xev);

            if (xev.type == KeyPress) {
                KeySym key = XLookupKeysym(&xev.xkey, 0);
                if (key == XK_Escape || key == XK_q) running = false;
                if (key == XK_space) is_running = !is_running;
            } else if (xev.type == MotionNotify) {
                cur_mouse_x = xev.xmotion.x;
                cur_mouse_y = xev.xmotion.y;
                if (mouse_pressed && cur_mouse_x < GRID_VIEW_SIZE) {
                    int cell_x = (cur_mouse_x * current_grid_size) / GRID_VIEW_SIZE;
                    int cell_y = (cur_mouse_y * current_grid_size) / GRID_VIEW_SIZE;
                    if (cell_x >= 0 && cell_x < current_grid_size && cell_y >= 0 && cell_y < current_grid_size) {
                        cpu_life.set_cell(cell_x, cell_y, 1);
                        if (is_cuda) cuda_life.upload(cpu_life.grid.data());
                        update_texture();
                    }
                }
            } else if (xev.type == ButtonPress) {
                int mx = xev.xbutton.x;
                int my = xev.xbutton.y;
                cur_mouse_x = mx;
                cur_mouse_y = my;
                mouse_pressed = true;

                // Check Button clicks
                for (const auto& btn : buttons) {
                    if (mx >= btn.x && mx <= btn.x + btn.w && my >= btn.y && my <= btn.y + btn.h) {
                        if (btn.id == 1) { // Mode CPU
                            if (is_cuda) {
                                cuda_life.download(cpu_life.grid.data());
                            }
                            is_cuda = false;
                        } else if (btn.id == 2) { // Mode CUDA
                            if (!is_cuda) {
                                cuda_life.upload(cpu_life.grid.data());
                            }
                            is_cuda = true;
                        } else if (btn.id == 3) { // Global memory
                            use_shared = false;
                            cuda_life.use_shared_mem = false;
                            is_cuda = true; // Automatically switch to CUDA
                        } else if (btn.id == 4) { // Shared memory
                            use_shared = true;
                            cuda_life.use_shared_mem = true;
                            is_cuda = true; // Automatically switch to CUDA
                        } else if (btn.id >= 10 && btn.id <= 14) { // Grid resize
                            int sizes[] = {128, 256, 512, 1024, 2048};
                            int new_size = sizes[btn.id - 10];
                            current_grid_size = new_size;
                            cpu_life = CPULife(new_size, new_size);
                            cpu_life.randomize(0.28f);
                            cuda_life.resize(new_size, new_size);
                            cuda_life.upload(cpu_life.grid.data());
                            rgba_texture.resize(new_size * new_size);
                            generation = 0;
                            update_texture();
                        } else if (btn.id == 20) { // Play / Pause
                            is_running = !is_running;
                        } else if (btn.id == 21) { // Step (1 Gen)
                            if (is_cuda) {
                                auto t0 = std::chrono::high_resolution_clock::now();
                                cuda_life.step();
                                auto t1 = std::chrono::high_resolution_clock::now();
                                last_step_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
                                cuda_life.download(cpu_life.grid.data());
                            } else {
                                auto t0 = std::chrono::high_resolution_clock::now();
                                cpu_life.step();
                                auto t1 = std::chrono::high_resolution_clock::now();
                                last_step_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
                            }
                            generation++;
                            update_texture();
                        } else if (btn.id == 22) { // Randomize
                            cpu_life.randomize(0.28f, rand());
                            if (is_cuda) cuda_life.upload(cpu_life.grid.data());
                            generation = 0;
                            update_texture();
                        } else if (btn.id == 23) { // Clear
                            cpu_life.clear();
                            if (is_cuda) cuda_life.upload(cpu_life.grid.data());
                            generation = 0;
                            update_texture();
                        } else if (btn.id == 24) { // Gosper Gun
                            cpu_life.clear();
                            int gx = current_grid_size / 4;
                            int gy = current_grid_size / 4;
                            std::vector<std::pair<int, int>> gun = {
                                {1,5},{1,6},{2,5},{2,6},
                                {11,5},{11,6},{11,7},{12,4},{12,8},{13,3},{13,9},{14,3},{14,9},{15,6},{16,4},{16,8},{17,5},{17,6},{17,7},{18,6},
                                {21,3},{21,4},{21,5},{22,3},{22,4},{22,5},{23,2},{23,6},{25,1},{25,2},{25,6},{25,7},
                                {35,3},{35,4},{36,3},{36,4}
                            };
                            for (auto p : gun) {
                                cpu_life.set_cell(gx + p.first, gy + p.second, 1);
                            }
                            if (is_cuda) cuda_life.upload(cpu_life.grid.data());
                            generation = 0;
                            update_texture();
                        } else if (btn.id == 30) { // Run Benchmark
                            // Download current state if in CUDA
                            if (is_cuda) cuda_life.download(cpu_life.grid.data());

                            CPULife bench_cpu(current_grid_size, current_grid_size);
                            bench_cpu.grid = cpu_life.grid;
                            last_bench_cpu = bench_cpu.run_benchmark(100);

                            CUDALife bench_cuda(current_grid_size, current_grid_size, use_shared);
                            bench_cuda.upload(cpu_life.grid.data());
                            last_bench_cuda = bench_cuda.run_benchmark(100);

                            last_bench_speedup = last_bench_cpu / (last_bench_cuda > 0.0001 ? last_bench_cuda : 0.0001);
                        }
                    }
                }

                // Grid click to toggle cell
                if (mx < GRID_VIEW_SIZE) {
                    int cell_x = (mx * current_grid_size) / GRID_VIEW_SIZE;
                    int cell_y = (my * current_grid_size) / GRID_VIEW_SIZE;
                    if (cell_x >= 0 && cell_x < current_grid_size && cell_y >= 0 && cell_y < current_grid_size) {
                        uint8_t cur = cpu_life.get_cell(cell_x, cell_y);
                        cpu_life.set_cell(cell_x, cell_y, cur ? 0 : 1);
                        if (is_cuda) cuda_life.upload(cpu_life.grid.data());
                        update_texture();
                    }
                }
            } else if (xev.type == ButtonRelease) {
                mouse_pressed = false;
            }
        }

        // Advance simulation if running
        if (is_running) {
            if (is_cuda) {
                auto t0 = std::chrono::high_resolution_clock::now();
                cuda_life.step();
                auto t1 = std::chrono::high_resolution_clock::now();
                last_step_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
                cuda_life.download(cpu_life.grid.data());
            } else {
                auto t0 = std::chrono::high_resolution_clock::now();
                cpu_life.step();
                auto t1 = std::chrono::high_resolution_clock::now();
                last_step_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
            }
            generation++;
            update_texture();
        }

        // Render Frame
        glViewport(0, 0, WIN_WIDTH, WIN_HEIGHT);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, WIN_WIDTH, WIN_HEIGHT, 0, -1, 1);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        glClearColor(0.06f, 0.07f, 0.10f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        // 1. Draw Simulation Grid (Left Side)
        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, tex_id);
        glColor3f(1.0f, 1.0f, 1.0f);
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0); glVertex2f(0, 0);
        glTexCoord2f(1, 0); glVertex2f(GRID_VIEW_SIZE, 0);
        glTexCoord2f(1, 1); glVertex2f(GRID_VIEW_SIZE, GRID_VIEW_SIZE);
        glTexCoord2f(0, 1); glVertex2f(0, GRID_VIEW_SIZE);
        glEnd();
        glDisable(GL_TEXTURE_2D);

        // Grid Border Divider
        glColor3f(0.18f, 0.22f, 0.30f);
        glLineWidth(2.0f);
        glBegin(GL_LINES);
        glVertex2f(GRID_VIEW_SIZE, 0);
        glVertex2f(GRID_VIEW_SIZE, WIN_HEIGHT);
        glEnd();

        // 2. Draw Dashboard Header Card
        glColor3f(0.35f, 0.82f, 0.95f);
        draw_ui_text("CONWAY'S GAME OF LIFE", DASH_X, 20, 1.6f);
        glColor3f(0.60f, 0.68f, 0.80f);
        draw_ui_text("HPC BENCHMARK: CPU (2D) VS CUDA GPU", DASH_X, 44, 1.15f);

        // Section Headers
        glColor3f(0.80f, 0.86f, 0.96f);
        draw_ui_text("1. COMPUTE BACKEND", DASH_X, 68, 1.2f);
        draw_ui_text("2. GRID RESOLUTION", DASH_X, 175, 1.2f);
        draw_ui_text("3. SIMULATION CONTROLS", DASH_X, 238, 1.2f);
        draw_ui_text("4. HPC BENCHMARK (100 ITERATIONS)", DASH_X, 345, 1.2f);

        // Render Buttons with Hover State
        for (const auto& btn : buttons) {
            bool active = false;
            if (btn.id == 1 && !is_cuda) active = true;
            if (btn.id == 2 && is_cuda) active = true;
            if (btn.id == 3 && is_cuda && !use_shared) active = true;
            if (btn.id == 4 && is_cuda && use_shared) active = true;
            if (btn.id >= 10 && btn.id <= 14) {
                int sizes[] = {128, 256, 512, 1024, 2048};
                if (sizes[btn.id - 10] == current_grid_size) active = true;
            }
            if (btn.id == 20 && is_running) active = true;

            bool hover = (cur_mouse_x >= btn.x && cur_mouse_x <= btn.x + btn.w &&
                          cur_mouse_y >= btn.y && cur_mouse_y <= btn.y + btn.h);

            draw_button(btn, active, hover);
        }

        // 3. Render Live Metrics Panel Card
        int py = 425;
        int ph = 295;
        draw_panel(DASH_X, py, DASH_W, ph, 0.11f, 0.13f, 0.18f);

        // Panel Title Badge
        glColor3f(0.18f, 0.78f, 0.55f);
        draw_ui_text("LIVE METRICS & HARDWARE HUD", DASH_X + 16, py + 16, 1.35f);

        // Status Row
        glColor3f(0.70f, 0.75f, 0.85f);
        draw_ui_text("SIMULATION STATUS : ", DASH_X + 16, py + 48, 1.15f);
        if (is_running) {
            glColor3f(0.25f, 0.95f, 0.55f);
            draw_ui_text("RUNNING", DASH_X + 185, py + 48, 1.15f);
        } else {
            glColor3f(0.95f, 0.45f, 0.40f);
            draw_ui_text("PAUSED", DASH_X + 185, py + 48, 1.15f);
        }

        // Backend Row
        glColor3f(0.70f, 0.75f, 0.85f);
        draw_ui_text("ACTIVE BACKEND    : ", DASH_X + 16, py + 72, 1.15f);
        glColor3f(0.40f, 0.85f, 1.0f);
        std::string backend_str = is_cuda ? (use_shared ? "CUDA (SHARED MEM)" : "CUDA (GLOBAL MEM)") : "CPU (SEQUENTIAL 2D)";
        draw_ui_text(backend_str, DASH_X + 185, py + 72, 1.15f);

        // Resolution Row
        glColor3f(0.70f, 0.75f, 0.85f);
        draw_ui_text("GRID RESOLUTION   : ", DASH_X + 16, py + 96, 1.15f);
        glColor3f(0.92f, 0.94f, 0.98f);
        std::string res_str = std::to_string(current_grid_size) + "X" + std::to_string(current_grid_size) + " (" + std::to_string(current_grid_size * current_grid_size) + " CELLS)";
        draw_ui_text(res_str, DASH_X + 185, py + 96, 1.15f);

        // Generation Row
        glColor3f(0.70f, 0.75f, 0.85f);
        draw_ui_text("GENERATION COUNT  : ", DASH_X + 16, py + 120, 1.15f);
        glColor3f(0.92f, 0.94f, 0.98f);
        draw_ui_text(std::to_string(generation), DASH_X + 185, py + 120, 1.15f);

        // Latency Row
        glColor3f(0.70f, 0.75f, 0.85f);
        draw_ui_text("STEP LATENCY      : ", DASH_X + 16, py + 144, 1.15f);
        glColor3f(0.95f, 0.85f, 0.40f);
        std::ostringstream ss_lat;
        ss_lat << std::fixed << std::setprecision(4) << last_step_ms << " MS";
        draw_ui_text(ss_lat.str(), DASH_X + 185, py + 144, 1.15f);

        // Divider in panel
        glColor3f(0.20f, 0.25f, 0.35f);
        glLineWidth(1.0f);
        glBegin(GL_LINES);
        glVertex2f(DASH_X + 16, py + 172);
        glVertex2f(DASH_X + DASH_W - 16, py + 172);
        glEnd();

        // Benchmark Section
        glColor3f(0.45f, 0.85f, 1.0f);
        draw_ui_text("LAST 100-ITER BENCHMARK RESULTS", DASH_X + 16, py + 188, 1.2f);

        std::ostringstream ss_bench;
        ss_bench << "CPU: " << std::fixed << std::setprecision(2) << last_bench_cpu << " MS   CUDA: " << std::fixed << std::setprecision(2) << last_bench_cuda << " MS";
        glColor3f(0.85f, 0.88f, 0.94f);
        draw_ui_text(ss_bench.str(), DASH_X + 16, py + 215, 1.15f);

        // Speedup Badge Card
        draw_panel(DASH_X + 16, py + 240, DASH_W - 32, 40, 0.08f, 0.25f, 0.18f);
        std::ostringstream ss_spd;
        ss_spd << "SPEEDUP: " << std::fixed << std::setprecision(2) << last_bench_speedup << "X FASTER ON GPU";
        glColor3f(0.35f, 0.98f, 0.65f);
        draw_ui_text(ss_spd.str(), DASH_X + 30, py + 252, 1.3f);

        glXSwapBuffers(dpy, win);

        // Frame rate limiter (~60 FPS) to keep CPU & event loop super responsive
        auto frame_end = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double, std::milli> frame_dur = frame_end - frame_start;
        if (frame_dur.count() < 16.6) {
            std::this_thread::sleep_for(std::chrono::milliseconds((int)(16.6 - frame_dur.count())));
        }
    }

    glXMakeCurrent(dpy, None, nullptr);
    glXDestroyContext(dpy, glc);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
