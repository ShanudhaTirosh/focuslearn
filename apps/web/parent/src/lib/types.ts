export interface ChildProfile {
  id: string;
  family_id: string;
  parent_id: string;
  child_id: string | null;
  display_name: string;
  birth_year: number;
  pairing_code: string | null;
  status: 'pending' | 'active' | 'revoked';
  created_at: string;
}

export interface ChildDevice {
  id: string;
  user_id: string;
  install_id: string;
  platform: string;
  name: string;
  app_version: string | null;
  last_seen_at: string;
  revoked_at: string | null;
  battery_level?: number | null;
  is_charging?: boolean | null;
  network_type?: string | null;
  is_connected?: boolean;
}

export interface DeviceConfig {
  id: string;
  device_id: string;
  parent_id: string;
  daily_screen_time_limit_minutes: number;
  bedtime_start: string | null;
  bedtime_end: string | null;
  schedule_days: number[];
  study_start: string | null;
  study_end: string | null;
  blocked_packages: string[];
  allowed_packages: string[];
  website_blocklist: string[];
  website_allowlist: string[];
  focus_mode_enabled: boolean;
  last_synced_at: string | null;
}

export interface ScreenTimeRecord {
  id: string;
  device_id: string;
  child_id: string;
  record_date: string;
  total_minutes: number;
  app_breakdown: Record<string, number>;
}

export interface AppUsageRecord {
  id: string;
  device_id: string;
  child_id: string;
  package_name: string;
  app_label: string | null;
  usage_date: string;
  total_minutes: number;
  session_count: number;
}

export interface RemoteCommandItem {
  id: string;
  device_id: string;
  parent_id: string;
  command_type: string;
  payload: Record<string, any>;
  status: 'pending' | 'acknowledged' | 'executed' | 'failed' | 'expired';
  created_at: string;
  acknowledged_at: string | null;
  executed_at: string | null;
  error_message: string | null;
}

export interface ViolationAuditItem {
  id: string;
  student_id: string;
  device_id: string;
  package_name: string;
  violation_type: string;
  occurred_at: string;
}
