#import "AIEngineLiteRtLmRuntime.h"

#import <dlfcn.h>
#import <stdbool.h>
#import <string.h>

static NSString *const AIEngineLiteRtLmRuntimeErrorDomain = @"OpenEdgeAI.LiteRtLMRuntime";
static NSString *const AIEngineLiteRtLmMissingRuntimeMessage =
  @"LiteRT-LM iOS 런타임 라이브러리가 앱 번들에 없습니다. libLiteRTLM.dylib 또는 LiteRTLM.framework를 Frameworks에 포함해야 Gemma 4를 iOS에서 실행할 수 있습니다.";

typedef enum {
  LiteRtLmInputDataTypeText = 0,
  LiteRtLmInputDataTypeImage = 1,
  LiteRtLmInputDataTypeImageEnd = 2,
  LiteRtLmInputDataTypeAudio = 3,
  LiteRtLmInputDataTypeAudioEnd = 4,
} LiteRtLmInputDataType;

typedef struct {
  LiteRtLmInputDataType type;
  const void *data;
  size_t size;
} LiteRtLmInputData;

typedef void (*LiteRtLmStreamCallback)(void *callbackData, const char *chunk, bool isFinal, const char *errorMessage);
typedef void *(*LiteRtLmEngineSettingsCreateFn)(const char *modelPath, const char *backend, const char *visionBackend, const char *audioBackend);
typedef void (*LiteRtLmEngineSettingsDeleteFn)(void *settings);
typedef void (*LiteRtLmEngineSettingsSetMaxTokensFn)(void *settings, int maxTokens);
typedef void (*LiteRtLmEngineSettingsSetCacheDirFn)(void *settings, const char *cacheDir);
typedef void (*LiteRtLmEngineSettingsSetParallelLoadingFn)(void *settings, bool enabled);
typedef void *(*LiteRtLmEngineCreateFn)(const void *settings);
typedef void (*LiteRtLmEngineDeleteFn)(void *engine);
typedef void *(*LiteRtLmEngineCreateSessionFn)(void *engine, void *sessionConfig);
typedef void (*LiteRtLmSessionDeleteFn)(void *session);
typedef void (*LiteRtLmSessionCancelFn)(void *session);
typedef void *(*LiteRtLmSessionGenerateContentFn)(void *session, const LiteRtLmInputData *inputs, size_t inputCount);
typedef int (*LiteRtLmSessionGenerateContentStreamFn)(void *session, const LiteRtLmInputData *inputs, size_t inputCount, LiteRtLmStreamCallback callback, void *callbackData);
typedef void (*LiteRtLmResponsesDeleteFn)(void *responses);
typedef int (*LiteRtLmResponsesGetNumCandidatesFn)(const void *responses);
typedef const char *(*LiteRtLmResponsesGetTextAtFn)(const void *responses, int index);

@interface AIEngineLiteRtLmStreamState : NSObject
@property (nonatomic, strong) NSMutableString *output;
@property (nonatomic, copy) AIEngineLiteRtLmChunkHandler onChunk;
@property (nonatomic) dispatch_semaphore_t semaphore;
@property (nonatomic, copy, nullable) NSString *errorMessage;
@end

@implementation AIEngineLiteRtLmStreamState
@end

static void AIEngineLiteRtLmRuntimeStreamCallback(void *callbackData, const char *chunk, bool isFinal, const char *errorMessage);

@interface AIEngineLiteRtLmRuntime ()
@property (nonatomic) BOOL loading;
@property (nonatomic, copy, nullable) NSString *lastError;
@end

