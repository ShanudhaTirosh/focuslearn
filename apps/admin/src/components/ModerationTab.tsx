import React from 'react';
import { Check, X, Shield } from 'lucide-react';

export interface ReportItem {
  id: string;
  reporter_id: string;
  target_type: string;
  target_id: string;
  reason: string;
  details?: string;
  status: 'pending' | 'reviewed' | 'actioned' | 'dismissed';
  created_at: string;
}

interface ModerationTabProps {
  reports: ReportItem[];
  onAction: (reportId: string, status: 'actioned' | 'dismissed') => void;
}

export const ModerationTab: React.FC<ModerationTabProps> = ({ reports, onAction }) => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-lg)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Moderation Queue</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>Review community reports on spam, harassment, or improper shared notes.</p>
        </div>
      </div>

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        {reports.length === 0 ? (
          <div style={{ padding: 'var(--fl-space-xxl)', textAlign: 'center', color: 'var(--fl-color-text-muted)' }}>
            <Shield size={48} style={{ margin: '0 auto 16px auto', opacity: 0.5 }} />
            <div>No pending moderation reports! Great job keeping the community safe.</div>
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Reason</th>
                <th>Target ID</th>
                <th>Reported At</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {reports.map((r) => (
                <tr key={r.id}>
                  <td style={{ fontWeight: 600, textTransform: 'capitalize' }}>{r.target_type}</td>
                  <td>
                    <div>{r.reason}</div>
                    {r.details && <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>{r.details}</div>}
                  </td>
                  <td style={{ fontFamily: 'monospace', fontSize: '12px' }}>{r.target_id.slice(0, 8)}...</td>
                  <td style={{ fontSize: '13px' }}>{new Date(r.created_at).toLocaleDateString()}</td>
                  <td>
                    <span className={`badge badge-${r.status === 'pending' ? 'pending' : r.status === 'actioned' ? 'error' : 'success'}`}>
                      {r.status}
                    </span>
                  </td>
                  <td>
                    {r.status === 'pending' && (
                      <div style={{ display: 'flex', gap: 'var(--fl-space-xs)' }}>
                        <button
                          className="btn btn-danger"
                          onClick={() => onAction(r.id, 'actioned')}
                          title="Take action (suspend/warn)"
                        >
                          <Check size={14} /> Ban/Action
                        </button>
                        <button
                          className="btn btn-secondary"
                          onClick={() => onAction(r.id, 'dismissed')}
                          title="Dismiss report"
                        >
                          <X size={14} /> Dismiss
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};

