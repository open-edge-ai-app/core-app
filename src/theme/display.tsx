import React, {
  createContext,
  forwardRef,
  ReactNode,
  useCallback,
  useContext,
  useMemo,
  useState,
} from 'react';
import {
  StyleProp,
  StyleSheet,
  Text as RNText,
  TextInput as RNTextInput,
  TextInputProps,
  TextProps,
  TextStyle,
} from 'react-native';

export type TextSizeOptionId = 'compact' | 'default' | 'large';

export type TextSizeOption = {
  description: string;
  id: TextSizeOptionId;
  label: string;
  scale: number;
};

export const textSizeOptions: TextSizeOption[] = [
  {
    description: '한 화면에 더 많은 내용을 보여줘요.',
    id: 'compact',
    label: '작게',
    scale: 0.86,
  },
  {
    description: 'iPhone 기본에 가까운 균형 잡힌 크기예요.',
    id: 'default',
    label: '기본',
    scale: 0.94,
  },
  {
    description: '읽기 편한 큰 글씨로 보여줘요.',
    id: 'large',
    label: '크게',
    scale: 1.08,
  },
];

type DisplaySettingsContextValue = {
  selectedTextSize: TextSizeOption;
  setTextSize: (nextTextSize: TextSizeOptionId) => void;
  textScale: number;
  textSize: TextSizeOptionId;
  textSizes: TextSizeOption[];
};

const DisplaySettingsContext =
  createContext<DisplaySettingsContextValue | null>(null);

const fallbackTextSize = textSizeOptions[0];
const textSizeStorageKey = 'open-edge-ai:text-size';

function isTextSizeOptionId(value: string | null): value is TextSizeOptionId {
  return textSizeOptions.some(option => option.id === value);
}

function getLocalStorage() {
  try {
    return globalThis.localStorage;
  } catch {
    return undefined;
  }
}

function readStoredTextSize() {
  let storedTextSize: string | null = null;

  try {
    storedTextSize = getLocalStorage()?.getItem(textSizeStorageKey) ?? null;
  } catch {
    storedTextSize = null;
  }

  return isTextSizeOptionId(storedTextSize)
    ? storedTextSize
    : fallbackTextSize.id;
}

function writeStoredTextSize(nextTextSize: TextSizeOptionId) {
  try {
    getLocalStorage()?.setItem(textSizeStorageKey, nextTextSize);
  } catch {
    return;
  }
}

export function DisplaySettingsProvider({ children }: { children: ReactNode }) {
  const [textSize, setTextSizeState] =
    useState<TextSizeOptionId>(readStoredTextSize);

  const setTextSize = useCallback((nextTextSize: TextSizeOptionId) => {
    setTextSizeState(nextTextSize);
    writeStoredTextSize(nextTextSize);
  }, []);

  const value = useMemo<DisplaySettingsContextValue>(() => {
    const selectedTextSize =
      textSizeOptions.find(option => option.id === textSize) ??
      textSizeOptions[0];

    return {
      selectedTextSize,
      setTextSize,
      textScale: selectedTextSize.scale,
      textSize,
      textSizes: textSizeOptions,
    };
  }, [setTextSize, textSize]);

  return (
    <DisplaySettingsContext.Provider value={value}>
      {children}
    </DisplaySettingsContext.Provider>
  );
}

export function useDisplaySettings() {
  const context = useContext(DisplaySettingsContext);

  if (!context) {
    throw new Error(
      'useDisplaySettings must be used within DisplaySettingsProvider.',
    );
  }

  return context;
}

function useTextScale() {
  return (
    useContext(DisplaySettingsContext)?.textScale ?? fallbackTextSize.scale
  );
}

function scaleTextStyle(style: StyleProp<TextStyle>, scale: number) {
  const flattenedStyle = StyleSheet.flatten(style);

  if (!flattenedStyle || scale === 1) {
    return style;
  }

  const scaledStyle = { ...flattenedStyle };

  if (typeof scaledStyle.fontSize === 'number') {
    scaledStyle.fontSize = Number((scaledStyle.fontSize * scale).toFixed(2));
  }

  if (typeof scaledStyle.lineHeight === 'number') {
    scaledStyle.lineHeight = Number(
      (scaledStyle.lineHeight * scale).toFixed(2),
    );
  }

  return scaledStyle;
}

export const ScaledText = forwardRef<
  React.ElementRef<typeof RNText>,
  TextProps
>(({ style, ...props }, ref) => {
  const textScale = useTextScale();

  return (
    <RNText ref={ref} style={scaleTextStyle(style, textScale)} {...props} />
  );
});

ScaledText.displayName = 'ScaledText';

export const ScaledTextInput = forwardRef<
  React.ElementRef<typeof RNTextInput>,
  TextInputProps
>(({ style, ...props }, ref) => {
  const textScale = useTextScale();

  return (
    <RNTextInput
      ref={ref}
      style={scaleTextStyle(style, textScale)}
      {...props}
    />
  );
});

ScaledTextInput.displayName = 'ScaledTextInput';