@implementation AIEngineLiteRtLmRuntime {
  void *_libraryHandle;
  BOOL _ownsLibraryHandle;
  NSString *_runtimeLibraryPath;

  LiteRtLmEngineSettingsCreateFn _engineSettingsCreate;
  LiteRtLmEngineSettingsDeleteFn _engineSettingsDelete;
  LiteRtLmEngineSettingsSetMaxTokensFn _engineSettingsSetMaxTokens;
  LiteRtLmEngineSettingsSetCacheDirFn _engineSettingsSetCacheDir;
  LiteRtLmEngineSettingsSetParallelLoadingFn _engineSettingsSetParallelLoading;
  LiteRtLmEngineCreateFn _engineCreate;
  LiteRtLmEngineDeleteFn _engineDelete;
  LiteRtLmEngineCreateSessionFn _engineCreateSession;
  LiteRtLmSessionDeleteFn _sessionDelete;
  LiteRtLmSessionCancelFn _sessionCancel;
  LiteRtLmSessionGenerateContentFn _sessionGenerateContent;
  LiteRtLmSessionGenerateContentStreamFn _sessionGenerateContentStream;
  LiteRtLmResponsesDeleteFn _responsesDelete;
  LiteRtLmResponsesGetNumCandidatesFn _responsesGetNumCandidates;
  LiteRtLmResponsesGetTextAtFn _responsesGetTextAt;

  void *_engine;
  void *_activeSession;
  NSString *_loadedModelPath;
}

+ (instancetype)shared
{
  static AIEngineLiteRtLmRuntime *runtime;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    runtime = [[AIEngineLiteRtLmRuntime alloc] init];
  });
  return runtime;
}

- (void)dealloc
{
  [self unload];
  if (_libraryHandle != NULL && _ownsLibraryHandle) {
    dlclose(_libraryHandle);
  }
}

- (NSDictionary<NSString *, id> *)statusWithModelInstalled:(BOOL)modelInstalled
                                                 localPath:(NSString *)localPath
{
  @synchronized (self) {
    BOOL runtimeAvailable = [self resolveFunctionsLocked];
    NSString *error = self.lastError;
    if (modelInstalled && !runtimeAvailable) {
      error = error ?: AIEngineLiteRtLmMissingRuntimeMessage;
    }

    return @{
      @"modelInstalled": @(modelInstalled),
      @"loaded": @(_engine != NULL),
      @"loading": @(self.loading),
      @"canGenerate": @(modelInstalled && _engine != NULL && runtimeAvailable),
      @"localPath": localPath,
      @"runtimeAvailable": @(runtimeAvailable),
      @"runtimeLibraryPath": _runtimeLibraryPath ?: [NSNull null],
      @"error": error ?: [NSNull null],
    };
  }
}

- (NSDictionary<NSString *, id> *)loadModelAtPath:(NSString *)modelPath
                                   cacheDirectory:(NSString *)cacheDirectory
{
  @synchronized (self) {
    if (![self resolveFunctionsLocked]) {
      self.lastError = self.lastError ?: AIEngineLiteRtLmMissingRuntimeMessage;
      return [self statusWithModelInstalled:YES localPath:modelPath];
    }

    if (_engine != NULL && [_loadedModelPath isEqualToString:modelPath]) {
      self.lastError = nil;
      return [self statusWithModelInstalled:YES localPath:modelPath];
    }

    [self closeEngineLocked];
    self.loading = YES;
    self.lastError = nil;

    NSError *directoryError = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&directoryError];
    if (directoryError != nil) {
      self.loading = NO;
      self.lastError = directoryError.localizedDescription;
      return [self statusWithModelInstalled:YES localPath:modelPath];
    }

    _engine = [self createEngineLockedWithModelPath:modelPath cacheDirectory:cacheDirectory backend:"gpu"];
    if (_engine == NULL) {
      _engine = [self createEngineLockedWithModelPath:modelPath cacheDirectory:cacheDirectory backend:"cpu"];
    }

    if (_engine == NULL) {
      self.lastError = self.lastError ?: @"LiteRT-LM 엔진을 초기화하지 못했습니다.";
      _loadedModelPath = nil;
    } else {
      _loadedModelPath = [modelPath copy];
      self.lastError = nil;
    }

    self.loading = NO;
    return [self statusWithModelInstalled:YES localPath:modelPath];
  }
}

