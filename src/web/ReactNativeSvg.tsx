import React from 'react';
import {StyleSheet} from 'react-native';

type SvgShimProps = {
  children?: React.ReactNode;
  style?: unknown;
  [key: string]: unknown;
};

const flattenStyle = (style: unknown) =>
  style ? (StyleSheet.flatten(style) as React.CSSProperties) : undefined;

const createSvgElement = <ElementType extends keyof React.JSX.IntrinsicElements>(
  element: ElementType,
) =>
  React.forwardRef<Element, SvgShimProps>(
    ({children, style, ...props}, ref) =>
      React.createElement(
        element as React.ElementType,
        {
          ...props,
          ref,
          style: flattenStyle(style),
        },
        children as React.ReactNode,
      ),
  );

export const Svg = createSvgElement('svg');
export const Path = createSvgElement('path');
export const Rect = createSvgElement('rect');
export const Defs = createSvgElement('defs');
export const Mask = createSvgElement('mask');
export const G = createSvgElement('g');
export const ClipPath = createSvgElement('clipPath');

export default Svg;
