/**
 * @file
 * @brief   Shader and FBO related definitions
 * @author  mtijanic
 * @license GPL-2.0
 */

#ifndef ZIJPER_FBO_SHADER_H
#define ZIJPER_FBO_SHADER_H

#define GL_GLEXT_PROTOTYPES 1
#include <GL/glew.h>


struct fbo
{
    GLuint fbo;      // Framebuffer object
    GLuint rbo;      // Depth renderbuffer
    GLuint vbo;      // Vertices the FBO texture will be rendered on
    GLuint texture;  // Texture of the FBO where everything is drawn to
};

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
        GLuint mouse_x;
        GLuint mouse_y;
        GLuint is_lmb_down;
        GLuint is_rmb_down;
        GLuint was_lmb_up;
        GLuint was_rmb_up;
    } uniform;
};


extern struct fbo primary_fbo;
extern struct fbo gui_fbo;
extern struct fbo skybox_fbo;

extern struct program first_pass_shader;
extern struct program second_pass_shader;
extern struct program passthrough_shader;
extern struct program skybox_shader;

void fbo_alloc(struct fbo *fbo);
void fbo_free(struct fbo *fbo);
void fbo_alloc_program(struct program *program, const char *fragment_shader_path);
void fbo_free_program(struct program *program);

void fbo_program_update_uniforms(struct program *program);
void fbo_prepare(struct fbo *fbo);
void fbo_draw(struct fbo *fbo, GLuint texture_coord);
void fbo_draw_with_program(struct fbo *fbo, struct program *program);
void fbo_draw_all(void);
void fbo_use(int which);


void effects_init(void);
void effects_destroy(void);
void effects_apply(struct fbo *fbo);
void effects_control(uint8_t cmd, const char *param);


// Utilities from openGL tutorials
GLuint create_shader(const char *filename, GLenum type);
char *print_log(GLuint object);

#endif
