#include <dlfcn.h>
#include <stdio.h>

static void probe(const char *path)
{
    void *handle = dlopen(path, RTLD_LOCAL | RTLD_NOW | RTLD_FIRST);
    if (!handle)
    {
        printf("%s\n  dlopen failed: %s\n", path, dlerror());
        return;
    }

    printf("%s\n", path);
    printf("  handle=%p glClear=%p glDrawElements=%p CGLCreateContext=%p\n",
            handle,
            dlsym(handle, "glClear"),
            dlsym(handle, "glDrawElements"),
            dlsym(handle, "CGLCreateContext"));
}

int main(int argc, char **argv)
{
    probe("/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL");
    probe("/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/libGL.dylib");
    probe("/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/libGLProgrammability.dylib");
    if (argc > 1)
        probe(argv[1]);
    return 0;
}
