/*
 * Licensed under GPLv2 or later, see file LICENSE in this source tree.
 *  Copyright (C) 2000, Jan-Derk Bakker (J.D.Bakker@its.tudelft.nl)
 *  Copyright (C) 2008, BusyBox Team. -solar 4/26/08
 */

//usage:#define devmem_trivial_usage
//usage:  "ADDRESS [WIDTH [VALUE]]"
//usage:#define devmem_full_usage "\n\n"
//usage:       "Read/write from physical address\n"
//usage:     "\n  ADDRESS Address to act upon"
//usage:     "\n  WIDTH   Width (8/16/...)"
//usage:     "\n  VALUE   Data to be written"
//usage:     "\n  -r      Read and output only the value in hex, with 0x prefix"
//usage:     "\n  -w      Write only, no read before or after and no output"

#include <ctype.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>

enum {
    DM_READ_ADVANCED = (1 << 0),
    DM_WRITE_ONLY = (1 << 1),
};

int main(int argc, char **argv) {
    uint64_t readval, writeval;
    void *map_base, *virt_addr;
    unsigned page_size, map_size, off_page, width;
    off_t off_addr = 0;
    int fd, flags;

    if (argc < 2) {
        printf("usage: %s [-rw] <address> [<width> <value>]\n", argv[0]);
        return EXIT_FAILURE;
    }

    readval = writeval = flags = 0;

    for(;;) {
        int c = getopt(argc, argv, "rw");
        if(c == -1)
            break;

        switch(c) {
            case 'r':
                flags = DM_READ_ADVANCED;
                break;
            case 'w':
                flags = DM_WRITE_ONLY;
                break;
            case '?': 
                printf("usage: %s [-rw] <address> [<width> <value>]\n", argv[0]);
                break;
            default:
                return EXIT_FAILURE;
        }
    }

    width = 8 * sizeof(int);

    if(optind < argc) /* ADDRESS */
        off_addr = strtoull(argv[optind++], NULL, 0); /* allows hex, oct etc */
    
    /* WIDTH */
    if(optind < argc && argv[optind]) {
        if (isdigit(argv[optind][0]) || argv[optind][1])
            width = atoi(argv[optind]);
        else {
            const char *cptr;
            const char bhwl[] = "bhwl";
            const uint8_t sizes[] = {
                8 * sizeof(char),
                8 * sizeof(short),
                8 * sizeof(int),
                8 * sizeof(long),
                0 /* bad */
            };
            cptr = strchr(bhwl, argv[optind][0] | 0x20);
            if(cptr == NULL)
                cptr = bhwl;

            width = sizes[cptr - bhwl];
        }
        optind++;
        /* VALUE */
        if(optind < argc && argv[optind])
            writeval = strtoull(argv[optind], NULL, 0);
    }

    if(errno) { /* one of bb_strtouXX failed */
        printf("usage: %s [-rw] <address> [<width> <value>]\n", argv[0]);
        return EXIT_FAILURE;
    }

    fd = open("/dev/mem", argv[optind] ? (O_RDWR | O_SYNC) : (O_RDONLY | O_SYNC));
    map_size = page_size = getpagesize();
    off_page = (unsigned)off_addr & (page_size - 1);
    if(off_page + width > page_size) {
        /* This access spans pages. Must map two pages to make it possible: */
        map_size *= 2;
    }
    map_base = mmap(NULL,
            map_size,
            argv[optind] ? (PROT_READ | PROT_WRITE) : PROT_READ,
            MAP_SHARED,
            fd,
            off_addr & ~(off_t)(page_size - 1));
    if (map_base == MAP_FAILED) {
        fprintf(stderr, "mmap failed: %s (%d)\n", strerror(errno), errno);
        goto err_close;
    }

    virt_addr = (char*)map_base + off_page;

    if(argv[optind]) {
        switch (width) {
            case 8: *(volatile uint8_t*)virt_addr = writeval; break;
            case 16: *(volatile uint16_t*)virt_addr = writeval; break;
            case 32: *(volatile uint32_t*)virt_addr = writeval; break;
            case 64: *(volatile uint64_t*)virt_addr = writeval; break;
            default:
                fprintf(stderr, "bad width");
                goto err_unmap;
        }
    }

    if(!(flags & DM_WRITE_ONLY)) {
        switch (width) {
            case 8: readval = *(volatile uint8_t*)virt_addr; break;
            case 16: readval = *(volatile uint16_t*)virt_addr; break;
            case 32: readval = *(volatile uint32_t*)virt_addr; break;
            case 64: readval = *(volatile uint64_t*)virt_addr; break;
            default:
                fprintf(stderr, "bad width");
                goto err_unmap;
        }

        /* Zero-padded output shows the width of access just done */
        if(argv[optind]) {
            printf("Written 0x%llX; readback 0x%llX\n",
                   (unsigned long long)writeval,
                   (unsigned long long)readval);
        } else if(flags & DM_READ_ADVANCED)
            printf("0x%0*llX\n", (width >> 2), (unsigned long long)readval);
        else
            printf("%0*llX\n", (width >> 2), (unsigned long long)readval);
    }

    if (munmap(map_base, map_size) == -1)
        fprintf(stderr, "munmap failed: %s (%d)\n", strerror(errno), errno);

    close(fd);

    return EXIT_SUCCESS;

err_unmap:
    munmap(map_base, map_size);
err_close:
    close(fd);
    return EXIT_FAILURE;
}
