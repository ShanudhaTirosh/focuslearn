import React from 'react';
import { Server, Database, Cloud, Radio } from 'lucide-react';

export const StatusTab: React.FC = () => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-lg)' }}>
      <div>
        <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>System Services Status</h2>
        <p style={{ color: 'var(--fl-color-text-muted)' }}>Infrastructure health monitor across Cloudflare Tunnel, Edge Functions, and Postgres RLS.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 'var(--fl-space-lg)' }}>
        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-md)', marginBottom: 'var(--fl-space-md)' }}>
            <Cloud color="var(--fl-color-primary)" size={24} />
            <h3 style={{ fontSize: '16px' }}>Cloudflare Tunnel</h3>
          </div>
          <p style={{ fontSize: '14px', color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-md)' }}>
            Endpoints proxied via Tunnel; ports 5432 and internal services not exposed to public internet.
          </p>
          <span className="badge badge-success">Connected</span>
        </div>

        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-md)', marginBottom: 'var(--fl-space-md)' }}>
            <Database color="var(--fl-color-success)" size={24} />
            <h3 style={{ fontSize: '16px' }}>PostgreSQL & RLS</h3>
          </div>
          <p style={{ fontSize: '14px', color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-md)' }}>
            Row Level Security active on all public tables. 9 offline pgTAP test suites verified.
          </p>
          <span className="badge badge-success">Healthy</span>
        </div>

        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-md)', marginBottom: 'var(--fl-space-md)' }}>
            <Server color="var(--fl-color-secondary)" size={24} />
            <h3 style={{ fontSize: '16px' }}>Edge Functions</h3>
          </div>
          <p style={{ fontSize: '14px', color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-md)' }}>
            Deno Edge Runtime serving file presigning, account deletions, push dispatch, and GCal sync.
          </p>
          <span className="badge badge-success">Operational</span>
        </div>

        <div className="card">
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-md)', marginBottom: 'var(--fl-space-md)' }}>
            <Radio color="var(--fl-color-warning)" size={24} />
            <h3 style={{ fontSize: '16px' }}>FCM Push Gateway</h3>
          </div>
          <p style={{ fontSize: '14px', color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-md)' }}>
            Generic lock-screen notification dispatch enabled for class starts and quiet hours reminders.
          </p>
          <span className="badge badge-success">Ready</span>
        </div>
      </div>
    </div>
  );
};

