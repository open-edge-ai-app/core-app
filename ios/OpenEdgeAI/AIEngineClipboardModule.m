#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>

@interface AIEngine : NSObject <RCTBridgeModule>
@end

@implementation AIEngine

RCT_EXPORT_MODULE(AIEngine)

RCT_EXPORT_METHOD(copyTextToClipboard:(NSString *)text
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UIPasteboard.generalPasteboard.string = text ?: @"";
    resolve(@YES);
  });
}

@end
