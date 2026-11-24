import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Shield, Smartphone, Radio, Users, Activity, AlertTriangle, RefreshCw } from 'lucide-react';

interface FamilyRecord {
  id: string;
  name: string;
  created_at: string;
}

interface SupervisedDeviceRecord {
  install_id: string;
  user_id: string;
  device_name: string | null;
  os_version: string | null;
  app_version: string | null;
  last_seen_at: string | null;
}

export const ParentalAdminTab: React.FC = () => {
  const [families, setFamilies] = useState<FamilyRecord[]>([]);
  const [devices, setDevices] = useState<SupervisedDeviceRecord[]>([]);
  const [recentCommandsCount, setRecentCommandsCount] = useState<number>(0);
  const [loading, setLoading] = useState<boolean>(true);

  const fetchParentalData = async () => {
    setLoading(true);
    try {
      const [fRes, dRes, cRes] = await Promise.all([
        supabase.from('families').select('*').limit(50),
        supabase.from('devices').select('*').limit(50),
        supabase.from('remote_commands').select('id', { count: 'exact', head: true }),
      ]);

      setFamilies(fRes.data || []);
      setDevices(dRes.data || []);
      setRecentCommandsCount(cRes.count || 0);
    } catch (err) {
      console.error('Error fetching admin parental data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchParentalData();
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-lg)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: 'bold', display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Shield size={22} color="var(--fl-color-primary)" />
            Family & Parental Device Supervision
          </h2>
          <p style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)' }}>
            System-wide overview of family accounts, child device enrollments, and remote command queues.
          </p>
        </div>

        <button
          onClick={fetchParentalData}
          disabled={loading}
          className="btn btn-secondary"
          style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
        >
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      {/* KPI Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 'var(--fl-space-md)' }}>
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-md)' }}>
          <div style={{ padding: '12px', borderRadius: '12px', backgroundColor: 'rgba(37, 99, 235, 0.1)' }}>
            <Users size={24} color="#2563EB" />
          </div>
          <div>
            <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>
              Registered Families
            </div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{families.length}</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-md)' }}>
          <div style={{ padding: '12px', borderRadius: '12px', backgroundColor: 'rgba(16, 185, 129, 0.1)' }}>
            <Smartphone size={24} color="#10B981" />
          </div>
          <div>
            <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>
              Registered Devices
            </div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{devices.length}</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-md)' }}>
          <div style={{ padding: '12px', borderRadius: '12px', backgroundColor: 'rgba(245, 158, 11, 0.1)' }}>
            <Radio size={24} color="#F59E0B" />
          </div>
          <div>
            <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>
              Total Remote Commands
            </div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{recentCommandsCount}</div>
          </div>
        </div>
      </div>

      {/* Supervised Devices Table */}
      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <div style={{ padding: 'var(--fl-space-md) var(--fl-space-lg)', borderBottom: '1px solid var(--fl-color-border)' }}>
          <h3 style={{ fontSize: '15px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Smartphone size={16} /> Active Supervised Child Devices
          </h3>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th>Device ID</th>
                <th>Device Model</th>
                <th>OS & App Version</th>
                <th>Child User ID</th>
                <th>Last Heartbeat</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {devices.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: 'var(--fl-color-text-muted)' }}>
                    No child devices registered yet.
                  </td>
                </tr>
              ) : (
                devices.map((d) => {
                  const lastSeen = d.last_seen_at ? new Date(d.last_seen_at).getTime() : 0;
                  const isOnline = Date.now() - lastSeen < 15 * 60 * 1000;
                  return (
                    <tr key={d.install_id}>
                      <td style={{ fontFamily: 'monospace', fontSize: '12px' }}>
                        {d.install_id.slice(0, 16)}...
                      </td>
                      <td style={{ fontWeight: 500 }}>
                        {d.device_name || 'Generic Android'}
                      </td>
                      <td style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>
                        Android {d.os_version || 'N/A'} • v{d.app_version || '1.0'}
                      </td>
                      <td style={{ fontFamily: 'monospace', fontSize: '12px' }}>
                        {d.user_id.slice(0, 12)}...
                      </td>
                      <td style={{ fontSize: '12px' }}>
                        {d.last_seen_at ? new Date(d.last_seen_at).toLocaleString() : 'Never'}
                      </td>
                      <td>
                        <span className={`badge ${isOnline ? 'badge-success' : 'badge-secondary'}`}>
                          {isOnline ? '● Online' : '○ Offline'}
                        </span>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
