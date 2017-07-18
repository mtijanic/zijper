/**
 * @file
 * @brief   Main client file
 * @author  mtijanic
 * @license GPL-2.0
 */

#include "zijper-client.h"

#include <string.h>
#include <sys/mman.h>
#include <stdlib.h>

void zijper_client_initialize(void) __attribute__((constructor));
void zijper_client_shutdown(void)   __attribute__((destructor));

FILE *logfile;

uint32_t screen_width;
uint32_t screen_height;
struct input_data input_data;

void zijper_client_initialize(void)
{
    if (logfile)
        return;
    logfile = fopen("zijper-client.log", "w");

    ASSERT(logfile);
}
void zijper_client_shutdown(void)
{
    framerate_print_report(logfile);
    fclose(logfile);
    logfile = NULL;
}

void apply_patch(uintptr_t address, const void *patch, size_t patch_size)
{
    zijper_client_initialize();

    uintptr_t page = address & ~0xFFF;
    ASSERT(!mprotect((void*)page, (address - page) + patch_size, PROT_WRITE | PROT_READ | PROT_EXEC));

    fprintf(logfile, "Applying patch at %p\n\tOld data:", (void*)address);
    for (size_t i = 0; i < patch_size; i++)
        fprintf(logfile, " %02x", ((uint8_t*)address)[i]);

    fprintf(logfile, "\n\tNew data:");
    for (size_t i = 0; i < patch_size; i++)
        fprintf(logfile, " %02x", ((uint8_t*)patch)[i]);

    fprintf(logfile, "\n");
    fflush(logfile);

    memcpy((void*)address, patch, patch_size);
}

void *make_detour(void *old_func, void *new_func, size_t bytes_to_copy)
{
    ASSERT(bytes_to_copy >= 5); // JMP+offset to hook

    size_t trampoline_size = bytes_to_copy + 5;

    uint8_t *trampoline = malloc(trampoline_size);
    memcpy(trampoline, old_func, bytes_to_copy);

    trampoline[bytes_to_copy] = 0xe9; // JMP relative
    int32_t offset = ((intptr_t)old_func   + bytes_to_copy) -
                     ((intptr_t)trampoline + trampoline_size);
    memcpy(trampoline + trampoline_size - 4, &offset, 4);

    uint8_t hook[5] = {0xe9};
    offset = new_func - old_func - 5;
    memcpy(&hook[1], &offset, 4);
    apply_patch((uintptr_t)old_func, hook, sizeof(hook));

    ASSERT(!mprotect((void*)((intptr_t)trampoline & ~0xFFF), 0x1000, PROT_READ | PROT_WRITE | PROT_EXEC));

    return trampoline;
}
//
// Weak stubs
// If a C file is removed from compilation, the functions will be stubbed
// and client will work without given functionality
//
__attribute__((weak)) void framerate_notify_frame(void)     { breakpoint(); }
__attribute__((weak)) void framerate_print_report(FILE *f)  { breakpoint(); UNUSED(f); }
__attribute__((weak)) void fbo_draw(void)                   { breakpoint(); }
__attribute__((weak)) void fbo_use(int i)                   { breakpoint(); UNUSED(i); }