- (NSDictionary<NSString *, id> *)generatePrompt:(NSString *)prompt
{
  @synchronized (self) {
    if (![self canGenerateLocked]) {
      return [self resultWithMessage:nil error:self.lastError ?: AIEngineLiteRtLmMissingRuntimeMessage];
    }
  }

  void *session = [self createSessionForGeneration];
  if (session == NULL) {
    return [self resultWithMessage:nil error:self.lastError ?: @"LiteRT-LM 세션을 만들지 못했습니다."];
  }

  @try {
    const char *promptBytes = [prompt UTF8String];
    LiteRtLmInputData input;
    input.type = LiteRtLmInputDataTypeText;
    input.data = promptBytes;
    input.size = strlen(promptBytes);

    void *responses = _sessionGenerateContent(session, &input, 1);
    if (responses == NULL) {
      return [self resultWithMessage:nil error:@"LiteRT-LM 응답 생성에 실패했습니다."];
    }

    @try {
      int candidates = _responsesGetNumCandidates(responses);
      if (candidates <= 0) {
        return [self resultWithMessage:nil error:@"LiteRT-LM 응답 후보가 비어 있습니다."];
      }

      const char *text = _responsesGetTextAt(responses, 0);
      NSString *message = text != NULL ? [NSString stringWithUTF8String:text] : @"";
      return [self resultWithMessage:message ?: @"" error:nil];
    } @finally {
      _responsesDelete(responses);
    }
  } @finally {
    [self finishSession:session];
  }
}

- (NSDictionary<NSString *, id> *)streamPrompt:(NSString *)prompt
                                       onChunk:(AIEngineLiteRtLmChunkHandler)onChunk
{
  @synchronized (self) {
    if (![self canGenerateLocked]) {
      return [self resultWithMessage:nil error:self.lastError ?: AIEngineLiteRtLmMissingRuntimeMessage];
    }
  }

  void *session = [self createSessionForGeneration];
  if (session == NULL) {
    return [self resultWithMessage:nil error:self.lastError ?: @"LiteRT-LM 세션을 만들지 못했습니다."];
  }

  AIEngineLiteRtLmStreamState *state = [[AIEngineLiteRtLmStreamState alloc] init];
  state.output = [[NSMutableString alloc] init];
  state.onChunk = onChunk ?: ^(NSString *chunk) {};
  state.semaphore = dispatch_semaphore_create(0);

  void *callbackData = (__bridge_retained void *)state;

  @try {
    const char *promptBytes = [prompt UTF8String];
    LiteRtLmInputData input;
    input.type = LiteRtLmInputDataTypeText;
    input.data = promptBytes;
    input.size = strlen(promptBytes);

    int started = _sessionGenerateContentStream(session, &input, 1, AIEngineLiteRtLmRuntimeStreamCallback, callbackData);
    if (started != 0) {
      CFRelease(callbackData);
      return [self resultWithMessage:nil error:@"LiteRT-LM 스트리밍 응답을 시작하지 못했습니다."];
    }

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(180 * NSEC_PER_SEC));
    long waitResult = dispatch_semaphore_wait(state.semaphore, timeout);
    if (waitResult != 0) {
      _sessionCancel(session);
      dispatch_time_t cancelTimeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC));
      if (dispatch_semaphore_wait(state.semaphore, cancelTimeout) == 0) {
        CFRelease(callbackData);
      }
      return [self resultWithMessage:nil error:@"LiteRT-LM 응답이 제한 시간 안에 완료되지 않았습니다."];
    }

    NSString *error = nil;
    NSString *message = nil;
    @synchronized (state) {
      error = state.errorMessage;
      message = [state.output copy];
    }

    CFRelease(callbackData);
    return [self resultWithMessage:error == nil ? message : nil error:error];
  } @finally {
    [self finishSession:session];
  }
}

