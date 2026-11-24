import React from 'react';
import { Users, Smartphone, Clock, ShieldAlert, Wifi, Battery, AlertTriangle, ArrowRight } from 'lucide-react';
import { ChildProfile, ChildDevice, ViolationAuditItem } from '../lib/types';

interface OverviewTabProps {
  children: ChildProfile[];
  devices: ChildDevice[];
  violations: ViolationAuditItem[];
  onNavigate: (tab: any) => void;
}

export const OverviewTab: React.FC<OverviewTabProps> = ({ children, devices, violations, onNavigate }) => {
  const activeDevices = devices.filter(d => !d.revoked_at);
  const onlineDevices = activeDevices.filter(d => {
    if (!d.last_seen_at) return false;
    const diff = Date.now() - new Date(d.last_seen_at).getTime();
    return diff < 15 * 60 * 1000; // seen within 15 minutes
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      {/* Top Banner / Hero */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--fl-space-md)' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Family Protection Overview</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>
            Monitor your children's device health, screen time, and digital safety rules in real time.
          </p>
        </div>
        <div style={{ display: 'flex', gap: 'var(--fl-space-sm)' }}>
          <button className="btn btn-primary" onClick={() => onNavigate('children')}>
            <Users size={16} /> Manage Children
          </button>
          <button className="btn btn-secondary" onClick={() => onNavigate('devices')}>
            <Smartphone size={16} /> Supervised Devices ({activeDevices.length})
          </button>
        </div>
      </div>

      {/* Metrics Row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 'var(--fl-space-lg)' }}>
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', background: 'rgba(37, 99, 235, 0.1)' }}>
            <Users size={28} color="var(--fl-color-primary)" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', fontWeight: 500 }}>Protected Children</div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{children.length}</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', background: 'rgba(22, 163, 74, 0.1)' }}>
            <Smartphone size={28} color="var(--fl-color-success)" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', fontWeight: 500 }}>Online Devices</div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>
              {onlineDevices.length} / {activeDevices.length}
            </div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', background: 'rgba(245, 158, 11, 0.1)' }}>
            <AlertTriangle size={28} color="var(--fl-color-warning)" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', fontWeight: 500 }}>Distractions Blocked</div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{violations.length}</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', background: 'rgba(2, 132, 199, 0.1)' }}>
            <Clock size={28} color="var(--fl-color-info)" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', fontWeight: 500 }}>Daily Screen Limit</div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>Active</div>
          </div>
        </div>
      </div>

      {/* Children Quick Status Grid */}
      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--fl-space-md)' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 600 }}>Children & Connected Devices</h3>
          <button className="btn btn-secondary" style={{ fontSize: '12px', padding: '4px 8px' }} onClick={() => onNavigate('children')}>
            View All <ArrowRight size={14} />
          </button>
        </div>

        {children.length === 0 ? (
          <div className="card" style={{ textAlign: 'center', padding: 'var(--fl-space-xxl)' }}>
            <Users size={48} color="var(--fl-color-text-muted)" style={{ margin: '0 auto var(--fl-space-md)' }} />
            <h4 style={{ fontSize: '16px', fontWeight: 600 }}>No Child Profiles Registered Yet</h4>
            <p style={{ color: 'var(--fl-color-text-muted)', fontSize: '14px', maxWidth: '420px', margin: 'var(--fl-space-xs) auto var(--fl-space-lg)' }}>
              Add your child's profile to generate a secure 6-digit pairing code for their Android phone or tablet.
            </p>
            <button className="btn btn-primary" onClick={() => onNavigate('children')}>
              Add First Child Profile
            </button>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 'var(--fl-space-lg)' }}>
            {children.map(c => {
              const childDevs = devices.filter(d => d.user_id === c.child_id && !d.revoked_at);
              return (
                <div key={c.id} className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-sm)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ fontWeight: 600, fontSize: '16px' }}>{c.display_name}</div>
                    <span className={`badge ${c.status === 'active' ? 'badge-success' : 'badge-warning'}`}>
                      {c.status === 'active' ? 'Paired' : 'Pending Pairing'}
                    </span>
                  </div>
                  <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)' }}>
                    Birth Year: {c.birth_year} (Age ~{new Date().getFullYear() - c.birth_year})
                  </div>

                  {c.status === 'pending' && c.pairing_code && (
                    <div style={{ background: 'var(--fl-color-surface-variant)', padding: 'var(--fl-space-sm)', borderRadius: 'var(--fl-radius-sm)', marginTop: 'var(--fl-space-xs)' }}>
                      <div style={{ fontSize: '11px', color: 'var(--fl-color-text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>Pairing Code</div>
                      <div style={{ fontSize: '20px', fontWeight: 'bold', letterSpacing: '4px', color: 'var(--fl-color-primary)' }}>{c.pairing_code}</div>
                    </div>
                  )}

                  <div style={{ marginTop: 'var(--fl-space-xs)', borderTop: '1px solid var(--fl-color-border)', paddingTop: 'var(--fl-space-sm)' }}>
                    <div style={{ fontSize: '12px', fontWeight: 600, color: 'var(--fl-color-text-muted)', marginBottom: '4px' }}>
                      Connected Devices ({childDevs.length})
                    </div>
                    {childDevs.length === 0 ? (
                      <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)' }}>No device paired yet.</div>
                    ) : (
                      childDevs.map(d => (
                        <div key={d.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '13px', padding: '2px 0' }}>
                          <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <Smartphone size={14} color="var(--fl-color-primary)" /> {d.name}
                          </span>
                          <span style={{ fontSize: '11px', color: 'var(--fl-color-text-muted)' }}>
                            {d.battery_level ? `${d.battery_level}%` : 'Online'}
                          </span>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Recent Distraction Violations Stream */}
      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--fl-space-md)' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
            <ShieldAlert size={20} color="var(--fl-color-error)" /> Recent Safety & Study Violations ({violations.length})
          </h3>
          <button className="btn btn-secondary" style={{ fontSize: '12px', padding: '4px 8px' }} onClick={() => onNavigate('violations')}>
            View All <ArrowRight size={14} />
          </button>
        </div>

        {violations.length === 0 ? (
          <p style={{ color: 'var(--fl-color-text-muted)', fontSize: '14px' }}>
            No distraction attempts or rule violations detected. All children are adhering to their study schedules!
          </p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table>
              <thead>
                <tr>
                  <th>Restricted App</th>
                  <th>Type</th>
                  <th>Occurred At</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {violations.slice(0, 5).map(v => (
                  <tr key={v.id}>
                    <td style={{ fontWeight: 600 }}>{v.package_name}</td>
                    <td>
                      <span className="badge badge-warning">{v.violation_type}</span>
                    </td>
                    <td style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)' }}>
                      {new Date(v.occurred_at).toLocaleString()}
                    </td>
                    <td>
                      <span className="badge badge-success">Intercepted & Blocked</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
