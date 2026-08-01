#ifndef KeyboardBacklightBridge_h
#define KeyboardBacklightBridge_h

#ifdef __cplusplus
extern "C" {
#endif

typedef void *AESKeyboardBacklightHandle;

AESKeyboardBacklightHandle AESKeyboardBacklightCreate(void);
void AESKeyboardBacklightDestroy(AESKeyboardBacklightHandle handle);
int AESKeyboardBacklightCopyBrightness(
    AESKeyboardBacklightHandle handle,
    float *brightness
);
int AESKeyboardBacklightSetBrightness(
    AESKeyboardBacklightHandle handle,
    float brightness
);

#ifdef __cplusplus
}
#endif

#endif
