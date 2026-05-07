import React from 'react';
import { IconDefinition } from '@fortawesome/fontawesome-svg-core';
import { FontAwesomeIcon } from '@fortawesome/react-native-fontawesome';

type AppIconProps = {
  color: string;
  icon: IconDefinition;
  size: number;
};

function AppIcon({ color, icon, size }: AppIconProps) {
  return <FontAwesomeIcon color={color} icon={icon} size={size} />;
}

export default AppIcon;
