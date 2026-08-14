/*
 * product_set — read/write IOKit :/product demotion keys (no DYLD, no mad patch)
 *
 * mobileactivationd 26.5 reads via IORegistryEntryFromPath + IORegistryEntryCreateCFProperty.
 * Lab: run from ramdisk BEFORE normal boot to inject CFData ints on :product.
 *
 * CI: gestalt-patcher-ci (.github/workflows/build-ios-patcher.yml)
 */
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

static const char *PRODUCT_PATH = ":/product";

static const struct {
    const char *key;
    int ap_value;
} DEMOTION_KEYS[] = {
    {"certificate-production-status", 0},
    {"effective-production-status-ap", 1},
    {"certificate-security-mode", 0},
    {"effective-security-mode-sep", 0},
};

static io_registry_entry_t open_product(void) {
    io_registry_entry_t product = IORegistryEntryFromPath(kIOMainPortDefault, PRODUCT_PATH);
    if (!product) {
        /* fallback path form seen in some builds */
        product = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product");
    }
    if (!product) {
        fprintf(stderr, "IORegistryEntryFromPath(%s) failed\n", PRODUCT_PATH);
    }
    return product;
}

static CFTypeRef read_property(io_registry_entry_t entry, const char *key) {
    CFStringRef cfkey = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
    CFTypeRef val = IORegistryEntryCreateCFProperty(entry, cfkey, kCFAllocatorDefault, 0);
    CFRelease(cfkey);
    return val;
}

static void print_property(const char *key, CFTypeRef val) {
    if (!val) {
        printf("  %s = (null)\n", key);
        return;
    }
    CFTypeID tid = CFGetTypeID(val);
    if (tid == CFDataGetTypeID()) {
        CFIndex len = CFDataGetLength((CFDataRef)val);
        const UInt8 *bytes = CFDataGetBytePtr((CFDataRef)val);
        printf("  %s = CFData[%ld] ", key, (long)len);
        for (CFIndex i = 0; i < len && i < 8; i++) printf("%02x", bytes[i]);
        if (len >= 4) {
            uint32_t le = 0;
            memcpy(&le, bytes, 4);
            printf(" (uint32_le=%u)", le);
        }
        printf("\n");
    } else if (tid == CFNumberGetTypeID()) {
        int n = 0;
        CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &n);
        printf("  %s = CFNumber(%d)\n", key, n);
    } else {
        printf("  %s = %s\n", key, CFCopyDescription(val));
    }
}

static CFDataRef cfdata_u32(uint32_t v) {
    v = CFSwapInt32HostToLittle(v);
    return CFDataCreate(kCFAllocatorDefault, (const UInt8 *)&v, sizeof(v));
}

static int cmd_read(void) {
    io_registry_entry_t product = open_product();
    if (!product) return 1;
    printf("[read] path=%s entry=0x%x\n", PRODUCT_PATH, product);
    for (size_t i = 0; i < sizeof(DEMOTION_KEYS) / sizeof(DEMOTION_KEYS[0]); i++) {
        CFTypeRef val = read_property(product, DEMOTION_KEYS[i].key);
        print_property(DEMOTION_KEYS[i].key, val);
        if (val) CFRelease(val);
    }
    IOObjectRelease(product);
    return 0;
}

static int cmd_set(void) {
    io_registry_entry_t product = open_product();
    if (!product) return 1;

    CFMutableDictionaryRef props = CFDictionaryCreateMutable(
        kCFAllocatorDefault, 0,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);

    for (size_t i = 0; i < sizeof(DEMOTION_KEYS) / sizeof(DEMOTION_KEYS[0]); i++) {
        CFStringRef cfkey = CFStringCreateWithCString(
            kCFAllocatorDefault, DEMOTION_KEYS[i].key, kCFStringEncodingUTF8);
        CFDataRef data = cfdata_u32((uint32_t)DEMOTION_KEYS[i].ap_value);
        CFDictionarySetValue(props, cfkey, data);
        CFRelease(cfkey);
        CFRelease(data);
    }

    kern_return_t kr = IORegistryEntrySetCFProperties(product, props);
    CFRelease(props);
    printf("[set] IORegistryEntrySetCFProperties kr=0x%x\n", kr);

    for (size_t i = 0; i < sizeof(DEMOTION_KEYS) / sizeof(DEMOTION_KEYS[0]); i++) {
        CFTypeRef val = read_property(product, DEMOTION_KEYS[i].key);
        print_property(DEMOTION_KEYS[i].key, val);
        if (val) CFRelease(val);
    }
    IOObjectRelease(product);
    return (kr == KERN_SUCCESS) ? 0 : 2;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s read|set\n", argv[0]);
        return 1;
    }
    if (strcmp(argv[1], "read") == 0) return cmd_read();
    if (strcmp(argv[1], "set") == 0) return cmd_set();
    fprintf(stderr, "unknown command: %s\n", argv[1]);
    return 1;
}
