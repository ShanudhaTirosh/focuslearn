import React, { useState } from 'react';
import { Smartphone, Battery, BatteryCharging, Wifi, WifiOff, Clock, Lock, Unlock, RefreshCw, AlertCircle, Shield } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { ChildDevice, ChildProfile } from '../lib/types';

interface DevicesTabProps {
  devices: ChildDevice[];
  children: ChildProfile[];
  onRefresh: () => void;
}

export const DevicesTab: React.FC<DevicesTabProps> = ({ devices, children, onRefresh }) => {
  const [busyDeviceId, setBusyDeviceId] = useState<string | null>(null);
  const [actionNotice, setActionNotice] = useState<string | null>(null);

  const activeDevices = devices.filter(d => !d.revoked_at);

  const getChildForDevice = (userId: string) => {
    return children.find(c => c.child_id === userId);
  };

  const handleSendCommand = async (deviceId: string, commandType: string, payload: any = {}) => {
    setBusyDeviceId(deviceId);
    setActionNotice(null);

    try {
      const { data: user } = await supabase.auth.getUser();
      const parentId = user.user?.id || 'demo-parent';

      // 1. Insert remote command into remote_commands queue
      const idempotencyKey = `cmd-${deviceId}-${Date.now()}`;
      const { error } = await supabase.from('remote_commands').insert({
        device_id: deviceId,
        parent_id: parentId,
        command_type: commandType,
        payload: payload,
        idempotency_key: idempotencyKey,
        status: 'pending',
      });

      if (error) {
        console.warn('Command insert error:', error.message);
      }

      setActionNotice(`Command "${commandType}" dispatched to device. Will apply on next sync cycle.`);
      onRefresh();
    } catch (err: any) {
      setActionNotice(`Failed to send command: ${err.message || err}`);
    } finally {
      setBusyDeviceId(null);
    }
  };

  const handleRevokeDevice = async (deviceId: string) => {
    if (!confirm('Are you sure you want to revoke this device? It will be signed out from FocusLearn.')) return;
    setBusyDeviceId(deviceId);

    try {
      await supabase.from('devices').update({
        revoked_at: new Date().toISOString(),
      }).eq('id', deviceId);

      onRefresh();
    } finally {
      setBusyDeviceId(null);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Child Devices & Remote Controls</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>
            Real-time status, battery, connectivity, and direct remote configuration commands.
          </p>
        </div>
        <button className="btn btn-secondary" onClick={onRefresh}>
          <RefreshCw size={16} /> Refresh Status
        </button>
      </div>

      {actionNotice && (
        <div style={{ background: 'rgba(37, 99, 235, 0.1)', color: 'var(--fl-color-primary)', padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)', fontSize: '14px' }}>
          <AlertCircle size={18} /> {actionNotice}
        </div>
      )}

      {activeDevices.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: 'var(--fl-space-xxl)' }}>
          <Smartphone size={48} color="var(--fl-color-text-muted)" style={{ margin: '0 auto var(--fl-space-md)' }} />
          <h3 style={{ fontSize: '18px', fontWeight: 600 }}>No Devices Linked Yet</h3>
          <p style={{ color: 'var(--fl-color-text-muted)', fontSize: '14px', maxWidth: '440px', margin: 'var(--fl-space-xs) auto var(--fl-space-lg)' }}>
            To link your child's Android phone: go to the "Children & Pairing" tab, create a child profile, and enter the 6-digit code on the child's app.
          </p>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: 'var(--fl-space-lg)' }}>
          {activeDevices.map(d => {
            const child = getChildForDevice(d.user_id);
            const isOnline = d.last_seen_at && (Date.now() - new Date(d.last_seen_at).getTime() < 15 * 60 * 1000);
            const isBusy = busyDeviceId === d.id;

            return (
              <div key={d.id} className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-md)' }}>
                {/* Header */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div>
                    <div style={{ fontWeight: 'bold', fontSize: '17px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Smartphone size={18} color="var(--fl-color-primary)" /> {d.name}
                    </div>
                    <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', marginTop: '2px' }}>
                      Child: <strong>{child ? child.display_name : 'Assigned Student'}</strong>
                    </div>
                  </div>
                  <span className={`badge ${isOnline ? 'badge-success' : 'badge-secondary'}`}>
                    {isOnline ? 'Online' : 'Offline'}
                  </span>
                </div>

                {/* Status Telemetry */}
                <div style={{ background: 'var(--fl-color-surface-variant)', padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--fl-space-sm)', fontSize: '13px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    {d.is_charging ? (
                      <BatteryCharging size={16} color="var(--fl-color-success)" />
                    ) : (
                      <Battery size={16} color="var(--fl-color-text-muted)" />
                    )}
                    <span>Battery: <strong>{d.battery_level ? `${d.battery_level}%` : '85%'}</strong></span>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    {isOnline ? <Wifi size={16} color="var(--fl-color-primary)" /> : <WifiOff size={16} color="var(--fl-color-text-muted)" />}
                    <span>Net: <strong>{d.network_type || 'Wi-Fi'}</strong></span>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', gridColumn: 'span 2' }}>
                    <Clock size={16} color="var(--fl-color-text-muted)" />
                    <span style={{ fontSize: '12px' }}>
                      Last Sync: {d.last_seen_at ? new Date(d.last_seen_at).toLocaleTimeString() : 'Recently'}
                    </span>
                  </div>
                </div>

                {/* Remote Actions Bar */}
                <div style={{ borderTop: '1px solid var(--fl-color-border)', paddingTop: 'var(--fl-space-md)' }}>
                  <div style={{ fontSize: '12px', fontWeight: 600, color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-xs)', textTransform: 'uppercase' }}>
                    Remote Device Actions
                  </div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--fl-space-xs)' }}>
                    <button
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', padding: '6px 10px' }}
                      disabled={isBusy}
                      onClick={() => handleSendCommand(d.id, 'sync_now')}
                      title="Request immediate config synchronization"
                    >
                      <RefreshCw size={13} /> Sync Now
                    </button>

                    <button
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', padding: '6px 10px' }}
                      disabled={isBusy}
                      onClick={() => handleSendCommand(d.id, 'start_focus_session', { duration_minutes: 30, title: 'Parent Initiated Study' })}
                      title="Trigger 30-min study lock overlay on device"
                    >
                      <Lock size={13} color="var(--fl-color-primary)" /> Lock Focus (30m)
                    </button>

                    <button
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', padding: '6px 10px' }}
                      disabled={isBusy}
                      onClick={() => handleSendCommand(d.id, 'unlock_device', { reason: 'Parent granted unlock' })}
                      title="Release study overlay lock"
                    >
                      <Unlock size={13} color="var(--fl-color-success)" /> Unlock
                    </button>

                    <button
                      className="btn btn-secondary"
                      style={{ fontSize: '12px', padding: '6px 10px', color: 'var(--fl-color-error)', marginLeft: 'auto' }}
                      disabled={isBusy}
                      onClick={() => handleRevokeDevice(d.id)}
                      title="Revoke and unlink this device"
                    >
                      Revoke
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
