Pod::Spec.new do |s|
  s.name = 'OpenEdgeLiteRTLMRuntime'
  s.version = '0.1.0'
  s.summary = 'Local LiteRT-LM iOS runtime frameworks for Open Edge AI.'
  s.description = 'Links LiteRT-LM C API frameworks built locally from upstream source.'
  s.homepage = 'https://github.com/open-edge-ai-app/core-app'
  s.license = { :type => 'Apache-2.0' }
  s.author = { 'Open Edge AI' => 'open-edge-ai' }
  s.source = { :path => '.' }
  s.platform = :ios, '15.1'
  s.vendored_frameworks = ['Frameworks/GemmaModelConstraintProvider.xcframework']
  s.frameworks = ['AVFoundation', 'AVFAudio', 'AudioToolbox']
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'FRAMEWORK_SEARCH_PATHS' => '"$(PODS_ROOT)/../Frameworks"',
    'OTHER_LDFLAGS' => '$(inherited) -lc++ -framework AVFoundation -framework AVFAudio -framework AudioToolbox -framework GemmaModelConstraintProvider',
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -lc++ -framework AVFoundation -framework AVFAudio -framework AudioToolbox -framework GemmaModelConstraintProvider -force_load "$(PODS_ROOT)/../Frameworks/LiteRTLM.xcframework/ios-arm64/LiteRTLM.framework/LiteRTLM"',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited) -lc++ -framework AVFoundation -framework AVFAudio -framework AudioToolbox -framework GemmaModelConstraintProvider -force_load "$(PODS_ROOT)/../Frameworks/LiteRTLM.xcframework/ios-arm64-simulator/LiteRTLM.framework/LiteRTLM"',
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'FRAMEWORK_SEARCH_PATHS' => '"$(PODS_ROOT)/../Frameworks"',
    'OTHER_LDFLAGS' => '$(inherited) -framework AVFoundation -framework AVFAudio -framework AudioToolbox -framework GemmaModelConstraintProvider',
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -framework AVFoundation -framework AVFAudio -framework AudioToolbox -framework GemmaModelConstraintProvider -force_load "$(PODS_ROOT)/../Frameworks/LiteRTLM.xcframework/ios-arm64/LiteRTLM.framework/LiteRTLM"',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited) -framework AVFoundation -framework AVFAudio -framework AudioToolbox -framework GemmaModelConstraintProvider -force_load "$(PODS_ROOT)/../Frameworks/LiteRTLM.xcframework/ios-arm64-simulator/LiteRTLM.framework/LiteRTLM"',
  }
end
