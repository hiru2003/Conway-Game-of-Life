#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <GL/gl.h>
#include <GL/glx.h>
#include <iostream>
#include <vector>
#include <string>
#include <chrono>
#include <cmath>
#include <cctype>
#include <algorithm>
#include <iomanip>
#include <sstream>
#include <thread>
#include "cpu_life.h"
#include "cuda_life.h"

// Window Dimensions
const int WIN_WIDTH = 1380;
const int WIN_HEIGHT = 800;
const int GRID_VIEW_SIZE = 800;
const int DASH_X = GRID_VIEW_SIZE + 15;
const int DASH_W = WIN_WIDTH - GRID_VIEW_SIZE - 30;
const int DASH_PAD = 16;    // inner padding for panel contents
const int VALUE_COL = 210;  // x offset of the value column inside the metrics panel

// Palette - restyle the whole dashboard from this one block.
struct Col { float r, g, b; };

const Col C_BG          = {0.043f, 0.051f, 0.071f};  // window background
const Col C_PANEL       = {0.078f, 0.090f, 0.118f};  // card fill
const Col C_PANEL_EDGE  = {0.157f, 0.180f, 0.235f};  // card border
const Col C_DIVIDER     = {0.141f, 0.165f, 0.220f};  // hairline rules

const Col C_BTN         = {0.110f, 0.129f, 0.173f};
const Col C_BTN_EDGE    = {0.204f, 0.235f, 0.306f};
const Col C_BTN_HOVER   = {0.169f, 0.200f, 0.267f};
const Col C_BTN_HOVER_E = {0.357f, 0.420f, 0.549f};
const Col C_BTN_ON      = {0.055f, 0.510f, 0.420f};
const Col C_BTN_ON_EDGE = {0.251f, 0.878f, 0.702f};

const Col C_TEXT        = {0.878f, 0.906f, 0.953f};  // primary text
const Col C_TEXT_DIM    = {0.482f, 0.537f, 0.631f};  // labels and captions
const Col C_TEXT_ON     = {1.000f, 1.000f, 1.000f};  // text on an active button

const Col C_ACCENT      = {0.251f, 0.878f, 0.702f};  // headline accent (mint)
const Col C_ACCENT_ALT  = {0.361f, 0.706f, 0.980f};  // secondary accent (blue)
const Col C_WARN        = {0.980f, 0.733f, 0.310f};  // latency figures
const Col C_OK          = {0.251f, 0.878f, 0.549f};  // running state
const Col C_STOP        = {0.961f, 0.443f, 0.408f};  // paused state
const Col C_CARD_OK     = {0.047f, 0.169f, 0.137f};  // speedup badge fill
const Col C_CARD_OK_E   = {0.141f, 0.455f, 0.361f};

inline void set_color(const Col& c) { glColor3f(c.r, c.g, c.b); }

// Texture words are little-endian RGBA, i.e. 0xAABBGGRR.
constexpr uint32_t rgba(uint8_t r, uint8_t g, uint8_t b) {
    return 0xFF000000u | (uint32_t(b) << 16) | (uint32_t(g) << 8) | uint32_t(r);
}
const uint32_t CELL_ALIVE = rgba(0x4A, 0xDE, 0x80);  // mint green
const uint32_t CELL_DEAD  = rgba(0x0E, 0x11, 0x17);  // near-black

// Grid resolutions, matching the benchmark's 128..4096 sweep.
const int GRID_SIZES[6] = {128, 256, 512, 1024, 2048, 4096};
const char* const GRID_LABELS[6] = {"128", "256", "512", "1024", "2048", "4096"};

// Playback speed in target generations per second; 0 means uncapped.
const int SPEED_GPS[4] = {5, 20, 60, 0};
const char* const SPEED_LABELS[4] = {"SLOW", "NORMAL", "FAST", "MAX"};

// ASCII patterns ('O' = live cell), centred on the board when placed.
const std::vector<std::string> PATTERN_GOSPER = {
    "........................O...........",
    "......................O.O...........",
    "............OO......OO............OO",
    "...........O...O....OO............OO",
    "OO........O.....O...OO..............",
    "OO........O...O.OO....O.O...........",
    "..........O.....O.......O...........",
    "...........O...O....................",
    "............OO......................"
};

const std::vector<std::string> PATTERN_PULSAR = {
    "..OOO...OOO..",
    ".............",
    "O....O.O....O",
    "O....O.O....O",
    "O....O.O....O",
    "..OOO...OOO..",
    ".............",
    "..OOO...OOO..",
    "O....O.O....O",
    "O....O.O....O",
    "O....O.O....O",
    ".............",
    "..OOO...OOO.."
};

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

