/**
 * @file
 * @brief   Functions for hooking into the main executable
 * @author  mtijanic
 * @license GPL-2.0
 */

#ifndef ZIJPER_NWMAIN_HOOKS_H
#define ZIJPER_NWMAIN_HOOKS_H


struct functions
{
    // Library functions called from nwmain
    void  (*SDL_GL_SwapBuffers)(void);
    void *(*SDL_SetVideoMode)(int width, int height, int bpp, uint32_t flags);

    // Functions defined in nwmain
    void (*CGuiMan__UpdateAndRender)(void* this, float delta);
    int  (*CNWCMessage__HandleServerToPlayerMessage)(void *this, uint8_t *buffer, uint32_t size);
    int  (*CNWSMessage__SendServerToPlayerMessage)(void *this, uint32_t nPlayerId, uint8_t nMajor, uint8_t nMinor, uint8_t *pBuffer, uint32_t nBufferSize);
    void (*NWSScriptVarTable__SetString)(void *this, const char **varname, const char **value);
};

/// @brief Bypasses custom logic in the hooks
extern struct functions originals;
/// @brief Includes custom logic in the hooks
extern struct functions wrappers;

struct globals
{
    void *CNWSMessage;
    void *CNWCMessage;
    void *CGuiMan;
};
extern struct globals globals;

void nwmain_hooks_initialize(void) __attribute__((constructor));

#endif
