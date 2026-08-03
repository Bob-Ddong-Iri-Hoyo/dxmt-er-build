#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <unistd.h>

typedef int (*extract_dylibs_progress_fn)(
        const char *cache_path,
        const char *output_root,
        void (^progress)(unsigned current, unsigned total));

int main(int argc, char **argv)
{
    static const char *relative_target =
            "/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL";
    void *bundle;
    extract_dylibs_progress_fn extract;
    char *target;
    int result;

    if (argc != 4)
    {
        fprintf(stderr, "usage: %s EXTRACTOR_BUNDLE CACHE OUTPUT_ROOT\n", argv[0]);
        return 2;
    }

    if (asprintf(&target, "%s%s", argv[3], relative_target) < 0)
        return 3;

    bundle = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
    if (!bundle)
    {
        fprintf(stderr, "dlopen: %s\n", dlerror());
        free(target);
        return 4;
    }

    extract = (extract_dylibs_progress_fn)dlsym(
            bundle, "dyld_shared_cache_extract_dylibs_progress");
    if (!extract)
    {
        fprintf(stderr, "dlsym: %s\n", dlerror());
        free(target);
        return 5;
    }

    result = extract(argv[2], argv[3], ^(unsigned current, unsigned total) {
        struct stat target_stat;
        struct statvfs fs;

        if ((current % 100) == 0)
            fprintf(stderr, "extracting %u/%u\n", current, total);
        if (stat(target, &target_stat) == 0 && target_stat.st_size > 0)
        {
            fprintf(stderr, "target extracted: %s\n", target);
            fflush(stderr);
            _exit(0);
        }
        if (statvfs(argv[3], &fs) == 0
                && (unsigned long long)fs.f_bavail * fs.f_frsize < 4ULL * 1024 * 1024 * 1024)
        {
            fprintf(stderr, "stopping: less than 4 GiB free\n");
            fflush(stderr);
            _exit(6);
        }
    });

    {
        struct stat target_stat;
        if (stat(target, &target_stat) == 0 && target_stat.st_size > 0)
        fprintf(stderr, "target extracted: %s\n", target);
        else
            fprintf(stderr, "target not found after extraction\n");
    }

    free(target);
    return result;
}
