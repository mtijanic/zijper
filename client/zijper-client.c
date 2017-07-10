/**
 * @file
 * @brief   Main client file
 * @author  mtijanic
 * @license GPL-2.0
 */

#include "zijper-client.h"

#include <string.h>
#include <sys/mman.h>

void zijper_client_initialize(void) __attribute__((constructor));
void zijper_client_shutdown(void)   __attribute__((destructor));

FILE *logfile;

void zijper_client_initialize(void)
{
    if (logfile)
        return;
    logfile = fopen("zijper-client.log", "w");
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
    if (mprotect((void*)page, (address - page) + patch_size, PROT_WRITE | PROT_READ | PROT_EXEC))
    {
        perror("mprotect");
        ASSERT(0, "mprotect failure");
        return;
    }

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

//
// Weak stubs
// If a C file is removed from compilation, the functions will be stubbed
// and client will work without given functionality
//
__attribute__((weak)) void framerate_notify_frame(void)     { }
__attribute__((weak)) void framerate_print_report(FILE *f)  { }
__attribute__((weak)) void fbo_draw(void)                   { }
__attribute__((weak)) void fbo_use(void)                    { }
__attribute__((weak)) void fbo_init(void)                   { }
__attribute__((weak)) void fbo_destroy(void)                { }
