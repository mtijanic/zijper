/**
 * @file
 * @brief   Redirect drawing to FBO and apply shaders to it
 * @author  mtijanic
 * @license GPL-2.0
 */

#include "zijper-client.h"

#define GL_GLEXT_PROTOTYPES 1
#include <GL/glew.h>
#include <GL/glut.h>
#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glcorearb.h>

#include <string.h>

static int fbo_initialized;

struct fbo
{
    GLuint fbo;      // Framebuffer object
    GLuint rbo;      // Depth renderbuffer
    GLuint vbo;      // Vertices the FBO texture will be rendered on
    GLuint texture;  // Texture of the FBO where everything is drawn to
};

struct fbo primary_fbo;
struct fbo gui_fbo;

struct program
{
    GLuint program;
    GLuint fragment;

    struct
    {
        GLuint texture_coord;
    } attribute;
    struct
    {
        GLuint texture;
        GLuint frame_num;
        GLuint seconds;  // Total system uptime
        GLuint elapsed_us; // Since last frame
        GLuint screen_width;
        GLuint screen_height;
    } uniform;
};

struct program first_pass_shader;
struct program second_pass_shader;
struct program passthrough_shader;


/// @todo load from environment
// The only thing vertex shader does is pass the coordinates to the fragment shader
static GLuint vertex_shader;
static const char vertex_shader_name[]   = "shaders/zijper.vert";

static const char common_shader_name[]     = "shaders/common.frag";
static GLuint common_shader;

static const char first_pass_shader_name[]  = "shaders/first_pass.frag";
static const char second_pass_shader_name[] = "shaders/second_pass.frag";
static const char passthrough_shader_name[] = "shaders/passthrough.frag";

// Utilities from openGL tutorials
GLuint create_shader(const char* filename, GLenum type);
char *print_log(GLuint object);

/// @todo Get width/height dynamically
GLsizei screen_width  = 1920;
GLsizei screen_height = 1080;

static void fbo_alloc(struct fbo *fbo)
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

static void fbo_free(struct fbo *fbo)
{
    glDeleteRenderbuffers(1, &fbo->rbo);
    glDeleteTextures(1, &fbo->texture);
    glDeleteFramebuffers(1, &fbo->fbo);
    glDeleteBuffers(1, &fbo->vbo);
}

static void fbo_alloc_program(struct program *program, const char *frag)
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
    ASSERT(program->attribute.texture_coord != ~0u);

    program->uniform.texture       = glGetUniformLocation(program->program, "inFboTexture");
    program->uniform.frame_num     = glGetUniformLocation(program->program, "inFrameNum");
    program->uniform.seconds       = glGetUniformLocation(program->program, "inSeconds");
    program->uniform.elapsed_us    = glGetUniformLocation(program->program, "inElapsedUs");
    program->uniform.screen_width  = glGetUniformLocation(program->program, "inScreenWidth");
    program->uniform.screen_height = glGetUniformLocation(program->program, "inScreenHeight");
}

static void fbo_free_program(struct program *program)
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

    fbo_alloc_program(&first_pass_shader, first_pass_shader_name);
    fbo_alloc_program(&second_pass_shader, second_pass_shader_name);
    fbo_alloc_program(&passthrough_shader, passthrough_shader_name);

    fbo_initialized = 1;
}

void fbo_destroy(void) __attribute__((destructor));
void fbo_destroy(void)
{
    fbo_free_program(&first_pass_shader);
    fbo_free_program(&passthrough_shader);
    fbo_free(&gui_fbo);
    fbo_free(&primary_fbo);

    glDeleteShader(vertex_shader);

    fbo_initialized = 0;
}

static void draw_fbo_with_program(struct fbo *fbo, struct program *program)
{
    //glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    glUseProgram(program->program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fbo->texture);

    glUniform1i(program->uniform.texture,       GL_TEXTURE0);
    glUniform1i(program->uniform.frame_num,     frame_data.total_frames);
    glUniform1i(program->uniform.seconds,       frame_data.last_frame_time.seconds);
    glUniform1i(program->uniform.elapsed_us,    framerate_microseconds_since_last_frame());
    glUniform1i(program->uniform.screen_width,  screen_width);
    glUniform1i(program->uniform.screen_height, screen_height);

    glEnableVertexAttribArray(program->attribute.texture_coord);
    glBindBuffer(GL_ARRAY_BUFFER, fbo->fbo);
    glVertexAttribPointer(program->attribute.texture_coord, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(program->attribute.texture_coord);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void fbo_draw(void)
{
    // @todo Maybe store the state here so it doesn't get corrupted?
    //glPushAttrib(GL_ALL_ATTRIB_BITS);
    //glPushMatrix();
    if (!fbo_initialized)
        return;

    // First pass shader renders back to primary FBO, second pass renders to main FB.
    glBindFramebuffer(GL_FRAMEBUFFER, primary_fbo.fbo);
    draw_fbo_with_program(&primary_fbo, &first_pass_shader);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

    draw_fbo_with_program(&primary_fbo, &second_pass_shader);

    draw_fbo_with_program(&gui_fbo, &passthrough_shader);
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
            ASSERT(0, "%d", which);
          break;
    }
    glUseProgram(0); // Restore fixed function pipeline
    //glPopMatrix();
    //glPopAttrib();
}
