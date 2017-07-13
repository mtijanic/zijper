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


void (*CGuiMan__UpdateAndRender)(void* this, float delta);
int  (*CNWCMessage__HandleServerToPlayerMessage)(void *this, uint8_t *buffer, uint32_t size);
int  (*CNWSMessage__SendServerToPlayerMessage)(uint32_t nPlayerId, uint8_t nMajor, uint8_t nMinor, uint8_t *pBuffer, uint32_t nBufferSize);



int hook_CNWCMessage__HandleServerToPlayerMessage(void *this, uint8_t *buffer, uint32_t size)
{
    /// @todo Detect custom message to control shaders
    return CNWCMessage__HandleServerToPlayerMessage(this, buffer, size);
}

void hook_CGuiMan__UpdateAndRender(void *this, float delta)
{
    fbo_use(FBO_GUI);
    CGuiMan__UpdateAndRender(this, delta);
    fbo_use(FBO_PRIMARY);
}


static void hook_nwmain_functions(void)
{
    CNWCMessage__HandleServerToPlayerMessage = make_detour((void*)0x815ed58,
        hook_CNWCMessage__HandleServerToPlayerMessage, 5);

    CGuiMan__UpdateAndRender = make_detour((void*)0x084b61e4,
        hook_CGuiMan__UpdateAndRender, 5);

    CNWSMessage__SendServerToPlayerMessage = (void*)0x83d58c4;
}

void gl_hooks_initialize(void)
{
    hook_nwmain_functions();

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
