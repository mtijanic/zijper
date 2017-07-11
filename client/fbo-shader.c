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

struct shader
{
    GLuint program;
    GLuint vertex;
    GLuint fragment;

    struct
    {
        GLuint v_coord;
    } attribute;
    struct
    {
        GLuint texture_primary;
        GLuint texture_gui;
        GLuint frame_num;
        GLuint seconds;
        GLuint offset; /// @todo temporary for test shaders
    } uniform;
    const char *vertex_name;
    const char *fragment_name;
};

struct shader primary_shader;


/// @todo load from environment
static const char vertex_shader_name[]   = "shaders/zijper.vert";
static const char fragment_shader_name[] = "shaders/zijper.frag";

// Utilities from openGL tutorials
GLuint create_shader(const char* filename, GLenum type);

/// @todo Get width/height dynamically
GLsizei screen_width  = 1920;
GLsizei screen_height = 1080;

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

void fbo_alloc_shader(struct shader *shader, const char *vert, const char *frag)
{
    GLint status;

    ASSERT(shader->vertex   = create_shader(vert, GL_VERTEX_SHADER));
    ASSERT(shader->fragment = create_shader(frag, GL_FRAGMENT_SHADER));

    shader->program = glCreateProgram();
    glAttachShader(shader->program, shader->vertex);
    glAttachShader(shader->program, shader->fragment);
    glLinkProgram(shader->program);

    glGetProgramiv(shader->program, GL_LINK_STATUS, &status);
    ASSERT(status != 0, "%d", status);

    glValidateProgram(shader->program);
    glGetProgramiv(shader->program, GL_VALIDATE_STATUS, &status);
    ASSERT(status != 0, "%d", status);

    shader->attribute.v_coord = glGetAttribLocation(shader->program, "v_coord");
    ASSERT(shader->attribute.v_coord != ~0u);

    shader->uniform.texture_primary = glGetUniformLocation(shader->program, "fbo_texture");
    ASSERT(shader->uniform.texture_primary != ~0u);

    shader->uniform.offset = glGetUniformLocation(shader->program, "offset");
    ASSERT(shader->uniform.offset != ~0u);
}

void fbo_free_shader(struct shader *shader)
{
    (void)sizeof(shader);
    /// @todo implement
}

void fbo_init(void)
{
    GLenum status = glewInit();
    ASSERT(status == GLEW_OK, "%s", glewGetErrorString(status));

    fbo_alloc(&primary_fbo);
    fbo_alloc(&gui_fbo);

    fbo_alloc_shader(&primary_shader, vertex_shader_name, fragment_shader_name);

    fbo_initialized = 1;
}

void fbo_destroy(void) __attribute__((destructor));
void fbo_destroy(void)
{
    fbo_free_shader(&primary_shader);
    fbo_free(&gui_fbo);
    fbo_free(&primary_fbo);
}


void fbo_draw(void)
{
    // @todo Maybe store the state here so it doesn't get corrupted?
    //glPushAttrib(GL_ALL_ATTRIB_BITS);
    //glPushMatrix();
    if (!fbo_initialized)
        return;

    /// @todo This is only for the test effect
    static GLfloat move = 0;
    move += 0.01f;

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    glUseProgram(primary_shader.program);
    glActiveTexture(GL_TEXTURE0);
    glUniform1f(primary_shader.uniform.offset, move);

    glBindTexture(GL_TEXTURE_2D, primary_fbo.texture);
    glUniform1i(primary_shader.uniform.texture_primary, GL_TEXTURE0);
    glEnableVertexAttribArray(primary_shader.attribute.v_coord);

    glBindBuffer(GL_ARRAY_BUFFER, primary_fbo.fbo);
    glVertexAttribPointer(primary_shader.attribute.v_coord, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(primary_shader.attribute.v_coord);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

}

void fbo_use(int which)
{
    if (!fbo_initialized)
        fbo_init();

    switch (which)
    {
        case FBO_NONE:    glBindFramebuffer(GL_FRAMEBUFFER, 0);                break;
        case FBO_PRIMARY: glBindFramebuffer(GL_FRAMEBUFFER, primary_fbo.fbo);  break;
        case FBO_GUI:     glBindFramebuffer(GL_FRAMEBUFFER, gui_fbo.fbo);      break;
        default:
            ASSERT(0, "%d", which);
            break;
    }
    //glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    glUseProgram(0); // Restore fixed function pipeline
    //glPopMatrix();
    //glPopAttrib();
}
