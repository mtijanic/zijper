/**
 * @file
 * @brief   Hooks into library function calls from main executable
 * @author  mtijanic
 * @license GPL-2.0
 */

#include "zijper-client.h"
#include "dlfcn.h"

void gl_hooks_initialize(void) __attribute__((constructor));
void gl_hooks_shutdown(void)   __attribute__((destructor));

static struct {
    void (*SDL_GL_SwapBuffers)(void);
} original;

void gl_hooks_initialize(void)
{
    original.SDL_GL_SwapBuffers = dlsym(RTLD_NEXT, "SDL_GL_SwapBuffers");
}
void gl_hooks_shutdown(void)
{
}

void SDL_GL_SwapBuffers(void)
{
    fbo_draw();
    original.SDL_GL_SwapBuffers();
    fbo_use(FBO_PRIMARY);
    framerate_notify_frame();
}
