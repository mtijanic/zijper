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

int __attribute__((thiscall)) WRAPPER_CGuiMan__UpdateAndRender(void* this, ...);

void gl_hooks_initialize(void)
{
    original.SDL_GL_SwapBuffers = dlsym(RTLD_NEXT, "SDL_GL_SwapBuffers");

    uint32_t wrapper_offset;
    wrapper_offset = (uint32_t)&WRAPPER_CGuiMan__UpdateAndRender - 0x8050f41 - 5;
    apply_patch(0x8050f41 + 1, &wrapper_offset, 4);
    wrapper_offset = (uint32_t)&WRAPPER_CGuiMan__UpdateAndRender - 0x8054771 - 5;
    apply_patch(0x8054771 + 1, &wrapper_offset, 4);
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

int __attribute__((thiscall)) WRAPPER_CGuiMan__UpdateAndRender(void* this, ...)
{
    UNUSED(this);
    void *CGuiMan__UpdateAndRender = (void*)0x084b61e4;

    fbo_use(FBO_GUI);
      void *arg = __builtin_apply_args();
      void *ret = __builtin_apply(CGuiMan__UpdateAndRender, arg, 32);
    fbo_use(FBO_PRIMARY);
    __builtin_return(ret);
}
