export interface Device {
  id: string;
  name: string;
  deviceType: string;
  lastSyncAt: string | null;
  isActive: boolean;
  createdAt: string;
}

export interface DevicesResponse {
  devices: Device[];
}

export type ScanPathKind = "default" | "custom";
export type ScanPathSource = "device" | "user";

export interface DeviceScanPath {
  id: string;
  deviceId: string;
  path: string;
  kind: ScanPathKind;
  source: ScanPathSource;
  createdAt: string;
  updatedAt: string;
}

export interface DeviceScanPathsResponse {
  paths: DeviceScanPath[];
}

export type SyncStrategy = "shared" | "per_device";

export interface SaveLocation {
  id: string;
  deviceId: string;
  deviceName: string;
  deviceType: string;
  localPath: string;
  isLatest: boolean;
  latestModifiedAt: string | null;
  modifiedAt: string | null;
  uploadedAt: string | null;
}

export interface Save {
  id: string;
  saveKey: string;
  displayName: string;
  fileSize: number;
  uploadedAt: string;
  lastModifiedAt: string;
  syncStrategy: SyncStrategy;
  locations: SaveLocation[];
  latestVersionDevice: {
    id: string;
    name: string;
    deviceType: string;
  } | null;
}

export interface SavesResponse {
  saves: Save[];
  count: number;
}

export interface AuthUser {
  subscriptionTier: string;
  email?: string;
  name?: string;
  createdAt?: string;
}

export interface AuthState {
  isAuthenticated: boolean;
  isLoading: boolean;
  token: string | null;
  user: AuthUser | null;
}
