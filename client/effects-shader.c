/**
 * @file
 * @brief   Special effects shader functions
 * @author  mtijanic
 * @license GPL-2.0
 */

#include "zijper-client.h"
#include "fbo-shader.h"

#include <stdio.h>
#include <string.h>

enum {
    EFFECT_CLEAR_ALL,
    EFFECT_RED_FOG,
    EFFECT_SCREEN_SHAKE,
    EFFECT_GRAYSCALE,
    EFFECT_SHADOWREALM,
    EFFECT_UNDERWATER,
    EFFECT_BLUR,
    EFFECT_COUNT
};

struct {
    uint64_t usec_remaining;
    float    intensity;
    GLuint   uniform_intensity;
} effects[EFFECT_COUNT];

// Number of effects still active. Skip effect_shader if zero.
static int active_effects;

struct program effect_shader;


void effects_control(uint8_t cmd, const char *param)
{
    int check;
    if (cmd >= EFFECT_COUNT)
    {
        ASSERT(!"Invalid cmd received", "%u", cmd);
        return;
    }
    ASSERT(param != NULL);

    int temporary = *param == 'T';
    int permanent = *param == 'P';
    int cancel    = *param == 'C';
    param += 2;

    if (cmd == EFFECT_CLEAR_ALL)
    {
        for (int i = 0; i < EFFECT_COUNT; i++)
        {
            effects[i].usec_remaining = 0;
            effects[i].intensity      = 0.0f;
        }
        return;
    }

    ASSERT(temporary || permanent || cancel);

    if (cancel)
    {
        effects[cmd].usec_remaining = 0;
        effects[cmd].intensity      = 0.0f;
        return;
    }

    check = sscanf(param, "%f#", &effects[cmd].intensity);
    ASSERT(check && "Failed to read intensity from param", "param=%s", param);
    param = strstr(param, "#") + 1;

    uint64_t usec_remaining = ~0ull;
    if (temporary)
    {
        float duration;
        check = sscanf(param, "%f#", &duration);
        ASSERT(check && "Failed to read duration from param", "param=%s", param);
        param = strstr(param, "#") + 1;
        usec_remaining = (uint64_t)(duration * 1000000.0);
    }
    if (effects[cmd].usec_remaining == 0)
        active_effects++;
    effects[cmd].usec_remaining = usec_remaining;

}


#define INIT_UNIFORM(eff, name) \
    effects[eff].uniform_intensity = glGetUniformLocation(effect_shader.program, name)
void effects_init(void)
{
    fbo_alloc_program(&effect_shader, "shaders/effects.frag");

    INIT_UNIFORM(EFFECT_RED_FOG,      "effIntensityRedFog");
    INIT_UNIFORM(EFFECT_SCREEN_SHAKE, "effIntensityScreenShake");
    INIT_UNIFORM(EFFECT_GRAYSCALE,    "effIntensityGrayscale");
    INIT_UNIFORM(EFFECT_SHADOWREALM,  "effIntensityShadowrealm");
    INIT_UNIFORM(EFFECT_UNDERWATER,   "effIntensityUnderwater");
    INIT_UNIFORM(EFFECT_BLUR,         "effIntensityBlur");
}
void effects_destroy(void)
{
    fbo_free_program(&effect_shader);
}

void effects_tick(uint32_t elapsed_us)
{
    if (active_effects == 0)
        return;

    for (int i = 0; i < EFFECT_COUNT; i++)
    {
        if (effects[i].usec_remaining > elapsed_us)
        {
            // Gradually drop intensity
            effects[i].intensity *= 1.0 - ((double)elapsed_us / effects[i].usec_remaining);
            effects[i].usec_remaining -= elapsed_us;
        }
        else if (effects[i].usec_remaining > 0)
        {
            active_effects--;
            effects[i].usec_remaining = 0;
            effects[i].intensity = 0.0f;
        }
    }
}

void effects_apply(struct fbo *fbo)
{
    effects_tick(framerate_microseconds_since_last_frame());

    if (active_effects == 0)
        return;

    glUseProgram(effect_shader.program);
    fbo_prepare(fbo);
    fbo_program_update_uniforms(&effect_shader);

    for (int i = 0; i < EFFECT_COUNT; i++)
    {
        glUniform1f(effects[i].uniform_intensity, effects[i].intensity);
    }

    glFinish(); // Wait for previous shader to finish, so there's no tearing.
    fbo_draw(fbo, effect_shader.attribute.texture_coord);
}
