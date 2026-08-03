#include <errno.h>
#include <fcntl.h>
#include <mach-o/loader.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    struct segment_copy
    {
        struct segment_command_64 *command;
        uint32_t size;
        void *data;
    } segments[16];
    struct mach_header_64 *header;
    struct load_command *command;
    char *segment_start = NULL;
    struct stat st;
    unsigned i;
    unsigned segment_count = 0;
    int fd;
    void *mapping;
    int fixed = 0;

    if (argc != 2)
    {
        fprintf(stderr, "usage: %s MACH_O\n", argv[0]);
        return 2;
    }

    if ((fd = open(argv[1], O_RDWR)) < 0 || fstat(fd, &st) < 0)
    {
        fprintf(stderr, "%s: %s\n", argv[1], strerror(errno));
        return 3;
    }

    mapping = mmap(NULL, st.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mapping == MAP_FAILED)
    {
        fprintf(stderr, "mmap: %s\n", strerror(errno));
        close(fd);
        return 4;
    }

    header = mapping;
    if (header->magic != MH_MAGIC_64)
    {
        fprintf(stderr, "not a 64-bit native-endian Mach-O\n");
        return 5;
    }

    command = (struct load_command *)(header + 1);
    for (i = 0; i < header->ncmds; ++i)
    {
        if (command->cmd == LC_SEGMENT_64)
        {
            struct segment_command_64 *segment = (struct segment_command_64 *)command;
            struct segment_command_64 *copy;

            if (segment_count >= sizeof(segments) / sizeof(segments[0]))
            {
                fprintf(stderr, "too many segments\n");
                return 7;
            }
            if (!segment_start)
                segment_start = (char *)command;
            copy = malloc(command->cmdsize);
            memcpy(copy, command, command->cmdsize);
            segments[segment_count].command = copy;
            segments[segment_count].size = command->cmdsize;
            segments[segment_count].data = malloc(segment->filesize);
            if (segment->fileoff + segment->filesize > (uint64_t)st.st_size)
            {
                fprintf(stderr, "segment outside file\n");
                return 8;
            }
            memcpy(segments[segment_count].data,
                    (char *)mapping + segment->fileoff, segment->filesize);
            ++segment_count;

            if (!strncmp(segment->segname, "__DATA_CONST", sizeof(segment->segname)))
            {
                copy->flags |= SG_READ_ONLY;
                ++fixed;
            }
        }
        command = (struct load_command *)((char *)command + command->cmdsize);
    }

    for (i = 0; i < segment_count; ++i)
    {
        unsigned j;
        for (j = i + 1; j < segment_count; ++j)
        {
            if (segments[j].command->vmaddr < segments[i].command->vmaddr)
            {
                struct segment_copy temporary = segments[i];
                segments[i] = segments[j];
                segments[j] = temporary;
            }
        }
    }

    {
        uint64_t next_fileoff = 0;
        char *destination = segment_start;
        for (i = 0; i < segment_count; ++i)
        {
            struct segment_command_64 *segment = segments[i].command;
            struct section_64 *section = (struct section_64 *)(segment + 1);
            uint64_t old_fileoff = segment->fileoff;
            uint64_t section_index;

            for (section_index = 0; section_index < segment->nsects; ++section_index)
            {
                if (section[section_index].offset >= old_fileoff
                        && section[section_index].offset < old_fileoff + segment->filesize)
                {
                    section[section_index].offset =
                            next_fileoff + section[section_index].offset - old_fileoff;
                }
            }
            segment->fileoff = next_fileoff;
            memcpy((char *)mapping + next_fileoff,
                    segments[i].data, segment->filesize);
            next_fileoff += segment->filesize;

            memcpy(destination, segments[i].command, segments[i].size);
            destination += segments[i].size;
            free(segments[i].data);
            free(segments[i].command);
        }
    }

    msync(mapping, st.st_size, MS_SYNC);
    munmap(mapping, st.st_size);
    close(fd);
    printf("fixed %d __DATA_CONST segment(s)\n", fixed);
    return fixed ? 0 : 6;
}
