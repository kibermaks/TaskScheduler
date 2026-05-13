#import "AVAudioExceptionCatcher.h"

@implementation AVAudioExceptionCatcher

+ (nullable NSString *)playPlayerNodeAndReturnExceptionReason:(AVAudioPlayerNode *)playerNode {
    @try {
        [playerNode play];
        return nil;
    } @catch (NSException *exception) {
        NSString *reason = exception.reason ?: @"Unknown AVAudioPlayerNode exception";
        return [NSString stringWithFormat:@"%@: %@", exception.name, reason];
    }
}

@end