- (void)unload
{
  @synchronized (self) {
    if (_activeSession != NULL && _sessionCancel != NULL) {
      _sessionCancel(_activeSession);
    }
    [self closeEngineLocked];
    self.loading = NO;
    self.lastError = nil;
  }
}

- (BOOL)cancelActiveGeneration
{
  @synchronized (self) {
    if (_activeSession == NULL || _sessionCancel == NULL) {
      return NO;
    }
    _sessionCancel(_activeSession);
    return YES;
  }
}

static void AIEngineLiteRtLmRuntimeStreamCallback(void *callbackData, const char *chunk, bool isFinal, const char *errorMessage)
{
  AIEngineLiteRtLmStreamState *state = (__bridge AIEngineLiteRtLmStreamState *)callbackData;
  NSString *chunkText = nil;
  NSString *errorText = nil;

  if (chunk != NULL) {
    chunkText = [NSString stringWithUTF8String:chunk];
  }
  if (errorMessage != NULL) {
    errorText = [NSString stringWithUTF8String:errorMessage];
  }

  @synchronized (state) {
    if (chunkText.length > 0) {
      [state.output appendString:chunkText];
    }
    if (errorText.length > 0) {
      state.errorMessage = errorText;
    }
  }

  if (chunkText.length > 0) {
    state.onChunk(chunkText);
  }
  if (isFinal || errorText.length > 0) {
    dispatch_semaphore_signal(state.semaphore);
  }
}

- (BOOL)resolveFunctionsLocked
{
  if ([self hasRequiredFunctionsLocked]) {
    return YES;
  }

  void *mainHandle = dlopen(NULL, RTLD_NOW);
  if (mainHandle != NULL && [self bindFunctionsLockedFromHandle:mainHandle libraryPath:@"main executable"]) {
    _libraryHandle = mainHandle;
    _ownsLibraryHandle = NO;
    return YES;
  }

  for (NSString *path in [self candidateLibraryPaths]) {
    void *handle = dlopen(path.UTF8String, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
      continue;
    }

    if ([self bindFunctionsLockedFromHandle:handle libraryPath:path]) {
      _libraryHandle = handle;
      _ownsLibraryHandle = YES;
      return YES;
    }

    dlclose(handle);
  }

  self.lastError = AIEngineLiteRtLmMissingRuntimeMessage;
  return NO;
}

