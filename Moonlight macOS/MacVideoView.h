#import <AppKit/AppKit.h>
#import "AnyVideoDecoderRenderer.h"

// AppKit video surface for the macOS target. Decodes H.264 and HEVC with
// VideoToolbox. AV1 is not advertised by the macOS client.
@interface MacVideoView : NSView <AnyVideoDecoderRenderer>

@property (nonatomic, assign) BOOL relativeMouse;
@property (nonatomic, weak) id<ConnectionCallbacks> callbacks;

@end
