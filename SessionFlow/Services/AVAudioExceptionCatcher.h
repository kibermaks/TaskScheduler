#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioExceptionCatcher : NSObject

+ (nullable NSString *)playPlayerNodeAndReturnExceptionReason:(AVAudioPlayerNode *)playerNode;

@end

NS_ASSUME_NONNULL_END