- (BOOL)bindFunctionsLockedFromHandle:(void *)handle libraryPath:(NSString *)libraryPath
{
  LiteRtLmEngineSettingsCreateFn engineSettingsCreate =
    reinterpret_cast<LiteRtLmEngineSettingsCreateFn>(dlsym(handle, "litert_lm_engine_settings_create"));
  LiteRtLmEngineSettingsDeleteFn engineSettingsDelete =
    reinterpret_cast<LiteRtLmEngineSettingsDeleteFn>(dlsym(handle, "litert_lm_engine_settings_delete"));
  LiteRtLmEngineSettingsSetMaxTokensFn engineSettingsSetMaxTokens =
    reinterpret_cast<LiteRtLmEngineSettingsSetMaxTokensFn>(dlsym(handle, "litert_lm_engine_settings_set_max_num_tokens"));
  LiteRtLmEngineSettingsSetCacheDirFn engineSettingsSetCacheDir =
    reinterpret_cast<LiteRtLmEngineSettingsSetCacheDirFn>(dlsym(handle, "litert_lm_engine_settings_set_cache_dir"));
  LiteRtLmEngineSettingsSetParallelLoadingFn engineSettingsSetParallelLoading =
    reinterpret_cast<LiteRtLmEngineSettingsSetParallelLoadingFn>(dlsym(handle, "litert_lm_engine_settings_set_parallel_file_section_loading"));
  LiteRtLmEngineCreateFn engineCreate =
    reinterpret_cast<LiteRtLmEngineCreateFn>(dlsym(handle, "litert_lm_engine_create"));
  LiteRtLmEngineDeleteFn engineDelete =
    reinterpret_cast<LiteRtLmEngineDeleteFn>(dlsym(handle, "litert_lm_engine_delete"));
  LiteRtLmEngineCreateSessionFn engineCreateSession =
    reinterpret_cast<LiteRtLmEngineCreateSessionFn>(dlsym(handle, "litert_lm_engine_create_session"));
  LiteRtLmSessionDeleteFn sessionDelete =
    reinterpret_cast<LiteRtLmSessionDeleteFn>(dlsym(handle, "litert_lm_session_delete"));
  LiteRtLmSessionCancelFn sessionCancel =
    reinterpret_cast<LiteRtLmSessionCancelFn>(dlsym(handle, "litert_lm_session_cancel_process"));
  LiteRtLmSessionGenerateContentFn sessionGenerateContent =
    reinterpret_cast<LiteRtLmSessionGenerateContentFn>(dlsym(handle, "litert_lm_session_generate_content"));
  LiteRtLmSessionGenerateContentStreamFn sessionGenerateContentStream =
    reinterpret_cast<LiteRtLmSessionGenerateContentStreamFn>(dlsym(handle, "litert_lm_session_generate_content_stream"));
  LiteRtLmResponsesDeleteFn responsesDelete =
    reinterpret_cast<LiteRtLmResponsesDeleteFn>(dlsym(handle, "litert_lm_responses_delete"));
  LiteRtLmResponsesGetNumCandidatesFn responsesGetNumCandidates =
    reinterpret_cast<LiteRtLmResponsesGetNumCandidatesFn>(dlsym(handle, "litert_lm_responses_get_num_candidates"));
  LiteRtLmResponsesGetTextAtFn responsesGetTextAt =
    reinterpret_cast<LiteRtLmResponsesGetTextAtFn>(dlsym(handle, "litert_lm_responses_get_response_text_at"));

  if (
    engineSettingsCreate == NULL ||
    engineSettingsDelete == NULL ||
    engineSettingsSetMaxTokens == NULL ||
    engineSettingsSetCacheDir == NULL ||
    engineCreate == NULL ||
    engineDelete == NULL ||
    engineCreateSession == NULL ||
    sessionDelete == NULL ||
    sessionCancel == NULL ||
    sessionGenerateContent == NULL ||
    sessionGenerateContentStream == NULL ||
    responsesDelete == NULL ||
    responsesGetNumCandidates == NULL ||
    responsesGetTextAt == NULL
  ) {
    return NO;
  }

  _engineSettingsCreate = engineSettingsCreate;
  _engineSettingsDelete = engineSettingsDelete;
  _engineSettingsSetMaxTokens = engineSettingsSetMaxTokens;
  _engineSettingsSetCacheDir = engineSettingsSetCacheDir;
  _engineSettingsSetParallelLoading = engineSettingsSetParallelLoading;
  _engineCreate = engineCreate;
  _engineDelete = engineDelete;
  _engineCreateSession = engineCreateSession;
  _sessionDelete = sessionDelete;
  _sessionCancel = sessionCancel;
  _sessionGenerateContent = sessionGenerateContent;
  _sessionGenerateContentStream = sessionGenerateContentStream;
  _responsesDelete = responsesDelete;
  _responsesGetNumCandidates = responsesGetNumCandidates;
  _responsesGetTextAt = responsesGetTextAt;
  _runtimeLibraryPath = [libraryPath copy];
  self.lastError = nil;
  return YES;
}

