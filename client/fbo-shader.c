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


GLuint fbo;                 // Main framebuffer object
GLuint rbo_depth;           // Depth renderbuffer
GLuint texture_fbo;         // Texture of the FBO where everything is drawn to
GLuint vbo_vertices_fbo;    // Vertices the FBO texture will be rendered on
GLuint program;             // Shaders program to apply to FBO texture

GLuint attribute_v_coord;   // Vertex location attribute
GLuint uniform_texture_fbo; // GLSL binding for texture_fbo
GLuint uniform_offset;      // Incremented every frame, for test wobble effect

/// @todo load from environment
static const char vertex_shader_name[]   = "shaders/zijper.vert";
static const char fragment_shader_name[] = "shaders/zijper.frag";

// Utilities from openGL tutorials
GLuint create_shader(const char* filename, GLenum type);

void fbo_init(void)
{
    /// @todo Get width/height dynamically
    const GLsizei screen_width  = 1920;
    const GLsizei screen_height = 1080;
    GLenum status;

    status = glewInit();
    ASSERT(status == GLEW_OK, "%s", glewGetErrorString(status));

    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &texture_fbo);
    glBindTexture(GL_TEXTURE_2D, texture_fbo);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, screen_width, screen_height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindTexture(GL_TEXTURE_2D, 0);

    // Depth buffer
    glGenRenderbuffers(1, &rbo_depth);
    glBindRenderbuffer(GL_RENDERBUFFER, rbo_depth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, screen_width, screen_height);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);

    // Frame buffer
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture_fbo, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, rbo_depth);

    status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    ASSERT(status == GL_FRAMEBUFFER_COMPLETE, "%u", status);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    GLfloat fbo_vertices[] = {-1, -1, 1, -1, -1, 1, 1, 1};
    glGenBuffers(1, &vbo_vertices_fbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_vertices_fbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(fbo_vertices), fbo_vertices, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    GLuint vs, fs;
    ASSERT(vs = create_shader(vertex_shader_name,   GL_VERTEX_SHADER));
    ASSERT(fs = create_shader(fragment_shader_name, GL_FRAGMENT_SHADER));

    program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    glGetProgramiv(program, GL_LINK_STATUS, &status);
    ASSERT(status != 0, "%u", status);

    glValidateProgram(program);
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    ASSERT(status != 0, "%u", status);

    attribute_v_coord = glGetAttribLocation(program, "v_coord");
    ASSERT(attribute_v_coord != -1);

    uniform_texture_fbo = glGetUniformLocation(program, "texture_fbo");
    ASSERT(uniform_texture_fbo != -1);

    uniform_offset = glGetUniformLocation(program, "offset");
    ASSERT(uniform_offset != -1);
}

void fbo_destroy(void)
{
    glDeleteRenderbuffers(1, &rbo_depth);
    glDeleteTextures(1, &texture_fbo);
    glDeleteFramebuffers(1, &fbo);
    glDeleteBuffers(1, &vbo_vertices_fbo);
}


void fbo_draw(void)
{
    // @todo Maybe store the state here so it doesn't get corrupted?
    //glPushAttrib(GL_ALL_ATTRIB_BITS);
    //glPushMatrix();
    if (fbo == 0)
        return;

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    glUseProgram(program);
    glActiveTexture(GL_TEXTURE0);

    glBindTexture(GL_TEXTURE_2D, texture_fbo);
    glUniform1i(uniform_texture_fbo, GL_TEXTURE0);
    glEnableVertexAttribArray(attribute_v_coord);

    /// @todo This is only for the test effect
    static GLfloat move = 0;
    move += 0.01f;
    glUniform1f(uniform_offset, move);

    glBindBuffer(GL_ARRAY_BUFFER, vbo_vertices_fbo);
    glVertexAttribPointer(attribute_v_coord, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(attribute_v_coord);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void fbo_use(void)
{
    if (fbo == 0)
        fbo_init();

    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    //glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    glUseProgram(0); // Restore fixed function pipeline
    //glPopMatrix();
    //glPopAttrib();
}
