#define GL_SILENCE_DEPRECATION

#include <stddef.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl.h>

int main(void)
{
    CGLPixelFormatAttribute attributes[] = {
        kCGLPFAAccelerated,
        kCGLPFAColorSize,
        (CGLPixelFormatAttribute)24,
        (CGLPixelFormatAttribute)0,
    };
    CGLPixelFormatObj pixel_format = NULL;
    CGLContextObj context = NULL;
    GLint count = 0;

    if (CGLChoosePixelFormat(attributes, &pixel_format, &count) != kCGLNoError)
        return 1;
    if (CGLCreateContext(pixel_format, NULL, &context) != kCGLNoError)
        return 2;

    CGLSetCurrentContext(context);
    glViewport(0, 0, 16, 16);
    glClearColor(0.25f, 0.5f, 0.75f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glFinish();

    CGLSetCurrentContext(NULL);
    CGLDestroyContext(context);
    CGLDestroyPixelFormat(pixel_format);
    return 0;
}
