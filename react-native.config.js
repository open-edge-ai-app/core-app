// iOS is a native SwiftUI app in this repository. Keep the React Native CLI
// from discovering or operating on ios/ while preserving Android workflows.
const disableReactNativeIOS = () => {
  console.error(
    'React Native iOS is disabled for Open Edge AI. Use `npm run ios` for the native SwiftUI app.',
  );
  process.exitCode = 1;
};

const commonDisabledIOSOptions = [
  { name: '--mode <string>' },
  { name: '--scheme <string>' },
  { name: '--configuration <string>' },
  { name: '--simulator <string>' },
  { name: '--device [string]' },
  { name: '--udid <string>' },
  { name: '--binary-path <string>' },
  { name: '--no-packager' },
  { name: '--port <number>' },
  { name: '--terminal <string>' },
  { name: '--list-devices' },
  { name: '--interactive' },
  { name: '--force-pods' },
  { name: '--only-pods' },
  { name: '--destination <string>' },
  { name: '--extra-params <string>' },
];

const disabledIOSCommand = name => ({
  name,
  description: 'disabled because iOS is a native SwiftUI app in this repo',
  func: disableReactNativeIOS,
  options: commonDisabledIOSOptions,
});

module.exports = {
  commands: [
    disabledIOSCommand('run-ios'),
    disabledIOSCommand('build-ios'),
    disabledIOSCommand('log-ios'),
  ],
  project: {
    android: {},
    ios: {
      sourceDir: '.react-native-disabled/ios',
      automaticPodsInstallation: false,
    },
  },
};
