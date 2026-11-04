#import <Foundation/Foundation.h>

// Plays decoded 16-bit PCM with AudioQueue. Used by the macOS target only.
@interface MacAudioOutput : NSObject

- (instancetype)initWithSampleRate:(int)sampleRate
                          channels:(int)channels
                   samplesPerFrame:(int)samplesPerFrame;

- (void *)rawBuffer;
- (BOOL)start;
- (void)stop;
- (void)enqueuePCM:(const void *)bytes length:(int)length;

@end
