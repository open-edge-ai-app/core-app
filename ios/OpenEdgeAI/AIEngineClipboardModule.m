#import <React/RCTBridgeModule.h>
#import <React/RCTUtils.h>
#import <UIKit/UIKit.h>

@interface AIEngine : NSObject <RCTBridgeModule, UIDocumentPickerDelegate>
@property (nonatomic, copy) RCTPromiseResolveBlock filePickerResolve;
@property (nonatomic, copy) RCTPromiseRejectBlock filePickerReject;
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

RCT_EXPORT_METHOD(pickAttachment:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self.filePickerResolve != nil) {
      reject(@"FILE_PICKER_BUSY", @"이미 파일 선택이 진행 중입니다.", nil);
      return;
    }

    UIViewController *presenter = RCTPresentedViewController();
    if (presenter == nil) {
      reject(@"FILE_PICKER_NO_VIEW_CONTROLLER", @"현재 파일 선택 화면을 열 수 없습니다.", nil);
      return;
    }

    self.filePickerResolve = resolve;
    self.filePickerReject = reject;

    NSArray<NSString *> *documentTypes = @[
      @"public.image",
      @"public.audio",
      @"public.movie",
      @"com.adobe.pdf",
      @"public.text",
      @"public.json",
      @"public.data"
    ];
    UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes
                                                             inMode:UIDocumentPickerModeImport];
    picker.allowsMultipleSelection = NO;
    picker.delegate = self;

    [presenter presentViewController:picker animated:YES completion:nil];
  });
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
  didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
  NSURL *url = urls.firstObject;
  if (url == nil) {
    [self resolvePickedAttachment:nil];
    return;
  }

  NSError *error = nil;
  NSDictionary *attachment = [self attachmentForURL:url error:&error];
  if (error != nil) {
    [self rejectPickedAttachment:error];
    return;
  }

  [self resolvePickedAttachment:attachment];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
  [self resolvePickedAttachment:nil];
}

- (NSDictionary *)attachmentForURL:(NSURL *)url error:(NSError **)error
{
  NSNumber *fileSize = nil;
  NSString *name = nil;
  NSString *typeIdentifier = nil;
  [url getResourceValue:&name forKey:NSURLNameKey error:nil];
  [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
  [url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:nil];

  NSString *fileName = name.length > 0 ? name : url.lastPathComponent;
  NSString *mimeType = [self mimeTypeForFileName:fileName typeIdentifier:typeIdentifier];
  NSString *attachmentType = [self attachmentTypeForMimeType:mimeType fileName:fileName];

  NSMutableDictionary *attachment = [NSMutableDictionary dictionary];
  attachment[@"id"] = [NSString stringWithFormat:@"attachment-%0.f", [[NSDate date] timeIntervalSince1970] * 1000];
  attachment[@"type"] = attachmentType;
  attachment[@"uri"] = url.absoluteString;
  attachment[@"name"] = fileName.length > 0 ? fileName : @"첨부 파일";
  if (mimeType.length > 0) {
    attachment[@"mimeType"] = mimeType;
  }
  if (fileSize != nil) {
    attachment[@"sizeBytes"] = fileSize;
  }

  return attachment;
}

- (void)resolvePickedAttachment:(NSDictionary *)attachment
{
  RCTPromiseResolveBlock resolve = self.filePickerResolve;
  self.filePickerResolve = nil;
  self.filePickerReject = nil;

  if (resolve != nil) {
    resolve(attachment ?: [NSNull null]);
  }
}

- (void)rejectPickedAttachment:(NSError *)error
{
  RCTPromiseRejectBlock reject = self.filePickerReject;
  self.filePickerResolve = nil;
  self.filePickerReject = nil;

  if (reject != nil) {
    reject(@"FILE_PICKER_RESULT_ERROR", error.localizedDescription, error);
  }
}

- (NSString *)mimeTypeForFileName:(NSString *)fileName typeIdentifier:(NSString *)typeIdentifier
{
  NSString *lowercaseName = fileName.lowercaseString;
  if ([typeIdentifier isEqualToString:@"com.adobe.pdf"] || [lowercaseName hasSuffix:@".pdf"]) {
    return @"application/pdf";
  }
  if ([typeIdentifier containsString:@"json"] || [lowercaseName hasSuffix:@".json"]) {
    return @"application/json";
  }
  if ([lowercaseName hasSuffix:@".png"]) {
    return @"image/png";
  }
  if ([lowercaseName hasSuffix:@".jpg"] || [lowercaseName hasSuffix:@".jpeg"]) {
    return @"image/jpeg";
  }
  if ([lowercaseName hasSuffix:@".gif"]) {
    return @"image/gif";
  }
  if ([lowercaseName hasSuffix:@".heic"]) {
    return @"image/heic";
  }
  if ([lowercaseName hasSuffix:@".mp3"]) {
    return @"audio/mpeg";
  }
  if ([lowercaseName hasSuffix:@".wav"]) {
    return @"audio/wav";
  }
  if ([lowercaseName hasSuffix:@".m4a"]) {
    return @"audio/mp4";
  }
  if ([lowercaseName hasSuffix:@".mp4"]) {
    return @"video/mp4";
  }
  if ([lowercaseName hasSuffix:@".mov"]) {
    return @"video/quicktime";
  }
  if ([typeIdentifier hasPrefix:@"public.text"] || [lowercaseName hasSuffix:@".txt"]) {
    return @"text/plain";
  }
  return @"application/octet-stream";
}

- (NSString *)attachmentTypeForMimeType:(NSString *)mimeType fileName:(NSString *)fileName
{
  if ([mimeType hasPrefix:@"image/"]) {
    return @"image";
  }
  if ([mimeType hasPrefix:@"audio/"]) {
    return @"audio";
  }
  if ([mimeType hasPrefix:@"video/"]) {
    return @"video";
  }

  NSString *lowercaseName = fileName.lowercaseString;
  if ([lowercaseName hasSuffix:@".png"] || [lowercaseName hasSuffix:@".jpg"] ||
      [lowercaseName hasSuffix:@".jpeg"] || [lowercaseName hasSuffix:@".gif"] ||
      [lowercaseName hasSuffix:@".heic"]) {
    return @"image";
  }
  if ([lowercaseName hasSuffix:@".mp3"] || [lowercaseName hasSuffix:@".wav"] ||
      [lowercaseName hasSuffix:@".m4a"]) {
    return @"audio";
  }
  if ([lowercaseName hasSuffix:@".mp4"] || [lowercaseName hasSuffix:@".mov"]) {
    return @"video";
  }
  return @"file";
}

@end
