#ifndef OCWS_GL_HELPERS_H
#define OCWS_GL_HELPERS_H

#include <epoxy/gl.h>
#include <stdio.h>
#include <string.h>

/*
 * gl_helpers.h — Shared OpenGL utility functions for GTK GL applications.
 *
 * Provides shader compilation, program linking, and fullscreen quad setup
 * used by ocws-waveform-gl, ocws-equalizer-gl, ocws-speaker-gl, etc.
 */

/* Compile a single shader (vertex or fragment). Returns the shader handle.
 * Logs compilation errors to stderr. */
static inline GLuint ocws_gl_compile_shader(GLenum type, const char *source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        char log[512];
        glGetShaderInfoLog(shader, sizeof(log), NULL, log);
        fprintf(stderr, "Shader compile error:\n%s\n", log);
    }
    return shader;
}

/* Create and link a shader program from vertex and fragment source strings.
 * Returns the program handle, or 0 on failure. */
static inline GLuint ocws_gl_create_program(const char *vert_src, const char *frag_src) {
    GLuint vs = ocws_gl_compile_shader(GL_VERTEX_SHADER, vert_src);
    GLuint fs = ocws_gl_compile_shader(GL_FRAGMENT_SHADER, frag_src);

    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    GLint linked;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (linked == GL_FALSE) {
        char log[512];
        glGetProgramInfoLog(program, sizeof(log), NULL, log);
        fprintf(stderr, "Program link error:\n%s\n", log);
        glDeleteProgram(program);
        program = 0;
    }

    /* Shaders are linked into the program; copies can be deleted */
    glDeleteShader(vs);
    glDeleteShader(fs);

    return program;
}

/* Set up a fullscreen quad VAO/VBO pair.
 * Returns the VAO handle. Caller must bind it before drawing. */
static inline GLuint ocws_gl_setup_fullscreen_quad(GLuint *vbo_out) {
    /* Two triangles covering clip space [-1,1] */
    static const float quad_vertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };

    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad_vertices), quad_vertices, GL_STATIC_DRAW);

    /* position attribute (location 0): 2 floats */
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);

    glBindVertexArray(0);

    if (vbo_out) *vbo_out = vbo;
    return vao;
}

#endif
