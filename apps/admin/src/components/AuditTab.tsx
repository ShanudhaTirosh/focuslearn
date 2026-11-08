import React from 'react';

export interface AuditEntry {
  id: string;
  actor_id: string;
  actor_role: string;
  action: string;
  entity_type: string;
  entity_id: string;
  created_at: string;
}

interface AuditTabProps {
  logs: AuditEntry[];
}

export const AuditTab: React.FC<AuditTabProps> = ({ logs }) => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-lg)' }}>
      <div>
        <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Immutable Audit Log</h2>
        <p style={{ color: 'var(--fl-color-text-muted)' }}>Append-only security and moderation record. Tamper-evident trail of administrative and elevated actions.</p>
      </div>

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <table>
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>Action</th>
              <th>Actor Role</th>
              <th>Entity</th>
              <th>Entity ID</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id}>
                <td style={{ fontSize: '13px' }}>{new Date(log.created_at).toLocaleString()}</td>
                <td style={{ fontWeight: 600 }}>{log.action}</td>
                <td>
                  <span className="badge badge-success">{log.actor_role}</span>
                </td>
                <td style={{ textTransform: 'capitalize' }}>{log.entity_type}</td>
                <td style={{ fontFamily: 'monospace', fontSize: '12px' }}>{log.entity_id.slice(0, 8)}...</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

