import React from 'react';
import { AppRegistry } from 'react-native';
import { createRoot } from 'react-dom/client';

import App from './App';
import { name as appName } from './app.json';
import { branding } from './src/config/branding';

import './web.css';

AppRegistry.registerComponent(appName, () => App);

document.title = branding.webTitle;

const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('Root element was not found.');
}

createRoot(rootElement).render(<App />);
