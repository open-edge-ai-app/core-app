import { PermissionsAndroid } from 'react-native';

export type AndroidPermission = Parameters<
  typeof PermissionsAndroid.requestMultiple
>[0][number];

export const androidPermissionResults = PermissionsAndroid.RESULTS;

export async function requestAndroidPermissions(
  permissions: AndroidPermission[],
) {
  return PermissionsAndroid.requestMultiple(permissions);
}
