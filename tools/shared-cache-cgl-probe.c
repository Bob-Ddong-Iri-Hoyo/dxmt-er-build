#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef int (*cgl_get_version_fn)(int *major, int *minor);

int main(void)
{
    static const uintptr_t unslid_CGLGetVersion = 0x7ffb08292803ULL;
    intptr_t slide = 0;
    uint32_t i;
    void *framework;
    int major = 0;
    int minor = 0;
    int result;

    framework = dlopen(
            "/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL",
            RTLD_LOCAL | RTLD_NOW);
    if (!framework)
    {
        fprintf(stderr, "OpenGL dlopen: %s\n", dlerror());
        return 2;
    }

    for (i = 0; i < _dyld_image_count(); ++i)
    {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "OpenGL.framework/Versions/A/Libraries/libGL.dylib"))
        {
            slide = _dyld_get_image_vmaddr_slide(i);
            printf("libGL=%s slide=%#lx\n", name, (long)slide);
            break;
        }
    }

    if (!slide)
    {
        fprintf(stderr, "libGL shared-cache slide not found\n");
        return 3;
    }

    result = ((cgl_get_version_fn)(unslid_CGLGetVersion + slide))(&major, &minor);
    printf("CGLGetVersion result=%d version=%d.%d address=%p\n",
            result, major, minor, (void *)(unslid_CGLGetVersion + slide));
    return result != 0;
}
