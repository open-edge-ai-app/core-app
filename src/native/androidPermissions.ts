export type AndroidPermission =
  | 'android.permission.READ_CALENDAR'
  | 'android.permission.WRITE_CALENDAR'
  | 'android.permission.READ_EXTERNAL_STORAGE'
  | 'android.permission.READ_MEDIA_IMAGES'
  | 'android.permission.READ_SMS';

export type AndroidPermissionStatus = 'granted' | 'denied' | 'never_ask_again';

export const androidPermissionResults = {
  GRANTED: 'granted' as AndroidPermissionStatus,
};

export async function requestAndroidPermissions(
  _permissions: AndroidPermission[],
): Promise<Partial<Record<AndroidPermission, AndroidPermissionStatus>>> {
  return {};
}