- (NSArray<NSString *> *)candidateLibraryPaths
{
  NSMutableArray<NSString *> *paths = [[NSMutableArray alloc] init];
  NSArray<NSString *> *libraryNames = @[
    @"libLiteRTLM.dylib",
    @"libLiteRtLM.dylib",
    @"libLiteRtLm.dylib",
    @"liblitert_lm.dylib",
    @"liblitert_lm_c.dylib",
    @"liblitert_lm_engine.dylib",
    @"LiteRTLM.framework/LiteRTLM",
  ];
  NSBundle *bundle = [NSBundle mainBundle];
  NSArray<NSString *> *directories = @[
    bundle.privateFrameworksPath ?: @"",
    [bundle.bundlePath stringByAppendingPathComponent:@"Frameworks"] ?: @"",
    bundle.bundlePath ?: @"",
  ];

  for (NSString *directory in directories) {
    if (directory.length == 0) {
      continue;
    }

    for (NSString *name in libraryNames) {
      [paths addObject:[directory stringByAppendingPathComponent:name]];
    }
  }

  [paths addObjectsFromArray:libraryNames];
  return paths;
}

- (BOOL)hasRequiredFunctionsLocked
{
  return
    _engineSettingsCreate != NULL &&
    _engineSettingsDelete != NULL &&
    _engineSettingsSetMaxTokens != NULL &&
    _engineSettingsSetCacheDir != NULL &&
    _engineCreate != NULL &&
    _engineDelete != NULL &&
    _engineCreateSession != NULL &&
    _sessionDelete != NULL &&
    _sessionCancel != NULL &&
    _sessionGenerateContent != NULL &&
    _sessionGenerateContentStream != NULL &&
    _responsesDelete != NULL &&
    _responsesGetNumCandidates != NULL &&
    _responsesGetTextAt != NULL;
}

- (void *)createEngineLockedWithModelPath:(NSString *)modelPath
                           cacheDirectory:(NSString *)cacheDirectory
                                  backend:(const char *)backend
{
  const char *modelPathBytes = modelPath.UTF8String;
  const char *cacheDirectoryBytes = cacheDirectory.UTF8String;
  void *settings = _engineSettingsCreate(modelPathBytes, backend, backend, "cpu");
  if (settings == NULL) {
    self.lastError = [NSString stringWithFormat:@"LiteRT-LM %@ 설정을 만들지 못했습니다.", [NSString stringWithUTF8String:backend]];
    return NULL;
  }

  @try {
    _engineSettingsSetMaxTokens(settings, 4096);
    _engineSettingsSetCacheDir(settings, cacheDirectoryBytes);
    if (_engineSettingsSetParallelLoading != NULL) {
      _engineSettingsSetParallelLoading(settings, false);
    }

    void *engine = _engineCreate(settings);
    if (engine == NULL) {
      self.lastError = [NSString stringWithFormat:@"LiteRT-LM %@ 엔진 초기화에 실패했습니다.", [NSString stringWithUTF8String:backend]];
    }
    return engine;
  } @finally {
    _engineSettingsDelete(settings);
  }
}

- (void *)createSessionForGeneration
{
  @synchronized (self) {
    if (![self canGenerateLocked]) {
      return NULL;
    }

    void *session = _engineCreateSession(_engine, NULL);
    if (session == NULL) {
      self.lastError = @"LiteRT-LM 세션 생성에 실패했습니다.";
      return NULL;
    }

    _activeSession = session;
    return session;
  }
}

- (void)finishSession:(void *)session
{
  @synchronized (self) {
    if (_activeSession == session) {
      _activeSession = NULL;
    }
  }

  if (session != NULL && _sessionDelete != NULL) {
    _sessionDelete(session);
  }
}

- (BOOL)canGenerateLocked
{
  return _engine != NULL && [self hasRequiredFunctionsLocked];
}

- (void)closeEngineLocked
{
  if (_engine != NULL && _engineDelete != NULL) {
    _engineDelete(_engine);
  }
  _engine = NULL;
  _activeSession = NULL;
  _loadedModelPath = nil;
}

- (NSDictionary<NSString *, id> *)resultWithMessage:(nullable NSString *)message
                                              error:(nullable NSString *)error
{
  if (error.length > 0) {
    self.lastError = error;
  } else {
    self.lastError = nil;
  }

  return @{
    @"message": message ?: [NSNull null],
    @"error": error ?: [NSNull null],
  };
}

@end
