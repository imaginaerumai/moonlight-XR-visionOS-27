#import "MacVideoView.h"
#import "Connection.h"
#import "Logger.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

#include "Limelight.h"

#define NALU_START_PREFIX_SIZE 3
#define NAL_LENGTH_PREFIX_SIZE 4

@implementation MacVideoView {
    AVSampleBufferDisplayLayer *_displayLayer;
    CADisplayLink *_displayLink;
    CMVideoFormatDescriptionRef _formatDesc;
    NSMutableArray<NSData *> *_parameterSets;
    int _videoFormat;
    int _frameRate;
    BOOL _hdr;
    NSEventModifierFlags _modifiers;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self == nil) {
        return nil;
    }
    self.wantsLayer = YES;
    self.layer.backgroundColor = NSColor.blackColor.CGColor;
    _parameterSets = [NSMutableArray array];
    [self installDisplayLayer];
    return self;
}

- (void)dealloc {
    [_displayLink invalidate];
    if (_formatDesc != NULL) {
        CFRelease(_formatDesc);
    }
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self.window makeFirstResponder:self];
    [self updateTrackingAreas];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) {
        [self removeTrackingArea:area];
    }
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                        options:NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                                          owner:self
                                                       userInfo:nil];
    [self addTrackingArea:area];
}

- (void)layout {
    [super layout];
    _displayLayer.frame = self.bounds;
}

- (void)installDisplayLayer {
    [_displayLayer removeFromSuperlayer];
    _displayLayer = [AVSampleBufferDisplayLayer layer];
    _displayLayer.frame = self.bounds;
    _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _displayLayer.backgroundColor = NSColor.blackColor.CGColor;
    if (_hdr) {
        _displayLayer.wantsExtendedDynamicRangeContent = YES;
    }
    [self.layer addSublayer:_displayLayer];
}

- (void)setupWithVideoFormat:(int)videoFormat width:(int)videoWidth height:(int)videoHeight frameRate:(int)frameRate {
    _videoFormat = videoFormat;
    _frameRate = frameRate;
    (void)videoWidth;
    (void)videoHeight;
}

