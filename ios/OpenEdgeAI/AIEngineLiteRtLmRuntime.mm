#import "AIEngineLiteRtLmRuntime.h"

#import <dlfcn.h>
#import <stdbool.h>
#import <string.h>

static NSString *const AIEngineLiteRtLmRuntimeErrorDomain = @"OpenEdgeAI.LiteRtLMRuntime";
static NSString *const AIEngineLiteRtLmMissingRuntimeMessage =
  @"LiteRT-LM iOS 런타임 라이브러리가 앱 번들에 없습니다. 공식 CLiteRTLM.framework, libLiteRTLM.dylib 또는 LiteRTLM.framework를 Frameworks에 포함해야 Gemma 4를 iOS에서 실행할 수 있습니다.";

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
typedef void *(*LiteRtLmConversationCreateFn)(void *engine, void *conversationConfig);
typedef void (*LiteRtLmConversationDeleteFn)(void *conversation);
typedef void *(*LiteRtLmConversationSendMessageFn)(void *conversation, const char *messageJSON, const char *extraContextJSON, const void *optionalArgs);
typedef int (*LiteRtLmConversationSendMessageStreamFn)(void *conversation, const char *messageJSON, const char *extraContextJSON, const void *optionalArgs, LiteRtLmStreamCallback callback, void *callbackData);
typedef void (*LiteRtLmConversationCancelFn)(void *conversation);
typedef void (*LiteRtLmJSONResponseDeleteFn)(void *response);
typedef const char *(*LiteRtLmJSONResponseGetStringFn)(const void *response);

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
+ (NSString *)displayTextFromStreamChunk:(NSString *)chunk;
+ (nullable NSString *)displayTextFromJSONObject:(id)json;
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
  LiteRtLmConversationCreateFn _conversationCreate;
  LiteRtLmConversationDeleteFn _conversationDelete;
  LiteRtLmConversationSendMessageFn _conversationSendMessage;
  LiteRtLmConversationSendMessageStreamFn _conversationSendMessageStream;
  LiteRtLmConversationCancelFn _conversationCancel;
  LiteRtLmJSONResponseDeleteFn _jsonResponseDelete;
  LiteRtLmJSONResponseGetStringFn _jsonResponseGetString;

  void *_engine;
  void *_activeSession;
  void *_activeConversation;
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

  if ([self canUseConversationAPI]) {
    return [self generateConversationPrompt:prompt];
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

  if ([self canUseConversationAPI]) {
    return [self streamConversationPrompt:prompt onChunk:onChunk];
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
    if (_activeConversation != NULL && _conversationCancel != NULL) {
      _conversationCancel(_activeConversation);
    }
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
    if (_activeConversation != NULL && _conversationCancel != NULL) {
      _conversationCancel(_activeConversation);
      return YES;
    }
    if (_activeSession == NULL || _sessionCancel == NULL) {
      return NO;
    }
    _sessionCancel(_activeSession);
    return YES;
  }
}

- (NSDictionary<NSString *, id> *)generateConversationPrompt:(NSString *)prompt
{
  void *conversation = [self createConversationForGeneration];
  if (conversation == NULL) {
    return [self resultWithMessage:nil error:self.lastError ?: @"LiteRT-LM 대화 세션을 만들지 못했습니다."];
  }

  NSString *messageJSON = [self userMessageJSONForPrompt:prompt];
  const char *messageBytes = messageJSON.UTF8String;
  const char *contextBytes = "{}";

  @try {
    void *response = _conversationSendMessage(conversation, messageBytes, contextBytes, NULL);
    if (response == NULL) {
      return [self resultWithMessage:nil error:@"LiteRT-LM 대화 응답 생성에 실패했습니다."];
    }

    @try {
      const char *responseBytes = _jsonResponseGetString(response);
      NSString *responseText = responseBytes != NULL ? [NSString stringWithUTF8String:responseBytes] : @"";
      NSString *message = [self displayTextFromResponseString:responseText] ?: responseText ?: @"";
      return [self resultWithMessage:message error:nil];
    } @finally {
      _jsonResponseDelete(response);
    }
  } @finally {
    [self finishConversation:conversation];
  }
}

