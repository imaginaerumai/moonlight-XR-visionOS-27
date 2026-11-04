#import "MacAudioOutput.h"
#import <AudioToolbox/AudioToolbox.h>
#import <stdatomic.h>

static const int kMaxQueuedBuffers = 8;

static void MacAudioOutputCallback(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer);

@interface MacAudioOutput ()
- (void)noteBufferFinished:(AudioQueueRef)queue buffer:(AudioQueueBufferRef)buffer;
@end

@implementation MacAudioOutput {
    AudioQueueRef _queue;
    void *_raw;
    int _rawBytes;
    atomic_int _queued;
}

- (instancetype)initWithSampleRate:(int)sampleRate
                          channels:(int)channels
                   samplesPerFrame:(int)samplesPerFrame {
    self = [super init];
    if (self == nil || sampleRate <= 0 || channels <= 0 || samplesPerFrame <= 0) {
        return nil;
    }

    _rawBytes = samplesPerFrame * channels * (int)sizeof(int16_t);
    _raw = calloc(1, (size_t)_rawBytes);
    if (_raw == NULL) {
        return nil;
    }
    atomic_init(&_queued, 0);

    AudioStreamBasicDescription format = {0};
    format.mSampleRate = sampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mBitsPerChannel = 16;
    format.mChannelsPerFrame = (UInt32)channels;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = (UInt32)(channels * (int)sizeof(int16_t));
    format.mBytesPerPacket = format.mBytesPerFrame;

    OSStatus status = AudioQueueNewOutput(&format, MacAudioOutputCallback, (__bridge void *)self, NULL, NULL, 0, &_queue);
    if (status != noErr) {
        free(_raw);
        _raw = NULL;
        return nil;
    }
    return self;
}

- (void)dealloc {
    [self stop];
    if (_raw != NULL) {
        free(_raw);
        _raw = NULL;
    }
}

- (void *)rawBuffer {
    return _raw;
}

- (BOOL)start {
    if (_queue == NULL) {
        return NO;
    }
    return AudioQueueStart(_queue, NULL) == noErr;
}

- (void)stop {
    if (_queue != NULL) {
        AudioQueueStop(_queue, true);
        AudioQueueDispose(_queue, true);
        _queue = NULL;
    }
    atomic_store(&_queued, 0);
}

- (void)enqueuePCM:(const void *)bytes length:(int)length {
    if (_queue == NULL || bytes == NULL || length <= 0) {
        return;
    }
    if (atomic_load(&_queued) >= kMaxQueuedBuffers) {
        return;
    }

    AudioQueueBufferRef buffer = NULL;
    if (AudioQueueAllocateBuffer(_queue, (UInt32)length, &buffer) != noErr || buffer == NULL) {
        return;
    }
    memcpy(buffer->mAudioData, bytes, (size_t)length);
    buffer->mAudioDataByteSize = (UInt32)length;
    if (AudioQueueEnqueueBuffer(_queue, buffer, 0, NULL) != noErr) {
        AudioQueueFreeBuffer(_queue, buffer);
        return;
    }
    atomic_fetch_add(&_queued, 1);
}

- (void)noteBufferFinished:(AudioQueueRef)queue buffer:(AudioQueueBufferRef)buffer {
    AudioQueueFreeBuffer(queue, buffer);
    atomic_fetch_sub(&_queued, 1);
}

@end

static void MacAudioOutputCallback(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer) {
    MacAudioOutput *output = (__bridge MacAudioOutput *)userData;
    [output noteBufferFinished:queue buffer:buffer];
}