- (void)start {
    [_displayLink invalidate];
    _displayLink = [self displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
    if (@available(macOS 14.0, *)) {
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(_frameRate, _frameRate, _frameRate);
    }
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stop {
    [_displayLink invalidate];
    _displayLink = nil;
    [_displayLayer flush];
}

- (void)setHdrMode:(BOOL)enabled {
    _hdr = enabled;
    _displayLayer.wantsExtendedDynamicRangeContent = enabled;
}

- (void)displayLinkFired:(CADisplayLink *)link {
    (void)link;
    VIDEO_FRAME_HANDLE handle;
    PDECODE_UNIT du;
    while (LiPollNextVideoFrame(&handle, &du)) {
        LiCompleteVideoFrame(handle, DrSubmitDecodeUnit(du));
    }
}

- (void)updateAnnexBBuffer:(CMBlockBufferRef)frameBuffer
                dataBuffer:(CMBlockBufferRef)dataBuffer
                    offset:(int)offset
                    length:(int)nalLength {
    size_t oldOffset = CMBlockBufferGetDataLength(frameBuffer);
    OSStatus status = CMBlockBufferAppendMemoryBlock(frameBuffer, NULL, NAL_LENGTH_PREFIX_SIZE,
                                                     kCFAllocatorDefault, NULL, 0, NAL_LENGTH_PREFIX_SIZE, 0);
    if (status != noErr) {
        return;
    }
    const int dataLength = nalLength - NALU_START_PREFIX_SIZE;
    const uint8_t lengthBytes[] = {
        (uint8_t)(dataLength >> 24),
        (uint8_t)(dataLength >> 16),
        (uint8_t)(dataLength >> 8),
        (uint8_t)dataLength
    };
    CMBlockBufferReplaceDataBytes(lengthBytes, frameBuffer, oldOffset, NAL_LENGTH_PREFIX_SIZE);
    CMBlockBufferAppendBufferReference(frameBuffer, dataBuffer, offset + NALU_START_PREFIX_SIZE, dataLength, 0);
}

- (int)submitDecodeBuffer:(unsigned char *)data length:(int)length bufferType:(int)bufferType decodeUnit:(PDECODE_UNIT)du {
    if (du->frameType == FRAME_TYPE_IDR) {
        if (bufferType != BUFFER_TYPE_PICDATA) {
            if (bufferType == BUFFER_TYPE_VPS || bufferType == BUFFER_TYPE_SPS || bufferType == BUFFER_TYPE_PPS) {
                int startLen = data[2] == 0x01 ? 3 : 4;
                if (length > startLen) {
                    [_parameterSets addObject:[NSData dataWithBytes:&data[startLen] length:(NSUInteger)(length - startLen)]];
                }
            }
            return DR_OK;
        }

        if (_formatDesc != NULL) {
            CFRelease(_formatDesc);
            _formatDesc = NULL;
        }

        size_t count = _parameterSets.count;
        if (count == 0) {
            free(data);
            return DR_NEED_IDR;
        }
        const uint8_t *pointers[count];
        size_t sizes[count];
        for (size_t i = 0; i < count; i++) {
            NSData *set = _parameterSets[i];
            pointers[i] = set.bytes;
            sizes[i] = set.length;
        }

        OSStatus status = noErr;
        if (_videoFormat & VIDEO_FORMAT_MASK_H264) {
            status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, count, pointers, sizes,
                                                                         NAL_LENGTH_PREFIX_SIZE, &_formatDesc);
        } else if (_videoFormat & VIDEO_FORMAT_MASK_H265) {
            status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault, count, pointers, sizes,
                                                                         NAL_LENGTH_PREFIX_SIZE, NULL, &_formatDesc);
        } else {
            Log(LOG_E, @"macOS target does not decode this video format (0x%x)", _videoFormat);
            free(data);
            [_parameterSets removeAllObjects];
            return DR_NEED_IDR;
        }
        [_parameterSets removeAllObjects];
        if (status != noErr) {
            Log(LOG_E, @"Failed to create format description: %d", (int)status);
            _formatDesc = NULL;
        }
    }

    if (bufferType != BUFFER_TYPE_PICDATA) {
        return DR_OK;
    }
    if (_formatDesc == NULL) {
        free(data);
        return DR_NEED_IDR;
    }
    if (_displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
        Log(LOG_E, @"Display layer failed: %@", _displayLayer.error);
        [self installDisplayLayer];
        free(data);
        return DR_NEED_IDR;
    }

    CMBlockBufferRef dataBuffer = NULL;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, data, (size_t)length, kCFAllocatorDefault, NULL,
                                                         0, (size_t)length, 0, &dataBuffer);
    if (status != noErr) {
        free(data);
        return DR_NEED_IDR;
    }

    CMBlockBufferRef frameBuffer = NULL;
    status = CMBlockBufferCreateEmpty(NULL, 0, 0, &frameBuffer);
    if (status != noErr) {
        CFRelease(dataBuffer);
        return DR_NEED_IDR;
    }

    if (_videoFormat & (VIDEO_FORMAT_MASK_H264 | VIDEO_FORMAT_MASK_H265)) {
        int lastOffset = -1;
        for (int i = 0; i < length - NALU_START_PREFIX_SIZE; i++) {
            if (data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1) {
                if (lastOffset != -1) {
                    [self updateAnnexBBuffer:frameBuffer dataBuffer:dataBuffer offset:lastOffset length:i - lastOffset];
                }
                lastOffset = i;
            }
        }
        if (lastOffset != -1) {
            [self updateAnnexBBuffer:frameBuffer dataBuffer:dataBuffer offset:lastOffset length:length - lastOffset];
        }
    }

    CMSampleTimingInfo timing = {kCMTimeInvalid, CMTimeMake(du->presentationTimeMs, 1000), kCMTimeInvalid};
    CMSampleBufferRef sample = NULL;
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, frameBuffer, _formatDesc, 1, 1, &timing, 0, NULL, &sample);
    if (status != noErr) {
        CFRelease(dataBuffer);
        CFRelease(frameBuffer);
        return DR_NEED_IDR;
    }

    [_displayLayer enqueueSampleBuffer:sample];
    if (du->frameType == FRAME_TYPE_IDR) {
        _displayLayer.hidden = NO;
        [self.callbacks videoContentShown];
    }
    CFRelease(dataBuffer);
    CFRelease(frameBuffer);
    CFRelease(sample);
    return DR_OK;
}

#pragma mark - Input

- (short)clamp:(CGFloat)value limit:(CGFloat)limit {
    if (limit < 1) {
        limit = 1;
    }
    if (value < 0) {
        value = 0;
    }
    if (value > limit - 1) {
        value = limit - 1;
    }
    return (short)value;
}

