/*
 * libiokit_spoof.dylib — interpose IORegistryEntryCreateCFProperty
 * iOS 26.5+ mobileactivationd demotion keys (kebab, :/product).
 *
 * CI: GitHub Actions (.github/workflows/build-ios-patcher.yml)
 * Lab: upload to /mnt2/tmp/ — manual DYLD test on ramdisk (no plist patch by default)
 */
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>
#import <stdint.h>
#import <stdio.h>
#import <string.h>
#import <unistd.h>

extern CFTypeRef IORegistryEntryCreateCFProperty(
    io_registry_entry_t entry,
    CFStringRef key,
    CFAllocatorRef allocator,
    IOOptionBits options);

static CFTypeRef (*orig_IORegistryEntryCreateCFProperty)(
    io_registry_entry_t entry,
    CFStringRef key,
    CFAllocatorRef allocator,
    IOOptionBits options);

/* AP demotion — DeviceType init combo (i11 26.5 mad static trace) */
static int spoof_int_for_key(const char *key) {
    if (!key) return -1;
    if (strcmp(key, "certificate-production-status") == 0) return 0;
    if (strcmp(key, "effective-production-status-ap") == 0) return 1;
    if (strcmp(key, "certificate-security-mode") == 0) return 0;
    if (strcmp(key, "effective-security-mode-sep") == 0) return 0;
    return -1;
}

static CFTypeRef cfdata_for_int(int value, CFAllocatorRef allocator) {
    uint32_t v = (uint32_t)value;
    return CFDataCreate(allocator, (const UInt8 *)&v, sizeof(v));
}

CFTypeRef IORegistryEntryCreateCFProperty_spoof(
    io_registry_entry_t entry,
    CFStringRef key,
    CFAllocatorRef allocator,
    IOOptionBits options) {
    if (key) {
        char buf[128];
        if (CFStringGetCString(key, buf, sizeof(buf), kCFStringEncodingUTF8)) {
            int spoof = spoof_int_for_key(buf);
            if (spoof >= 0) {
                fprintf(stderr, "[iokit_spoof] key=%s -> int %d (AP demotion)\n", buf, spoof);
                return cfdata_for_int(spoof, allocator ? allocator : kCFAllocatorDefault);
            }
        }
    }
    if (!orig_IORegistryEntryCreateCFProperty) {
        orig_IORegistryEntryCreateCFProperty = dlsym(
            RTLD_NEXT, "IORegistryEntryCreateCFProperty");
    }
    if (!orig_IORegistryEntryCreateCFProperty) {
        return NULL;
    }
    return orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
}

typedef struct {
    void *replacement;
    void *replacee;
} interpose_t;

__attribute__((used)) static const interpose_t interposers[]
    __attribute__((section("__DATA,__interpose"))) = {
        { (void *)IORegistryEntryCreateCFProperty_spoof,
          (void *)IORegistryEntryCreateCFProperty },
    };

__attribute__((constructor)) static void iokit_spoof_init(void) {
    orig_IORegistryEntryCreateCFProperty = dlsym(
        RTLD_NEXT, "IORegistryEntryCreateCFProperty");
    fprintf(stderr, "[iokit_spoof] loaded pid=%d\n", getpid());
}
