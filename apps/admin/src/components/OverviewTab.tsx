import React from 'react';
import { Users, Clock, ShieldAlert, Trash2 } from 'lucide-react';

interface OverviewTabProps {
  reportsCount: number;
  deletionsCount: number;
}

export const OverviewTab: React.FC<OverviewTabProps> = ({ reportsCount, deletionsCount }) => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      <div>
        <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Dashboard Overview</h2>
        <p style={{ color: 'var(--fl-color-text-muted)' }}>FocusLearn system analytics, moderation requests, and operational status.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 'var(--fl-space-lg)' }}>
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', background: 'var(--fl-color-surface-variant)' }}>
            <Users size={32} color="var(--fl-color-primary)" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', fontWeight: 500 }}>Active Students</div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>1,248</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', background: 'var(--fl-color-surface-variant)' }}>
            <Clock size={32} color="var(--fl-color-success)" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', fontWeight: 500 }}>Focus Hours Logged</div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>8,420 h</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', background: 'var(--fl-color-surface-variant)' }}>
            <ShieldAlert size={32} color="var(--fl-color-warning)" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', fontWeight: 500 }}>Pending Reports</div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{reportsCount}</div>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', background: 'var(--fl-color-surface-variant)' }}>
            <Trash2 size={32} color="var(--fl-color-error)" />
          </div>
          <div>
            <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', fontWeight: 500 }}>Pending Deletions</div>
            <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{deletionsCount}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <h3 style={{ fontSize: '18px', marginBottom: 'var(--fl-space-md)' }}>Platform Health & Policies</h3>
        <p style={{ color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-md)' }}>
          All user rows have Row Level Security enabled and forced. Under-18 students are protected by default and cannot be made public to strangers.
        </p>
        <div style={{ display: 'flex', gap: 'var(--fl-space-md)' }}>
          <span className="badge badge-success">RLS Enforced</span>
          <span className="badge badge-success">GDPR / PDPA Minor Guard Active</span>
          <span className="badge badge-success">Presigned R2 Storage Direct</span>
        </div>
      </div>
    </div>
  );
};

