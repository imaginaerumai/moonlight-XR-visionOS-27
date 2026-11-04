#import <Foundation/Foundation.h>

@class StreamConfiguration;
@class TemporaryApp;

@interface MacStreamConfig : NSObject

+ (StreamConfiguration *)configurationForApp:(TemporaryApp *)app;

@end
