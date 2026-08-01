#import "KeyboardBacklightBridge.h"

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <math.h>
#import <objc/message.h>

@interface AESKeyboardBacklightContext : NSObject
@property(nonatomic, strong) id client;
@property(nonatomic) uint64_t keyboardID;
@end

@implementation AESKeyboardBacklightContext
@end

static BOOL AESLoadCoreBrightness(void) {
    static BOOL attempted = NO;
    static BOOL loaded = NO;

    @synchronized([AESKeyboardBacklightContext class]) {
        if (!attempted) {
            attempted = YES;
            const char *paths[] = {
                "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
                "/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness"
            };

            for (size_t index = 0; index < sizeof(paths) / sizeof(paths[0]); index++) {
                if (dlopen(paths[index], RTLD_NOW | RTLD_LOCAL) != NULL) {
                    loaded = YES;
                    break;
                }
            }
        }
    }

    return loaded;
}

AESKeyboardBacklightHandle AESKeyboardBacklightCreate(void) {
    if (!AESLoadCoreBrightness()) {
        return NULL;
    }

    Class clientClass = NSClassFromString(@"KeyboardBrightnessClient");
    if (clientClass == Nil) {
        return NULL;
    }

    id client = [[clientClass alloc] init];
    SEL copyIDsSelector = NSSelectorFromString(@"copyKeyboardBacklightIDs");
    SEL builtInSelector = NSSelectorFromString(@"isKeyboardBuiltIn:");
    SEL brightnessSelector = NSSelectorFromString(@"brightnessForKeyboard:");
    SEL setBrightnessSelector = NSSelectorFromString(@"setBrightness:forKeyboard:");

    if (client == nil
        || ![client respondsToSelector:copyIDsSelector]
        || ![client respondsToSelector:builtInSelector]
        || ![client respondsToSelector:brightnessSelector]
        || ![client respondsToSelector:setBrightnessSelector]) {
        return NULL;
    }

    NSArray<NSNumber *> *keyboardIDs =
        ((NSArray<NSNumber *> *(*)(id, SEL))objc_msgSend)(client, copyIDsSelector);
    NSNumber *builtInKeyboardID = nil;

    for (NSNumber *keyboardID in keyboardIDs) {
        BOOL isBuiltIn = ((BOOL (*)(id, SEL, uint64_t))objc_msgSend)(
            client,
            builtInSelector,
            keyboardID.unsignedLongLongValue
        );
        if (isBuiltIn) {
            builtInKeyboardID = keyboardID;
            break;
        }
    }

    if (builtInKeyboardID == nil) {
        return NULL;
    }

    AESKeyboardBacklightContext *context = [[AESKeyboardBacklightContext alloc] init];
    context.client = client;
    context.keyboardID = builtInKeyboardID.unsignedLongLongValue;
    return (__bridge_retained void *)context;
}

void AESKeyboardBacklightDestroy(AESKeyboardBacklightHandle handle) {
    if (handle != NULL) {
        CFBridgingRelease(handle);
    }
}

int AESKeyboardBacklightCopyBrightness(
    AESKeyboardBacklightHandle handle,
    float *brightness
) {
    if (handle == NULL || brightness == NULL) {
        return 0;
    }

    AESKeyboardBacklightContext *context =
        (__bridge AESKeyboardBacklightContext *)handle;
    SEL selector = NSSelectorFromString(@"brightnessForKeyboard:");
    *brightness = ((float (*)(id, SEL, uint64_t))objc_msgSend)(
        context.client,
        selector,
        context.keyboardID
    );
    return isfinite(*brightness) ? 1 : 0;
}

int AESKeyboardBacklightSetBrightness(
    AESKeyboardBacklightHandle handle,
    float brightness
) {
    if (handle == NULL || !isfinite(brightness)) {
        return 0;
    }

    AESKeyboardBacklightContext *context =
        (__bridge AESKeyboardBacklightContext *)handle;
    SEL selector = NSSelectorFromString(@"setBrightness:forKeyboard:");
    float clampedBrightness = fminf(fmaxf(brightness, 0.0f), 1.0f);
    BOOL success = ((BOOL (*)(id, SEL, float, uint64_t))objc_msgSend)(
        context.client,
        selector,
        clampedBrightness,
        context.keyboardID
    );
    return success ? 1 : 0;
}
