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
    HOOK_LIBRARY_FUNCTION(SDL_SetVideoMode);
    HOOK_LIBRARY_FUNCTION(SDL_PeepEvents);
    HOOK_LIBRARY_FUNCTION(SDL_PollEvent);

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
    if (!strncmp(*varname, "NWNX!", 5))
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

    // Reset input data
    input_data.was_lmb_up = 0;
    input_data.was_rmb_up = 0;
}

void *SDL_SetVideoMode(int width, int height, int bpp, uint32_t flags)
{
    fprintf(logfile, "%s(): width = %d, height = %d, bpp = %d, flags = %08x\n",
        __FUNCTION__, width, height, bpp, flags);

    screen_width = width;
    screen_height = height;
    return originals.SDL_SetVideoMode(width, height, bpp, flags);
}

static void update_input_data(void *sdl_event)
{
    switch (*(uint8_t*)sdl_event)
    {
        case 0x4: // mouse motion
        {
            struct {
                uint8_t type, which, state;
                uint16_t x, y;
                int16_t xrel, yrel;
            } *motion_event = sdl_event;

            input_data.mouse_x = motion_event->x;
            input_data.mouse_y = motion_event->y;
            break;
        }

        case 0x5: // mouse button down
        case 0x6: // mouse button up
        {
            struct {
                uint8_t type, which, button, state;
                uint16_t x, y;
            } *mouse_button_event = sdl_event;

            if (mouse_button_event->button == 1)
            {
                input_data.is_lmb_down = mouse_button_event->state;
                input_data.was_lmb_up  = !mouse_button_event->state;
            }
            else if (mouse_button_event->button == 3)
            {
                input_data.is_rmb_down = mouse_button_event->state;
                input_data.was_rmb_up  = !mouse_button_event->state;
            }
        break;
        }
    }
}

int SDL_PeepEvents(void *events, int numevents, unsigned action, uint32_t mask)
{
    int r = originals.SDL_PeepEvents(events, numevents, action, mask);

    if (action != 0) // Not SDL_ADDEVENT
    {
        for (int i = 0; i < numevents; i++)
            update_input_data(events + i*56);
    }
    return r;
}
int SDL_PollEvent(void *event)
{
    int r = originals.SDL_PollEvent(event);
    update_input_data(event);
    return r;
}