// Advance width of a string, matching draw_ui_text's per-character stepping.
float text_width(const std::string& text, float scale) {
    float w = 0.0f;
    for (char c : text) w += (c == ' ' ? 6.0f : 8.5f) * scale;
    return w;
}

void draw_panel(int x, int y, int w, int h, const Col& fill, const Col& edge) {
    set_color(fill);
    glRectf(x, y, x + w, y + h);

    set_color(edge);
    glLineWidth(1.5f);
    glBegin(GL_LINE_LOOP);
    glVertex2f(x, y);
    glVertex2f(x + w, y);
    glVertex2f(x + w, y + h);
    glVertex2f(x, y + h);
    glEnd();
}

// Section heading with a hairline rule running out to the dashboard edge.
void draw_section(const std::string& label, int y) {
    set_color(C_ACCENT_ALT);
    draw_ui_text(label, DASH_X, y, 1.15f);

    float rule_x = DASH_X + text_width(label, 1.15f) + 10.0f;
    float rule_y = y + 8.0f;
    set_color(C_DIVIDER);
    glLineWidth(1.0f);
    glBegin(GL_LINES);
    glVertex2f(rule_x, rule_y);
    glVertex2f(DASH_X + DASH_W, rule_y);
    glEnd();
}

void draw_button(const Button& btn, bool active = false, bool hover = false) {
    const Col& fill = active ? C_BTN_ON : (hover ? C_BTN_HOVER : C_BTN);
    const Col& edge = active ? C_BTN_ON_EDGE : (hover ? C_BTN_HOVER_E : C_BTN_EDGE);

    set_color(fill);
    glRectf(btn.x, btn.y, btn.x + btn.w, btn.y + btn.h);

    set_color(edge);
    glLineWidth(1.5f);
    glBegin(GL_LINE_LOOP);
    glVertex2f(btn.x, btn.y);
    glVertex2f(btn.x + btn.w, btn.y);
    glVertex2f(btn.x + btn.w, btn.y + btn.h);
    glVertex2f(btn.x, btn.y + btn.h);
    glEnd();

    // Text centering
    float tw = text_width(btn.text, 1.15f);
    float text_x = btn.x + (btn.w - tw) / 2.0f;
    if (text_x < btn.x + 6) text_x = btn.x + 6;
    float text_y = btn.y + (btn.h - (13.0f * 1.15f)) / 2.0f;

    set_color((active || hover) ? C_TEXT_ON : C_TEXT);
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
    buttons.push_back({DASH_X, 102, col_w, 36, "MODE: CPU", 1});
    buttons.push_back({DASH_X + col_w + 10, 102, col_w, 36, "MODE: CUDA", 2});

    // 2. Kernel Mode
    buttons.push_back({DASH_X, 144, col_w, 32, "GLOBAL MEMORY", 3});
    buttons.push_back({DASH_X + col_w + 10, 144, col_w, 32, "SHARED MEMORY", 4});

    // 3. Grid Resolution
    int res_w = (DASH_W - 30) / 6;
    for (int i = 0; i < 6; ++i) {
        buttons.push_back({DASH_X + (res_w + 6) * i, 208, res_w, 32, GRID_LABELS[i], 10 + i});
    }

    // 4. Simulation Controls
    int ctrl_w = (DASH_W - 16) / 3;
    buttons.push_back({DASH_X, 272, ctrl_w, 36, "PLAY / PAUSE", 20});
    buttons.push_back({DASH_X + ctrl_w + 8, 272, ctrl_w, 36, "STEP (1 GEN)", 21});
    buttons.push_back({DASH_X + (ctrl_w + 8) * 2, 272, ctrl_w, 36, "RANDOMIZE", 22});

    buttons.push_back({DASH_X, 314, ctrl_w, 34, "CLEAR BOARD", 23});
    buttons.push_back({DASH_X + ctrl_w + 8, 314, ctrl_w, 34, "GOSPER GUN", 24});
    buttons.push_back({DASH_X + (ctrl_w + 8) * 2, 314, ctrl_w, 34, "PULSAR", 25});

    // 5. Playback Speed
    int spd_w = (DASH_W - 18) / 4;
    for (int i = 0; i < 4; ++i) {
        buttons.push_back({DASH_X + (spd_w + 6) * i, 378, spd_w, 30, SPEED_LABELS[i], 40 + i});
    }

    // 6. Benchmark Trigger
    buttons.push_back({DASH_X, 442, DASH_W, 42, "RUN 100-ITER BENCHMARK", 30});

    // Metrics & Mouse state
    double last_step_ms = 0.0;
    double last_bench_cpu = 0.0;
    double last_bench_cuda = 0.0;
    double last_bench_speedup = 0.0;
    int generation = 0;
    bool mouse_pressed = false;
    int cur_mouse_x = 0;
    int cur_mouse_y = 0;
    uint8_t paint_value = 1;  // left button draws cells, right button erases

    int speed_idx = 1;        // index into SPEED_GPS / SPEED_LABELS
    auto last_step_time = std::chrono::high_resolution_clock::now();

    auto update_texture = [&]() {
        const uint8_t* ptr = cpu_life.grid.data();
        int sz = current_grid_size;
        for (int i = 0; i < sz * sz; ++i) {
            rgba_texture[i] = ptr[i] ? CELL_ALIVE : CELL_DEAD;
        }
        glBindTexture(GL_TEXTURE_2D, tex_id);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, sz, sz, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba_texture.data());
    };

    update_texture();

    // Shared actions, so the buttons and the keyboard shortcuts stay in sync.
    auto sync_device = [&]() {
        if (is_cuda) cuda_life.upload(cpu_life.grid.data());
        update_texture();
    };

    auto advance_one = [&]() {
        auto t0 = std::chrono::high_resolution_clock::now();
        if (is_cuda) {
            cuda_life.step();
        } else {
            cpu_life.step();
        }
        auto t1 = std::chrono::high_resolution_clock::now();
        last_step_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
        if (is_cuda) cuda_life.download(cpu_life.grid.data());
        generation++;
        update_texture();
    };

    auto do_randomize = [&]() {
        cpu_life.randomize(0.28f, rand());
        generation = 0;
        sync_device();
    };

    auto do_clear = [&]() {
        cpu_life.clear();
        generation = 0;
        sync_device();
    };

    auto do_resize = [&](int new_size) {
        current_grid_size = new_size;
        cpu_life = CPULife(new_size, new_size);
        cpu_life.randomize(0.28f);
        cuda_life.resize(new_size, new_size);
        cuda_life.upload(cpu_life.grid.data());
        rgba_texture.resize(new_size * new_size);
        generation = 0;
        update_texture();
    };

    // Clear the board and stamp an ASCII pattern in the middle of it.
    auto place_pattern = [&](const std::vector<std::string>& rows) {
        cpu_life.clear();
        int ph = static_cast<int>(rows.size());
        int pw = 0;
        for (const auto& row : rows) pw = std::max(pw, static_cast<int>(row.size()));

        int ox = std::max(0, (current_grid_size - pw) / 2);
        int oy = std::max(0, (current_grid_size - ph) / 2);

        for (int y = 0; y < ph; ++y) {
            for (int x = 0; x < static_cast<int>(rows[y].size()); ++x) {
                if (rows[y][x] != 'O') continue;
                if (ox + x >= current_grid_size || oy + y >= current_grid_size) continue;
                cpu_life.set_cell(ox + x, oy + y, 1);
            }
        }
        generation = 0;
        sync_device();
    };

    bool running = true;
    while (running) {
        auto frame_start = std::chrono::high_resolution_clock::now();

        while (XPending(dpy)) {
            XEvent xev;
            XNextEvent(dpy, &xev);

            if (xev.type == KeyPress) {
                KeySym key = XLookupKeysym(&xev.xkey, 0);
                if (key == XK_Escape || key == XK_q) running = false;
                else if (key == XK_space) is_running = !is_running;
                else if (key == XK_s) advance_one();
                else if (key == XK_r) do_randomize();
                else if (key == XK_c) do_clear();
                else if (key == XK_g) place_pattern(PATTERN_GOSPER);
                else if (key == XK_p) place_pattern(PATTERN_PULSAR);
                else if (key >= XK_1 && key <= XK_6) do_resize(GRID_SIZES[key - XK_1]);
                else if (key == XK_bracketleft && speed_idx > 0) speed_idx--;
                else if (key == XK_bracketright && speed_idx < 3) speed_idx++;
            } else if (xev.type == MotionNotify) {
                cur_mouse_x = xev.xmotion.x;
                cur_mouse_y = xev.xmotion.y;
                if (mouse_pressed && cur_mouse_x < GRID_VIEW_SIZE) {
                    int cell_x = (cur_mouse_x * current_grid_size) / GRID_VIEW_SIZE;
                    int cell_y = (cur_mouse_y * current_grid_size) / GRID_VIEW_SIZE;
                    if (cell_x >= 0 && cell_x < current_grid_size && cell_y >= 0 && cell_y < current_grid_size) {
                        cpu_life.set_cell(cell_x, cell_y, paint_value);
                        if (is_cuda) cuda_life.upload(cpu_life.grid.data());
                        update_texture();
                    }
                }
            } else if (xev.type == ButtonPress &&
                       (xev.xbutton.button == Button1 || xev.xbutton.button == Button3)) {
                int mx = xev.xbutton.x;
                int my = xev.xbutton.y;
                cur_mouse_x = mx;
                cur_mouse_y = my;
                mouse_pressed = true;
                paint_value = (xev.xbutton.button == Button3) ? 0 : 1;

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
                        } else if (btn.id >= 10 && btn.id <= 15) { // Grid resize
                            do_resize(GRID_SIZES[btn.id - 10]);
                        } else if (btn.id == 20) { // Play / Pause
                            is_running = !is_running;
                        } else if (btn.id == 21) { // Step (1 Gen)
                            advance_one();
                        } else if (btn.id == 22) { // Randomize
                            do_randomize();
                        } else if (btn.id == 23) { // Clear
                            do_clear();
                        } else if (btn.id == 24) { // Gosper Gun
                            place_pattern(PATTERN_GOSPER);
                        } else if (btn.id == 25) { // Pulsar
                            place_pattern(PATTERN_PULSAR);
                        } else if (btn.id >= 40 && btn.id <= 43) { // Playback speed
                            speed_idx = btn.id - 40;
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
                        cpu_life.set_cell(cell_x, cell_y, paint_value == 0 ? 0 : (cur ? 0 : 1));
                        if (is_cuda) cuda_life.upload(cpu_life.grid.data());
                        update_texture();
                    }
                }
            } else if (xev.type == ButtonRelease) {
                mouse_pressed = false;
            }
        }

        // Advance simulation if running, throttled to the selected speed
        if (is_running) {
            int gps = SPEED_GPS[speed_idx];
            bool due = true;
            if (gps > 0) {
                double since = std::chrono::duration<double, std::milli>(frame_start - last_step_time).count();
                due = since >= 1000.0 / gps;
            }
            if (due) {
                last_step_time = frame_start;
                advance_one();
            }
        }

        // Render Frame
        glViewport(0, 0, WIN_WIDTH, WIN_HEIGHT);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, WIN_WIDTH, WIN_HEIGHT, 0, -1, 1);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        glClearColor(C_BG.r, C_BG.g, C_BG.b, 1.0f);
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
        set_color(C_PANEL_EDGE);
        glLineWidth(2.0f);
        glBegin(GL_LINES);
        glVertex2f(GRID_VIEW_SIZE, 0);
        glVertex2f(GRID_VIEW_SIZE, WIN_HEIGHT);
        glEnd();

        // 2. Draw Dashboard Header Card
        set_color(C_ACCENT);
        draw_ui_text("CONWAY'S GAME OF LIFE", DASH_X, 22, 1.7f);
        set_color(C_TEXT_DIM);
        draw_ui_text("HPC BENCHMARK: CPU (2D) VS CUDA GPU", DASH_X, 52, 1.1f);

        // Section Headers
        draw_section("1. COMPUTE BACKEND", 84);
        draw_section("2. GRID RESOLUTION", 190);
        draw_section("3. SIMULATION CONTROLS", 254);
        draw_section("4. PLAYBACK SPEED", 360);
        draw_section("5. HPC BENCHMARK (100 ITERATIONS)", 424);

        // Render Buttons with Hover State
        for (const auto& btn : buttons) {
            bool active = false;
            if (btn.id == 1 && !is_cuda) active = true;
            if (btn.id == 2 && is_cuda) active = true;
            if (btn.id == 3 && is_cuda && !use_shared) active = true;
            if (btn.id == 4 && is_cuda && use_shared) active = true;
            if (btn.id >= 10 && btn.id <= 15 && GRID_SIZES[btn.id - 10] == current_grid_size) active = true;
            if (btn.id >= 40 && btn.id <= 43 && btn.id - 40 == speed_idx) active = true;
            if (btn.id == 20 && is_running) active = true;

            bool hover = (cur_mouse_x >= btn.x && cur_mouse_x <= btn.x + btn.w &&
                          cur_mouse_y >= btn.y && cur_mouse_y <= btn.y + btn.h);

            draw_button(btn, active, hover);
        }

        // 3. Render Live Metrics Panel Card
        int py = 500;
        int ph = 285;
        int lx = DASH_X + DASH_PAD;          // label column
        int vx = DASH_X + VALUE_COL;         // value column
        draw_panel(DASH_X, py, DASH_W, ph, C_PANEL, C_PANEL_EDGE);

        // Panel Title Badge
        set_color(C_ACCENT);
        draw_ui_text("LIVE TELEMETRY", lx, py + 16, 1.35f);

        // Status Row
        set_color(C_TEXT_DIM);
        draw_ui_text("SIMULATION STATUS :", lx, py + 48, 1.15f);
        set_color(is_running ? C_OK : C_STOP);
        draw_ui_text(is_running ? "RUNNING" : "PAUSED", vx, py + 48, 1.15f);

        // Backend Row
        set_color(C_TEXT_DIM);
        draw_ui_text("ACTIVE BACKEND    :", lx, py + 72, 1.15f);
        set_color(C_ACCENT_ALT);
        std::string backend_str = is_cuda ? (use_shared ? "CUDA (SHARED MEM)" : "CUDA (GLOBAL MEM)") : "CPU (SEQUENTIAL 2D)";
        draw_ui_text(backend_str, vx, py + 72, 1.15f);

        // Resolution Row
        set_color(C_TEXT_DIM);
        draw_ui_text("GRID RESOLUTION   :", lx, py + 96, 1.15f);
        set_color(C_TEXT);
        std::string res_str = std::to_string(current_grid_size) + "X" + std::to_string(current_grid_size) + " (" + std::to_string(current_grid_size * current_grid_size) + " CELLS)";
        draw_ui_text(res_str, vx, py + 96, 1.15f);

        // Generation Row
        set_color(C_TEXT_DIM);
        draw_ui_text("GENERATION COUNT  :", lx, py + 120, 1.15f);
        set_color(C_TEXT);
        draw_ui_text(std::to_string(generation), vx, py + 120, 1.15f);

        // Latency Row
        set_color(C_TEXT_DIM);
        draw_ui_text("STEP LATENCY      :", lx, py + 144, 1.15f);
        set_color(C_WARN);
        std::ostringstream ss_lat;
        ss_lat << std::fixed << std::setprecision(4) << last_step_ms << " MS";
        draw_ui_text(ss_lat.str(), vx, py + 144, 1.15f);

        // Divider in panel
        set_color(C_DIVIDER);
        glLineWidth(1.0f);
        glBegin(GL_LINES);
        glVertex2f(lx, py + 172);
        glVertex2f(DASH_X + DASH_W - DASH_PAD, py + 172);
        glEnd();

        // Benchmark Section
        set_color(C_ACCENT_ALT);
        draw_ui_text("LAST 100-ITER BENCHMARK RESULTS", lx, py + 188, 1.2f);

        std::ostringstream ss_bench;
        ss_bench << "CPU: " << std::fixed << std::setprecision(2) << last_bench_cpu << " MS   CUDA: " << std::fixed << std::setprecision(2) << last_bench_cuda << " MS";
        set_color(C_TEXT);
        draw_ui_text(ss_bench.str(), lx, py + 215, 1.15f);

        // Speedup Badge Card
        draw_panel(lx, py + 240, DASH_W - 2 * DASH_PAD, 40, C_CARD_OK, C_CARD_OK_E);
        std::ostringstream ss_spd;
        ss_spd << "SPEEDUP: " << std::fixed << std::setprecision(2) << last_bench_speedup << "X FASTER ON GPU";
        set_color(C_ACCENT);
        draw_ui_text(ss_spd.str(), lx + 14, py + 252, 1.3f);

        glXSwapBuffers(dpy, win);

        // Frame rate limiter (~60 FPS) to keep CPU & event loop super responsive.
        // MAX speed runs uncapped, so skip the sleep there.
        if (SPEED_GPS[speed_idx] != 0 || !is_running) {
            auto frame_end = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double, std::milli> frame_dur = frame_end - frame_start;
            if (frame_dur.count() < 16.6) {
                std::this_thread::sleep_for(std::chrono::milliseconds((int)(16.6 - frame_dur.count())));
            }
        }
    }

    glXMakeCurrent(dpy, None, nullptr);
    glXDestroyContext(dpy, glc);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
