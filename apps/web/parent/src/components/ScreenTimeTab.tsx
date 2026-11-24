import React, { useState, useEffect } from 'react';
import { Clock, Moon, BookOpen, Save, Check, Smartphone, BarChart3 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { ChildDevice, ChildProfile, DeviceConfig, AppUsageRecord } from '../lib/types';

interface ScreenTimeTabProps {
  devices: ChildDevice[];
  children: ChildProfile[];
}

export const ScreenTimeTab: React.FC<ScreenTimeTabProps> = ({ devices, children }) => {
  const activeDevices = devices.filter(d => !d.revoked_at);
  const [selectedDeviceId, setSelectedDeviceId] = useState<string>(activeDevices[0]?.id || '');

  // Form states
  const [dailyLimitHours, setDailyLimitHours] = useState<number>(4);
  const [bedtimeStart, setBedtimeStart] = useState<string>('21:30');
  const [bedtimeEnd, setBedtimeEnd] = useState<string>('06:30');
  const [studyStart, setStudyStart] = useState<string>('16:00');
  const [studyEnd, setStudyEnd] = useState<string>('18:00');
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  // Usage records
  const [usageList, setUsageList] = useState<AppUsageRecord[]>([]);

  useEffect(() => {
    if (activeDevices.length > 0 && !selectedDeviceId) {
      setSelectedDeviceId(activeDevices[0].id);
    }
  }, [activeDevices]);

  useEffect(() => {
    if (!selectedDeviceId) return;

    async function loadConfigAndUsage() {
      // 1. Load config
      const { data: config } = await supabase
        .from('device_configs')
        .select('*')
        .eq('device_id', selectedDeviceId)
        .maybeSingle();

      if (config) {
        setDailyLimitHours(Math.round((config.daily_screen_time_limit_minutes || 240) / 60));
        setBedtimeStart(config.bedtime_start || '21:30');
        setBedtimeEnd(config.bedtime_end || '06:30');
        setStudyStart(config.study_start || '16:00');
        setStudyEnd(config.study_end || '18:00');
      }

      // 2. Load usage
      const { data: usage } = await supabase
        .from('app_usage_records')
        .select('*')
        .eq('device_id', selectedDeviceId)
        .order('total_minutes', { ascending: false })
        .limit(15);

      if (usage && usage.length > 0) {
        setUsageList(usage as AppUsageRecord[]);
      } else {
        // Sample baseline if new device
        setUsageList([
          { id: 'u1', device_id: selectedDeviceId, child_id: '', package_name: 'com.whatsapp', app_label: 'WhatsApp', usage_date: 'today', total_minutes: 45, session_count: 12 },
          { id: 'u2', device_id: selectedDeviceId, child_id: '', package_name: 'com.google.android.youtube', app_label: 'YouTube', usage_date: 'today', total_minutes: 70, session_count: 4 },
          { id: 'u3', device_id: selectedDeviceId, child_id: '', package_name: 'com.shanutechx.focuslearn', app_label: 'FocusLearn Companion', usage_date: 'today', total_minutes: 90, session_count: 3 },
          { id: 'u4', device_id: selectedDeviceId, child_id: '', package_name: 'com.duolingo', app_label: 'Duolingo', usage_date: 'today', total_minutes: 25, session_count: 2 },
        ]);
      }
    }

    loadConfigAndUsage();
  }, [selectedDeviceId]);

  const handleSaveConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedDeviceId) return;

    setIsSaving(true);
    setSaveSuccess(false);

    try {
      const { data: user } = await supabase.auth.getUser();
      const parentId = user.user?.id || 'demo-parent';

      await supabase.from('device_configs').upsert({
        device_id: selectedDeviceId,
        parent_id: parentId,
        daily_screen_time_limit_minutes: dailyLimitHours * 60,
        bedtime_start: bedtimeStart,
        bedtime_end: bedtimeEnd,
        study_start: studyStart,
        study_end: studyEnd,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'device_id' });

      // Queue an update_config remote command to push to device immediately
      await supabase.from('remote_commands').insert({
        device_id: selectedDeviceId,
        parent_id: parentId,
        command_type: 'update_config',
        payload: {
          daily_limit_minutes: dailyLimitHours * 60,
          bedtime_start: bedtimeStart,
          bedtime_end: bedtimeEnd,
        },
        idempotency_key: `cfg-${selectedDeviceId}-${Date.now()}`,
        status: 'pending',
      });

      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (err) {
      console.error('Error saving config:', err);
    } finally {
      setIsSaving(false);
    }
  };

  const totalUsedMinutes = usageList.reduce((acc, item) => acc + item.total_minutes, 0);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      <div>
        <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Screen Time & Schedules</h2>
        <p style={{ color: 'var(--fl-color-text-muted)' }}>
          Set daily recreational screen limits, scheduled downtime, and review app usage breakdowns.
        </p>
      </div>

      {activeDevices.length > 1 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
          <label style={{ fontSize: '14px', fontWeight: 500 }}>Select Supervised Device:</label>
          <select
            value={selectedDeviceId}
            onChange={e => setSelectedDeviceId(e.target.value)}
            style={{ padding: '6px 12px', borderRadius: 'var(--fl-radius-sm)', border: '1px solid var(--fl-color-border)', background: 'var(--fl-color-background)', color: 'var(--fl-color-text)' }}
          >
            {activeDevices.map(d => (
              <option key={d.id} value={d.id}>{d.name}</option>
            ))}
          </select>
        </div>
      )}

      {/* Grid: Settings form + Usage Summary */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--fl-space-lg)' }}>
        {/* Controls Card */}
        <form onSubmit={handleSaveConfig} className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-lg)' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
            <Clock size={20} color="var(--fl-color-primary)" /> Daily Time & Schedule Limits
          </h3>

          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--fl-space-xs)' }}>
              <label style={{ fontSize: '14px', fontWeight: 500 }}>Daily Screen Time Allowance</label>
              <span style={{ fontWeight: 'bold', color: 'var(--fl-color-primary)' }}>{dailyLimitHours} Hours</span>
            </div>
            <input
              type="range"
              min="1"
              max="10"
              step="1"
              value={dailyLimitHours}
              onChange={e => setDailyLimitHours(parseInt(e.target.value))}
              style={{ width: '100%' }}
            />
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: 'var(--fl-color-text-muted)', marginTop: '2px' }}>
              <span>1 hr</span>
              <span>5 hrs</span>
              <span>10 hrs</span>
            </div>
          </div>

          <div style={{ borderTop: '1px solid var(--fl-color-border)', paddingTop: 'var(--fl-space-md)' }}>
            <h4 style={{ fontSize: '15px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '6px', marginBottom: 'var(--fl-space-sm)' }}>
              <Moon size={16} color="var(--fl-color-secondary)" /> Bedtime Downtime Schedule
            </h4>
            <p style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-sm)' }}>
              Entertainment apps are locked during bedtime hours to ensure healthy sleep.
            </p>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--fl-space-md)' }}>
              <div>
                <label style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Bedtime Starts</label>
                <input
                  type="time"
                  value={bedtimeStart}
                  onChange={e => setBedtimeStart(e.target.value)}
                  style={{ width: '100%', padding: '6px', borderRadius: 'var(--fl-radius-sm)', border: '1px solid var(--fl-color-border)' }}
                />
              </div>
              <div>
                <label style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Bedtime Ends</label>
                <input
                  type="time"
                  value={bedtimeEnd}
                  onChange={e => setBedtimeEnd(e.target.value)}
                  style={{ width: '100%', padding: '6px', borderRadius: 'var(--fl-radius-sm)', border: '1px solid var(--fl-color-border)' }}
                />
              </div>
            </div>
          </div>

          <div style={{ borderTop: '1px solid var(--fl-color-border)', paddingTop: 'var(--fl-space-md)' }}>
            <h4 style={{ fontSize: '15px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '6px', marginBottom: 'var(--fl-space-sm)' }}>
              <BookOpen size={16} color="var(--fl-color-success)" /> Dedicated Study Window
            </h4>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--fl-space-md)' }}>
              <div>
                <label style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Study Starts</label>
                <input
                  type="time"
                  value={studyStart}
                  onChange={e => setStudyStart(e.target.value)}
                  style={{ width: '100%', padding: '6px', borderRadius: 'var(--fl-radius-sm)', border: '1px solid var(--fl-color-border)' }}
                />
              </div>
              <div>
                <label style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Study Ends</label>
                <input
                  type="time"
                  value={studyEnd}
                  onChange={e => setStudyEnd(e.target.value)}
                  style={{ width: '100%', padding: '6px', borderRadius: 'var(--fl-radius-sm)', border: '1px solid var(--fl-color-border)' }}
                />
              </div>
            </div>
          </div>

          <button type="submit" className="btn btn-primary" disabled={isSaving} style={{ alignSelf: 'flex-start' }}>
            {saveSuccess ? (
              <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Check size={16} /> Saved & Synced!</span>
            ) : (
              <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Save size={16} /> {isSaving ? 'Saving...' : 'Apply & Sync to Device'}</span>
            )}
          </button>
        </form>

        {/* Usage Breakdown Card */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-md)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '18px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
              <BarChart3 size={20} color="var(--fl-color-success)" /> Today's Usage Breakdown
            </h3>
            <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--fl-color-primary)' }}>
              Total: {Math.floor(totalUsedMinutes / 60)}h {totalUsedMinutes % 60}m
            </span>
          </div>

          {/* Simple Visual Bar */}
          <div style={{ height: '14px', borderRadius: '999px', background: 'var(--fl-color-surface-variant)', overflow: 'hidden', display: 'flex' }}>
            {usageList.map((item, idx) => {
              const colors = ['#2563EB', '#16A34A', '#F59E0B', '#DC2626', '#8B5CF6'];
              const pct = totalUsedMinutes > 0 ? (item.total_minutes / totalUsedMinutes) * 100 : 0;
              return (
                <div
                  key={item.id}
                  style={{ width: `${pct}%`, height: '100%', background: colors[idx % colors.length] }}
                  title={`${item.app_label || item.package_name}: ${item.total_minutes}m`}
                />
              );
            })}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-sm)', marginTop: 'var(--fl-space-sm)' }}>
            {usageList.map(item => (
              <div key={item.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', borderBottom: '1px solid var(--fl-color-border)' }}>
                <div>
                  <div style={{ fontWeight: 500, fontSize: '14px' }}>{item.app_label || item.package_name}</div>
                  <div style={{ fontSize: '11px', color: 'var(--fl-color-text-muted)' }}>{item.package_name}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontWeight: 'bold', fontSize: '14px' }}>{item.total_minutes} min</div>
                  <div style={{ fontSize: '11px', color: 'var(--fl-color-text-muted)' }}>
                    {Math.round((item.total_minutes / (dailyLimitHours * 60)) * 100)}% of daily
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
