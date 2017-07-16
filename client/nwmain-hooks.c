/**
 * @file
 * @brief   Functions for hooking into the main executable
 * @author  mtijanic
 * @license GPL-2.0
 */
#include "zijper-client.h"
#include "nwmain-hooks.h"

#include <dlfcn.h>
#include <string.h>

struct functions originals;
struct functions wrappers;
struct globals globals;

#define HOOK_LIBRARY_FUNCTION(func)                \
    do {                                           \
        extern typeof(*wrappers.func) func;        \
        wrappers.func = func;                      \
        originals.func = dlsym(RTLD_NEXT, #func);  \
    } while (0)

#define HOOK_NWMAIN_FUNCTION(func, addr)                               \
    do {                                                               \
        extern typeof(*wrappers.func) hook_##func;                     \
        wrappers.func = hook_##func;                                   \
        originals.func = make_detour((void*)addr, wrappers.func, 5);   \
    } while (0)


void nwmain_hooks_initialize(void)
{
    HOOK_LIBRARY_FUNCTION(SDL_GL_SwapBuffers);

    HOOK_NWMAIN_FUNCTION(CNWCMessage__HandleServerToPlayerMessage, 0x0815ed58);
    HOOK_NWMAIN_FUNCTION(CNWSMessage__SendServerToPlayerMessage,   0x083d58c4);
    HOOK_NWMAIN_FUNCTION(NWSScriptVarTable__SetString,             0x083f219c);
    HOOK_NWMAIN_FUNCTION(CGuiMan__UpdateAndRender,                 0x084b61e4);
}



#define INIT_GLOBAL(global, value)                                  \
    do {                                                            \
        ASSERT(globals.global == NULL || globals.global == value);  \
        globals.global = value;                                     \
    } while (0)

int hook_CNWCMessage__HandleServerToPlayerMessage(void *this, uint8_t *buffer, uint32_t size)
{
    /// @todo Detect custom message to control shaders
    INIT_GLOBAL(CNWCMessage, this);
    return originals.CNWCMessage__HandleServerToPlayerMessage(this, buffer, size);
}

void hook_CGuiMan__UpdateAndRender(void *this, float delta)
{
    INIT_GLOBAL(CGuiMan, this);
    fbo_use(FBO_GUI);
    originals.CGuiMan__UpdateAndRender(this, delta);
    fbo_use(FBO_PRIMARY);
}

int hook_CNWSMessage__SendServerToPlayerMessage(void *this, uint32_t nPlayerId, uint8_t nMajor, uint8_t nMinor, uint8_t *pBuffer, uint32_t nBufferSize)
{
    INIT_GLOBAL(CNWSMessage, this);
    return originals.CNWSMessage__SendServerToPlayerMessage(this, nPlayerId, nMajor, nMinor, pBuffer, nBufferSize);
}

void hook_NWSScriptVarTable__SetString(void *this, const char **varname, const char **value)
{
    if (strncmp(*varname, "NWNX!", 5))
    {
        /// @todo NWNCX hooks.
    }
    return originals.NWSScriptVarTable__SetString(this, varname, value);
}

void SDL_GL_SwapBuffers(void)
{
    fbo_draw();
    originals.SDL_GL_SwapBuffers();
    fbo_use(FBO_PRIMARY);
    framerate_notify_frame();
}