- (NSDictionary<NSString *, id> *)streamConversationPrompt:(NSString *)prompt
                                                   onChunk:(AIEngineLiteRtLmChunkHandler)onChunk
{
  void *conversation = [self createConversationForGeneration];
  if (conversation == NULL) {
    return [self resultWithMessage:nil error:self.lastError ?: @"LiteRT-LM 대화 세션을 만들지 못했습니다."];
  }

  AIEngineLiteRtLmStreamState *state = [[AIEngineLiteRtLmStreamState alloc] init];
  state.output = [[NSMutableString alloc] init];
  state.onChunk = onChunk ?: ^(NSString *chunk) {};
  state.semaphore = dispatch_semaphore_create(0);

  void *callbackData = (__bridge_retained void *)state;
  NSString *messageJSON = [self userMessageJSONForPrompt:prompt];
  const char *messageBytes = messageJSON.UTF8String;
  const char *contextBytes = "{}";

  @try {
    int started = _conversationSendMessageStream(conversation, messageBytes, contextBytes, NULL, AIEngineLiteRtLmRuntimeStreamCallback, callbackData);
    if (started != 0) {
      CFRelease(callbackData);
      return [self resultWithMessage:nil error:@"LiteRT-LM 대화 스트리밍 응답을 시작하지 못했습니다."];
    }

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(180 * NSEC_PER_SEC));
    long waitResult = dispatch_semaphore_wait(state.semaphore, timeout);
    if (waitResult != 0) {
      _conversationCancel(conversation);
      dispatch_time_t cancelTimeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC));
      if (dispatch_semaphore_wait(state.semaphore, cancelTimeout) == 0) {
        CFRelease(callbackData);
      }
      return [self resultWithMessage:nil error:@"LiteRT-LM 대화 응답이 제한 시간 안에 완료되지 않았습니다."];
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
    [self finishConversation:conversation];
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
      NSString *displayText = [AIEngineLiteRtLmRuntime displayTextFromStreamChunk:chunkText];
      if (displayText.length > 0) {
        [state.output appendString:displayText];
        chunkText = displayText;
      } else {
        chunkText = nil;
      }
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
  LiteRtLmConversationCreateFn conversationCreate =
    reinterpret_cast<LiteRtLmConversationCreateFn>(dlsym(handle, "litert_lm_conversation_create"));
  LiteRtLmConversationDeleteFn conversationDelete =
    reinterpret_cast<LiteRtLmConversationDeleteFn>(dlsym(handle, "litert_lm_conversation_delete"));
  LiteRtLmConversationSendMessageFn conversationSendMessage =
    reinterpret_cast<LiteRtLmConversationSendMessageFn>(dlsym(handle, "litert_lm_conversation_send_message"));
  LiteRtLmConversationSendMessageStreamFn conversationSendMessageStream =
    reinterpret_cast<LiteRtLmConversationSendMessageStreamFn>(dlsym(handle, "litert_lm_conversation_send_message_stream"));
  LiteRtLmConversationCancelFn conversationCancel =
    reinterpret_cast<LiteRtLmConversationCancelFn>(dlsym(handle, "litert_lm_conversation_cancel_process"));
  LiteRtLmJSONResponseDeleteFn jsonResponseDelete =
    reinterpret_cast<LiteRtLmJSONResponseDeleteFn>(dlsym(handle, "litert_lm_json_response_delete"));
  LiteRtLmJSONResponseGetStringFn jsonResponseGetString =
    reinterpret_cast<LiteRtLmJSONResponseGetStringFn>(dlsym(handle, "litert_lm_json_response_get_string"));

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
  _conversationCreate = conversationCreate;
  _conversationDelete = conversationDelete;
  _conversationSendMessage = conversationSendMessage;
  _conversationSendMessageStream = conversationSendMessageStream;
  _conversationCancel = conversationCancel;
  _jsonResponseDelete = jsonResponseDelete;
  _jsonResponseGetString = jsonResponseGetString;
  _runtimeLibraryPath = [libraryPath copy];
  self.lastError = nil;
  return YES;
}

