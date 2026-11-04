#import "MacStreamConfig.h"
#import "DataManager.h"
#import "TemporarySettings.h"
#import "Moonlight-Swift.h"

#include "Limelight.h"
#import <VideoToolbox/VideoToolbox.h>

@implementation MacStreamConfig

+ (StreamConfiguration *)configurationForApp:(TemporaryApp *)app {
    TemporaryHost *host = [app host];
    if (host == nil) {
        return nil;
    }

    DataManager *database = [[DataManager alloc] init];
    TemporarySettings *settings = [database getSettings];

    StreamConfiguration *config = [[StreamConfiguration alloc] init];
    config.host = host.activeAddress.length > 0 ? host.activeAddress : host.address;
    if (config.host.length == 0) {
        return nil;
    }
    config.httpsPort = host.httpsPort;
    config.appID = app.id;
    config.appName = app.name;
    config.serverCert = host.serverCert;
    config.serverCodecModeSupport = host.serverCodecModeSupport;

    int32_t width = settings.width.intValue > 0 ? settings.width.intValue : 1920;
    int32_t height = settings.height.intValue > 0 ? settings.height.intValue : 1080;
    int32_t frameRate = settings.framerate.intValue > 0 ? settings.framerate.intValue : 60;
    int32_t bitRate = settings.bitrate.intValue > 0 ? settings.bitrate.intValue : 20000;
    config.width = width;
    config.height = height;
    config.frameRate = frameRate;
    config.bitRate = bitRate;
    config.optimizeGameSettings = settings.optimizeGames;
    config.playAudioOnPC = settings.playAudioOnPC;
    config.useFramePacing = NO;
    config.swapABXYButtons = settings.swapABXYButtons;
    config.multiController = settings.multiController;
    config.gamepadMask = 1;
    config.audioConfiguration = AUDIO_CONFIGURATION_STEREO;

    int32_t formats = VIDEO_FORMAT_H264;
    if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
        formats |= VIDEO_FORMAT_H265;
        if (settings.enableHdr) {
            formats |= VIDEO_FORMAT_H265_MAIN10;
        }
    }
    config.supportedVideoFormats = formats;
    return config;
}

@end
