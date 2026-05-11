/* eslint-env jest */

const mockAsyncStorageStore = new Map();

jest.mock('@react-native-async-storage/async-storage', () => ({
  __esModule: true,
  default: {
    clear: jest.fn(() => {
      mockAsyncStorageStore.clear();
      return Promise.resolve();
    }),
    getItem: jest.fn(key =>
      Promise.resolve(mockAsyncStorageStore.get(key) ?? null),
    ),
    removeItem: jest.fn(key => {
      mockAsyncStorageStore.delete(key);
      return Promise.resolve();
    }),
    setItem: jest.fn((key, value) => {
      mockAsyncStorageStore.set(key, value);
      return Promise.resolve();
    }),
  },
}));
