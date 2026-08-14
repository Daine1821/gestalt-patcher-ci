//
// poc.m — GestaltHax v2 (hanakim3945/gestalt_hax_v2)
// Lab: discover gestalt_key_offset + patch MobileGestalt CacheData on-device.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#import <Foundation/Foundation.h>
#import <mach-o/getsect.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

off_t find_offset(const char *mgKey) {
    printf("\n--- Finding offset for key: '%s' ---\n", mgKey);

    const struct mach_header_64 *header = NULL;
    const char *mgName = "/usr/lib/libMobileGestalt.dylib";

    dlopen(mgName, RTLD_GLOBAL);

    for (int i = 0; i < _dyld_image_count(); i++) {
        if (!strncmp(mgName, _dyld_get_image_name(i), strlen(mgName))) {
            header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            break;
        }
    }

    if (!header) {
        fprintf(stderr, "ERROR: libMobileGestalt.dylib not loaded\n");
        return -1;
    }

    size_t textCStringSize;
    const char *textCStringSection =
        (const char *)getsectiondata(header, "__TEXT", "__cstring", &textCStringSize);

    const char *string_address = NULL;
    for (size_t size = 0; size < textCStringSize; size += strlen(textCStringSection + size) + 1) {
        if (!strncmp(mgKey, textCStringSection + size, strlen(mgKey))) {
            string_address = textCStringSection + size;
            textCStringSection += size;
            break;
        }
    }

    if (!string_address) {
        fprintf(stderr, "ERROR: key '%s' not found in __TEXT.__cstring\n", mgKey);
        return -1;
    }

    size_t constSize;
    const char *const_section_name = "__AUTH_CONST";
    const uintptr_t *constSection =
        (const uintptr_t *)getsectiondata(header, "__AUTH_CONST", "__const", &constSize);

    if (!constSection) {
        const_section_name = "__DATA_CONST";
        constSection = (const uintptr_t *)getsectiondata(header, "__DATA_CONST", "__const", &constSize);
    }

    if (!constSection) {
        fprintf(stderr, "ERROR: __const section not found\n");
        return -1;
    }

    for (int i = 0; i < (int)(constSize / sizeof(uintptr_t)); i++) {
        if (constSection[i] == (uintptr_t)textCStringSection) {
            constSection += i;
            break;
        }
    }

    uint16_t raw_value = ((uint16_t *)constSection)[0x9a / 2];
    off_t offset = (off_t)raw_value;

    printf("Key '%s' -> gestalt_key_offset = 0x%llx (%llu)\n",
           mgKey, (unsigned long long)offset, (unsigned long long)offset);
    return offset;
}

off_t find_pattern_offset(const unsigned char *buffer, size_t size, int n) {
    const unsigned char pattern[] = {0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00};
    const size_t pattern_len = sizeof(pattern);
    int found_count = 0;

    if (size < pattern_len) {
        return -1;
    }

    for (size_t offset = 0; offset <= size - pattern_len; ++offset) {
        if (memcmp(buffer + offset, pattern, pattern_len) == 0) {
            found_count++;
            if (found_count == n) {
                return (off_t)offset;
            }
        }
    }
    return -1;
}

typedef struct {
    const char *label;
    const char *obfuscated_string;
} PatchEntry;

void patch_buffer(unsigned char *buffer, size_t size) {
    if (!buffer || size == 0) {
        fprintf(stderr, "Invalid buffer or size.\n");
        return;
    }

    PatchEntry patches[] = {
        {"EffectiveSecurityModeAp", "vENa/R1xAXLobl8r3PBL6w"},
    };
    size_t num_patches = sizeof(patches) / sizeof(patches[0]);

    off_t pattern_offset = find_pattern_offset(buffer, size, 2);
    if (pattern_offset == -1) {
        printf("ERROR: 2nd pattern FFFFFFFF00000000 not found.\n");
        return;
    }

    printf("2nd pattern at offset 0x%llx\n", (unsigned long long)pattern_offset);

    for (size_t i = 0; i < num_patches; ++i) {
        off_t gestalt_key_offset = find_offset(patches[i].obfuscated_string);
        if (gestalt_key_offset == -1) {
            continue;
        }

        off_t final_patch_offset = pattern_offset + 7 + gestalt_key_offset;
        printf("Final patch: pattern(0x%llx) + 7 + key(0x%llx) = 0x%llx\n",
               (unsigned long long)pattern_offset,
               (unsigned long long)gestalt_key_offset,
               (unsigned long long)final_patch_offset);

        if (final_patch_offset >= (off_t)size) {
            fprintf(stderr, "ERROR: final offset out of range\n");
            continue;
        }

        unsigned char old = buffer[final_patch_offset];
        buffer[final_patch_offset] = 0x01;
        printf("PATCH %s @0x%llx: 0x%02x -> 0x01\n",
               patches[i].label,
               (unsigned long long)final_patch_offset,
               old);
    }
}

@interface PlistModifier : NSObject
- (void)modifyPlistAtPath:(NSString *)path;
@end

@implementation PlistModifier

- (NSData *)modifyCacheData:(NSData *)cacheData {
    if (!cacheData || [cacheData length] == 0) {
        return cacheData;
    }

    NSUInteger len = [cacheData length];
    unsigned char *buffer = malloc(len);
    if (!buffer) {
        return cacheData;
    }
    [cacheData getBytes:buffer length:len];
    patch_buffer(buffer, len);
    NSData *modifiedData = [NSData dataWithBytes:buffer length:len];
    free(buffer);
    return modifiedData;
}

- (void)modifyPlistAtPath:(NSString *)path {
    NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
    if (!plistDict) {
        fprintf(stderr, "Failed to load plist: %s\n", [path UTF8String]);
        return;
    }

    NSData *cacheData = plistDict[@"CacheData"];
    if (!cacheData || ![cacheData isKindOfClass:[NSData class]]) {
        fprintf(stderr, "Missing CacheData\n");
        return;
    }

    plistDict[@"CacheData"] = [self modifyCacheData:cacheData];

    if ([plistDict writeToFile:path atomically:YES]) {
        printf("Saved patched plist -> %s\n", [path UTF8String]);
    } else {
        fprintf(stderr, "Failed to save plist\n");
    }
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "Usage: %s <path_to_com.apple.MobileGestalt.plist>\n", argv[0]);
            return 1;
        }

        NSString *plistPath = [NSString stringWithUTF8String:argv[1]];
        PlistModifier *modifier = [[PlistModifier alloc] init];
        [modifier modifyPlistAtPath:plistPath];
    }
    return 0;
}
