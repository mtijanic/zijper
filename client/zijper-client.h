/**
 * @file
 * @brief   Utility header file
 * @author  mtijanic
 * @license GPL-2.0
 */

#ifndef ZIJPER_CLIENT_H
#define ZIJPER_CLIENT_H

#include <stdint.h>
#include <stdio.h>
#include <time.h>

#ifdef DEBUG
#define breakpoint()  __asm__ __volatile__ ("int $3")
#else
#define breakpoint()
#endif

#define UNUSED(x) (void)sizeof(x)

#define COUNTOF(a) (sizeof(a) / sizeof(a[0]))

extern FILE *logfile;

#define _STR2(x) #x
#define _STR(x) _STR2(x)

#define ASSERT(cond, ...)                                                      \
    do                                                                         \
    {                                                                          \
        int _c = (int)(cond);                                                  \
        if (!_c)                                                               \
        {                                                                      \
            fprintf(logfile,                                                   \
                "Assertion \""#cond"\" failed @ " __FILE__":"_STR(__LINE__)"; "\
                __VA_ARGS__);                                                  \
            fprintf(logfile, "\n");                                            \
            fflush(logfile);                                                   \
            breakpoint();                                                      \
        }                                                                      \
    } while (0)

void apply_patch(uintptr_t address, const void *patch, size_t patch_size);
void *make_detour(void *old_func, void *new_func, size_t bytes_to_copy);
void single_call_detour(uintptr_t address, void *func);

struct debug_data {
    uint8_t disable_all_effects;
};
extern struct debug_data debug_data;

extern uint32_t screen_width;
extern uint32_t screen_height;

struct input_data {
    uint32_t mouse_x;
    uint32_t mouse_y;

    // Is the button currently pressed
    uint8_t is_lmb_down;
    uint8_t is_rmb_down;
    // Was the button released this frame?
    uint8_t was_lmb_up;
    uint8_t was_rmb_up;
};
extern struct input_data input_data;

//
// Weak symbols used across modules
//
#define MAX_FRAMES_PER_SECOND 4000
struct frame_data {
    struct {
        uint32_t seconds;
        uint32_t microseconds;
    } init_time;
    struct {
        uint32_t seconds;
        uint32_t microseconds;
    } last_frame_time;
    uint32_t frames_this_second;
    uint32_t total_frames;
    uint32_t fps_histogram[MAX_FRAMES_PER_SECOND+1];
};
extern struct frame_data frame_data;
uint32_t framerate_microseconds_since_last_frame(void);
void framerate_notify_frame(void);
void framerate_print_report(FILE *f);

#define FBO_NONE    0
#define FBO_PRIMARY 1
#define FBO_GUI     2
#define FBO_SKYBOX  3

void fbo_draw_all(void);
void fbo_use(int which);
#endif // ZIJPER_CLIENT_H
