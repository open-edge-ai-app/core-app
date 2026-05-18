#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AIEngineLiteRtLmChunkHandler)(NSString *chunk);

@interface AIEngineLiteRtLmRuntime : NSObject

+ (instancetype)shared;

- (NSDictionary<NSString *, id> *)statusWithModelInstalled:(BOOL)modelInstalled
                                                 localPath:(NSString *)localPath;
- (NSDictionary<NSString *, id> *)loadModelAtPath:(NSString *)modelPath
                                   cacheDirectory:(NSString *)cacheDirectory;
- (NSDictionary<NSString *, id> *)generatePrompt:(NSString *)prompt;
- (NSDictionary<NSString *, id> *)streamPrompt:(NSString *)prompt
                                       onChunk:(AIEngineLiteRtLmChunkHandler)onChunk;
- (void)unload;
- (BOOL)cancelActiveGeneration;

@end

NS_ASSUME_NONNULL_END