- (NSArray<NSString *> *)candidateLibraryPaths
{
  NSMutableArray<NSString *> *paths = [[NSMutableArray alloc] init];
  NSArray<NSString *> *libraryNames = @[
    @"CLiteRTLM.framework/CLiteRTLM",
    @"libCLiteRTLM.dylib",
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

- (void *)createConversationForGeneration
{
  @synchronized (self) {
    if (![self canGenerateLocked] || ![self canUseConversationAPILocked]) {
      return NULL;
    }

    void *conversation = _conversationCreate(_engine, NULL);
    if (conversation == NULL) {
      self.lastError = @"LiteRT-LM 대화 세션 생성에 실패했습니다.";
      return NULL;
    }

    _activeConversation = conversation;
    return conversation;
  }
}

- (void)finishConversation:(void *)conversation
{
  @synchronized (self) {
    if (_activeConversation == conversation) {
      _activeConversation = NULL;
    }
  }

  if (conversation != NULL && _conversationDelete != NULL) {
    _conversationDelete(conversation);
  }
}

- (BOOL)canUseConversationAPI
{
  @synchronized (self) {
    return [self canUseConversationAPILocked];
  }
}

- (BOOL)canUseConversationAPILocked
{
  return
    _conversationCreate != NULL &&
    _conversationDelete != NULL &&
    _conversationSendMessage != NULL &&
    _conversationSendMessageStream != NULL &&
    _conversationCancel != NULL &&
    _jsonResponseDelete != NULL &&
    _jsonResponseGetString != NULL;
}

- (BOOL)canGenerateLocked
{
  return _engine != NULL && [self hasRequiredFunctionsLocked];
}

- (void)closeEngineLocked
{
  if (_activeConversation != NULL && _conversationCancel != NULL) {
    _conversationCancel(_activeConversation);
  }
  _activeConversation = NULL;
  if (_engine != NULL && _engineDelete != NULL) {
    _engineDelete(_engine);
  }
  _engine = NULL;
  _activeSession = NULL;
  _loadedModelPath = nil;
}

- (NSString *)userMessageJSONForPrompt:(NSString *)prompt
{
  NSDictionary<NSString *, id> *message = @{
    @"role": @"user",
    @"content": @[
      @{
        @"type": @"text",
        @"text": prompt ?: @"",
      },
    ],
  };
  NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
  if (data == nil) {
    return @"{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"\"}]}";
  }
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

- (nullable NSString *)displayTextFromResponseString:(NSString *)responseString
{
  return [AIEngineLiteRtLmRuntime displayTextFromStreamChunk:responseString];
}

+ (NSString *)displayTextFromStreamChunk:(NSString *)chunk
{
  if (chunk.length == 0) {
    return @"";
  }

  NSData *data = [chunk dataUsingEncoding:NSUTF8StringEncoding];
  if (data == nil) {
    return chunk;
  }

  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (json == nil) {
    return chunk;
  }

  NSString *extracted = [self displayTextFromJSONObject:json];
  return extracted ?: @"";
}

+ (nullable NSString *)displayTextFromJSONObject:(id)json
{
  if ([json isKindOfClass:[NSString class]]) {
    return (NSString *)json;
  }

  if ([json isKindOfClass:[NSArray class]]) {
    NSMutableString *text = [[NSMutableString alloc] init];
    for (id item in (NSArray *)json) {
      NSString *part = [self displayTextFromJSONObject:item];
      if (part.length > 0) {
        [text appendString:part];
      }
    }
    return text;
  }

  if (![json isKindOfClass:[NSDictionary class]]) {
    return nil;
  }

  NSDictionary *object = (NSDictionary *)json;
  id content = object[@"content"];
  if ([content isKindOfClass:[NSString class]]) {
    return content;
  }
  if ([content isKindOfClass:[NSArray class]]) {
    return [self displayTextFromJSONObject:content];
  }

  id text = object[@"text"];
  if ([text isKindOfClass:[NSString class]]) {
    return text;
  }

  return nil;
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
