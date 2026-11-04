//
//  Utils.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#include <TargetConditionals.h>

@interface Utils : NSObject

typedef NS_ENUM(int, PairState) {
    PairStateUnknown,
    PairStateUnpaired,
    PairStatePaired
};

typedef NS_ENUM(int, State) {
    StateUnknown,
    StateOffline,
    StateOnline
} NS_SWIFT_NAME(HostState);

FOUNDATION_EXPORT NSString *const deviceName;

+ (NSData*) randomBytes:(NSInteger)length;
+ (NSString*) bytesToHex:(NSData*)data;
+ (NSData*) hexToBytes:(NSString*) hex;
#if TARGET_OS_IPHONE
+ (void) addHelpOptionToDialog:(UIAlertController*)dialog;
#endif
+ (BOOL) isActiveNetworkVPN;
+ (BOOL) parseAddressPortString:(NSString*)addressPort address:(NSRange*)address port:(NSRange*)port;
+ (NSString*) addressPortStringToAddress:(NSString*)addressPort;
+ (unsigned short) addressPortStringToPort:(NSString*)addressPort;
+ (NSString*) addressAndPortToAddressPortString:(NSString*)address port:(unsigned short)port;

#if TARGET_OS_IPHONE && !TARGET_OS_TV
+ (void) launchUrl:(NSString*)urlString;
#endif

@end

@interface NSString (NSStringWithTrim)

- (NSString*) trim;

@end
