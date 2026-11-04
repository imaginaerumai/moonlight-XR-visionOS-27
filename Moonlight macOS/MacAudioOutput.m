#import "MacAudioOutput.h"
#import <AudioToolbox/AudioToolbox.h>
#import <stdatomic.h>

static const int kMaxQueuedBuffers = 8;

static void MacAudioOutputCallback(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer);

@interface MacAudioOutput ()
- (void)noteBufferFinished:(AudioQueueRef)queue buffer:(AudioQueueBufferRef)buffer;
- (void)callbackThreadMain;
@end

@implementation MacAudioOutput {
    AudioQueueRef _queue;
    void *_raw;
    int _rawBytes;
    atomic_int _queued;
    atomic_bool _stopped;
    CFRunLoopRef _callbackRunLoop;
    dispatch_semaphore_t _runLoopReady;
    dispatch_semaphore_t _threadDone;
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
    atomic_init(&_stopped, false);
    _runLoopReady = dispatch_semaphore_create(0);
    _threadDone = dispatch_semaphore_create(0);
    // Callbacks stay on this thread until stop joins it, so teardown cannot
    // release the output while noteBufferFinished is still running.
    [NSThread detachNewThreadSelector:@selector(callbackThreadMain) toTarget:self withObject:nil];
    dispatch_semaphore_wait(_runLoopReady, DISPATCH_TIME_FOREVER);

    AudioStreamBasicDescription format = {0};
    format.mSampleRate = sampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mBitsPerChannel = 16;
    format.mChannelsPerFrame = (UInt32)channels;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = (UInt32)(channels * (int)sizeof(int16_t));
    format.mBytesPerPacket = format.mBytesPerFrame;

    OSStatus status = AudioQueueNewOutput(&format, MacAudioOutputCallback, (__bridge void *)self,
                                         _callbackRunLoop, kCFRunLoopCommonModes, 0, &_queue);
    if (status != noErr) {
        _queue = NULL;
        free(_raw);
        _raw = NULL;
        [self stop];
        return nil;
    }
    return self;
}

- (void)callbackThreadMain {
    @autoreleasepool {
        _callbackRunLoop = CFRunLoopGetCurrent();
        CFRetain(_callbackRunLoop);
        // Signal only after CFRunLoopRun is pumping, so CFRunLoopStop cannot be lost.
        CFRunLoopPerformBlock(_callbackRunLoop, kCFRunLoopDefaultMode, ^{
            dispatch_semaphore_signal(self->_runLoopReady);
        });
        CFRunLoopRun();
        CFRunLoopRef loop = _callbackRunLoop;
        _callbackRunLoop = NULL;
        if (loop != NULL) {
            CFRelease(loop);
        }
    }
    dispatch_semaphore_signal(_threadDone);
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
    if (atomic_exchange(&_stopped, true)) {
        return;
    }
    // Stop from this thread so AudioQueue can finish callbacks on the run-loop
    // thread. Join that thread before returning; the caller then drops its retain.
    AudioQueueRef queue = _queue;
    _queue = NULL;
    if (queue != NULL) {
        AudioQueueStop(queue, true);
        AudioQueueDispose(queue, true);
    }
    CFRunLoopRef loop = _callbackRunLoop;
    if (loop != NULL) {
        CFRunLoopStop(loop);
        CFRunLoopWakeUp(loop);
    }
    dispatch_semaphore_wait(_threadDone, DISPATCH_TIME_FOREVER);
    atomic_store(&_queued, 0);
}

- (void)enqueuePCM:(const void *)bytes length:(int)length {
    if (atomic_load(&_stopped) || _queue == NULL || bytes == NULL || length <= 0) {
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
    if (!atomic_load(&_stopped)) {
        AudioQueueFreeBuffer(queue, buffer);
    }
    atomic_fetch_sub(&_queued, 1);
}

@end

static void MacAudioOutputCallback(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer) {
    MacAudioOutput *output = (__bridge MacAudioOutput *)userData;
    [output noteBufferFinished:queue buffer:buffer];
}
