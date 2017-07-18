/**
 * @file
 * @brief   Redirect drawing to FBO and apply shaders to it
 * @author  mtijanic
 * @license GPL-2.0
 */
#include "zijper-client.h"
#include "fbo-shader.h"

#include <string.h>

static int fbo_initialized;

struct fbo primary_fbo;
struct fbo gui_fbo;

struct program first_pass_shader;
struct program second_pass_shader;
struct program passthrough_shader;

/// @todo load from environment
// The only thing vertex shader does is pass the coordinates to the fragment shader
static GLuint vertex_shader;
static const char vertex_shader_name[]      = "shaders/zijper.vert";

static const char common_shader_name[]      = "shaders/common.frag";
static GLuint common_shader;

static const char first_pass_shader_name[]  = "shaders/first_pass.frag";
static const char second_pass_shader_name[] = "shaders/second_pass.frag";
static const char passthrough_shader_name[] = "shaders/passthrough.frag";

void fbo_alloc(struct fbo *fbo)
{
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &fbo->texture);
    glBindTexture(GL_TEXTURE_2D, fbo->texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, screen_width, screen_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindTexture(GL_TEXTURE_2D, 0);

    // Depth buffer
    glGenRenderbuffers(1, &fbo->rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, fbo->rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, screen_width, screen_height);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);

    // Frame buffer
    glGenFramebuffers(1, &fbo->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo->fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fbo->texture, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, fbo->rbo);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    ASSERT(status == GL_FRAMEBUFFER_COMPLETE, "%u", status);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    GLfloat vertices[] = {-1, -1, 1, -1, -1, 1, 1, 1};
    glGenBuffers(1, &fbo->vbo);
    glBindBuffer(GL_ARRAY_BUFFER, fbo->vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void fbo_free(struct fbo *fbo)
{
    glDeleteRenderbuffers(1, &fbo->rbo);
    glDeleteTextures(1, &fbo->texture);
    glDeleteFramebuffers(1, &fbo->fbo);
    glDeleteBuffers(1, &fbo->vbo);
}

void fbo_alloc_program(struct program *program, const char *frag)
{
    GLint status;

    ASSERT(program->fragment = create_shader(frag, GL_FRAGMENT_SHADER));
    program->program = glCreateProgram();
    glAttachShader(program->program, vertex_shader);
    glAttachShader(program->program, common_shader);
    glAttachShader(program->program, program->fragment);
    glLinkProgram(program->program);

    glGetProgramiv(program->program, GL_LINK_STATUS, &status);
    ASSERT(status != 0, "%s", print_log(program->program));

    glValidateProgram(program->program);
    glGetProgramiv(program->program, GL_VALIDATE_STATUS, &status);
    ASSERT(status != 0, "%s", print_log(program->program));

    program->attribute.texture_coord = glGetAttribLocation(program->program, "inTexCoord0");
    ASSERT(program->attribute.texture_coord != ~0u, "%s", print_log(program->program));

    program->uniform.texture       = glGetUniformLocation(program->program, "inFboTexture");
    program->uniform.frame_num     = glGetUniformLocation(program->program, "inFrameNum");
    program->uniform.seconds       = glGetUniformLocation(program->program, "inSeconds");
    program->uniform.elapsed_us    = glGetUniformLocation(program->program, "inElapsedUs");
    program->uniform.screen_width  = glGetUniformLocation(program->program, "inScreenWidth");
    program->uniform.screen_height = glGetUniformLocation(program->program, "inScreenHeight");
    program->uniform.mouse_x       = glGetUniformLocation(program->program, "inMouseX");
    program->uniform.mouse_y       = glGetUniformLocation(program->program, "inMouseY");
    program->uniform.is_lmb_down   = glGetUniformLocation(program->program, "inIsLmbDown");
    program->uniform.is_rmb_down   = glGetUniformLocation(program->program, "inIsRmbDown");
    program->uniform.was_lmb_up    = glGetUniformLocation(program->program, "inWasLmbUp");
    program->uniform.was_rmb_up    = glGetUniformLocation(program->program, "inWasRmbUp");
}

void fbo_free_program(struct program *program)
{
    glDetachShader(program->program, vertex_shader);
    glDetachShader(program->program, common_shader);
    glDetachShader(program->program, program->fragment);
    glDeleteShader(program->fragment);
    glDeleteProgram(program->program);
    memset(program, 0, sizeof(*program));
}

void fbo_init(void)
{
    if (fbo_initialized)
        return;

    GLenum status = glewInit();
    ASSERT(status == GLEW_OK, "%s", glewGetErrorString(status));

    vertex_shader = create_shader(vertex_shader_name, GL_VERTEX_SHADER);
    ASSERT(vertex_shader != 0);
    common_shader = create_shader(common_shader_name, GL_FRAGMENT_SHADER);
    ASSERT(common_shader != 0);

    fbo_alloc(&primary_fbo);
    fbo_alloc(&gui_fbo);

    fbo_alloc_program(&first_pass_shader,  first_pass_shader_name);
    fbo_alloc_program(&second_pass_shader, second_pass_shader_name);
    fbo_alloc_program(&passthrough_shader, passthrough_shader_name);

    effects_init();
    fbo_initialized = 1;
}

void fbo_destroy(void) __attribute__((destructor));
void fbo_destroy(void)
{
    effects_destroy();

    fbo_free_program(&first_pass_shader);
    fbo_free_program(&second_pass_shader);
    fbo_free_program(&passthrough_shader);
    fbo_free(&gui_fbo);
    fbo_free(&primary_fbo);

    glDeleteShader(vertex_shader);
    glDeleteShader(common_shader);

    fbo_initialized = 0;
}

void fbo_program_update_uniforms(struct program *program)
{
    glUniform1i(program->uniform.texture,       GL_TEXTURE0);
    glUniform1i(program->uniform.frame_num,     frame_data.total_frames);
    glUniform1i(program->uniform.seconds,       frame_data.last_frame_time.seconds);
    glUniform1i(program->uniform.elapsed_us,    framerate_microseconds_since_last_frame());
    glUniform1i(program->uniform.screen_width,  screen_width);
    glUniform1i(program->uniform.screen_height, screen_height);
    glUniform1i(program->uniform.mouse_x,       input_data.mouse_x);
    glUniform1i(program->uniform.mouse_y,       input_data.mouse_y);
    glUniform1i(program->uniform.is_lmb_down,   input_data.is_lmb_down);
    glUniform1i(program->uniform.is_rmb_down,   input_data.is_rmb_down);
    glUniform1i(program->uniform.was_lmb_up,    input_data.was_lmb_up);
    glUniform1i(program->uniform.was_rmb_up,    input_data.was_rmb_up);
}
void fbo_prepare(struct fbo *fbo)
{
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fbo->texture);
}
void fbo_draw(struct fbo *fbo, GLuint texture_coord)
{
    glEnableVertexAttribArray(texture_coord);
    glBindBuffer(GL_ARRAY_BUFFER, fbo->fbo);
    glVertexAttribPointer(texture_coord, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(texture_coord);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
}
void fbo_draw_with_program(struct fbo *fbo, struct program *program)
{
    glUseProgram(program->program);
    fbo_prepare(fbo);
    fbo_program_update_uniforms(program);
    fbo_draw(fbo, program->attribute.texture_coord);
}

void fbo_draw_all(void)
{
    if (!fbo_initialized)
        return;

    // First pass shader renders back to primary FBO, second pass renders to main FB.
    glBindFramebuffer(GL_FRAMEBUFFER, primary_fbo.fbo);
    fbo_draw_with_program(&primary_fbo, &first_pass_shader);

    effects_apply(&primary_fbo);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    fbo_draw_with_program(&primary_fbo, &second_pass_shader);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    fbo_draw_with_program(&gui_fbo, &passthrough_shader);
}

void fbo_use(int which)
{
    if (!fbo_initialized)
        fbo_init();

    switch (which)
    {
        case FBO_NONE:
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
          break;
        case FBO_PRIMARY:
            glBindFramebuffer(GL_FRAMEBUFFER, primary_fbo.fbo);
          break;
        case FBO_GUI:
            glBindFramebuffer(GL_FRAMEBUFFER, gui_fbo.fbo);
            glClearColor(0.0, 0.0, 0.0, 0.0);
            glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
          break;
        default:
            ASSERT(!"Invalid FBO specified", "%d", which);
          break;
    }
    glUseProgram(0); // Restore fixed function pipeline
}


//
// Weak symbols if effects are not linked in
//
__attribute__((weak)) void effects_init(void)                          { breakpoint(); }
__attribute__((weak)) void effects_destroy(void)                       { breakpoint(); }
__attribute__((weak)) void effects_apply(struct fbo *fbo)              { breakpoint(); UNUSED(fbo); }
__attribute__((weak)) void effects_control(uint8_t cmd, const char *p) { breakpoint(); UNUSED(cmd); UNUSED(p); }
