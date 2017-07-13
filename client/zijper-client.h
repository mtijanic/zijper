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


#ifdef DEBUG
#define breakpoint()  __asm__ __volatile__ ("int $3")
#else
#define breakpoint()
#endif

#define UNUSED(x) (void)sizeof(x)

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

//
// Weak symbols used across modules
//
void framerate_notify_frame(void);
void framerate_print_report(FILE *f);

#define FBO_NONE    0
#define FBO_PRIMARY 1
#define FBO_GUI     2

void fbo_draw(void);
void fbo_use(int which);
#endif // ZIJPER_CLIENT_H