- (void)sendPosition:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat height = NSHeight(self.bounds);
    CGFloat width = NSWidth(self.bounds);
    short x = [self clamp:point.x limit:width];
    short y = [self clamp:height - point.y limit:height];
    LiSendMousePositionEvent(x, y, [self clamp:width limit:32767], [self clamp:height limit:32767]);
}

- (void)mouseMoved:(NSEvent *)event {
    if (self.relativeMouse) {
        LiSendMouseMoveEvent((short)event.deltaX, (short)event.deltaY);
    } else {
        [self sendPosition:event];
    }
}

- (void)mouseDragged:(NSEvent *)event {
    [self mouseMoved:event];
}

- (void)rightMouseDragged:(NSEvent *)event {
    [self mouseMoved:event];
}

- (void)otherMouseDragged:(NSEvent *)event {
    [self mouseMoved:event];
}

- (void)mouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
}

- (void)mouseUp:(NSEvent *)event {
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
}

- (void)rightMouseDown:(NSEvent *)event {
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
}

- (void)rightMouseUp:(NSEvent *)event {
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
}

- (void)otherMouseDown:(NSEvent *)event {
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_MIDDLE);
}

- (void)otherMouseUp:(NSEvent *)event {
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_MIDDLE);
}

- (void)scrollWheel:(NSEvent *)event {
    CGFloat delta = event.scrollingDeltaY;
    if (!event.hasPreciseScrollingDeltas) {
        delta *= 10;
    }
    signed char clicks = 0;
    if (delta > 0) {
        clicks = (signed char)MIN(delta / 10.0, 127);
        if (clicks == 0) {
            clicks = 1;
        }
    } else if (delta < 0) {
        clicks = (signed char)MAX(delta / 10.0, -127);
        if (clicks == 0) {
            clicks = -1;
        }
    }
    if (clicks != 0) {
        LiSendScrollEvent(clicks);
    }
}

- (short)windowsKeyCode:(NSEvent *)event {
    switch (event.keyCode) {
        case 36: return 0x0D; // return
        case 48: return 0x09; // tab
        case 51: return 0x08; // backspace
        case 53: return 0x1B; // escape
        case 117: return 0x2E; // forward delete
        case 123: return 0x25; // left
        case 124: return 0x27; // right
        case 125: return 0x28; // down
        case 126: return 0x26; // up
        case 122: return 0x70; // F1
        case 120: return 0x71;
        case 99: return 0x72;
        case 118: return 0x73;
        case 96: return 0x74;
        case 97: return 0x75;
        case 98: return 0x76;
        case 100: return 0x77;
        case 101: return 0x78;
        case 109: return 0x79;
        case 103: return 0x7A;
        case 111: return 0x7B; // F12
        default: break;
    }
    NSString *chars = event.charactersIgnoringModifiers;
    if (chars.length == 0) {
        return 0;
    }
    unichar c = [chars characterAtIndex:0];
    if (c >= 'a' && c <= 'z') {
        return (short)(c - 'a' + 'A');
    }
    if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == ' ') {
        return (short)c;
    }
    return 0;
}

- (void)keyDown:(NSEvent *)event {
    short key = [self windowsKeyCode:event];
    if (key != 0) {
        LiSendKeyboardEvent(key, KEY_ACTION_DOWN, 0);
    }
}

- (void)keyUp:(NSEvent *)event {
    short key = [self windowsKeyCode:event];
    if (key != 0) {
        LiSendKeyboardEvent(key, KEY_ACTION_UP, 0);
    }
}

- (void)sendModifier:(NSEventModifierFlags)flag windowsKey:(short)key event:(NSEvent *)event {
    BOOL down = (event.modifierFlags & flag) != 0;
    BOOL wasDown = (_modifiers & flag) != 0;
    if (down == wasDown) {
        return;
    }
    LiSendKeyboardEvent(key, down ? KEY_ACTION_DOWN : KEY_ACTION_UP, 0);
}

- (void)flagsChanged:(NSEvent *)event {
    [self sendModifier:NSEventModifierFlagShift windowsKey:0x10 event:event];
    [self sendModifier:NSEventModifierFlagControl windowsKey:0x11 event:event];
    [self sendModifier:NSEventModifierFlagOption windowsKey:0x12 event:event];
    [self sendModifier:NSEventModifierFlagCommand windowsKey:0x5B event:event];
    _modifiers = event.modifierFlags;
}

@end
