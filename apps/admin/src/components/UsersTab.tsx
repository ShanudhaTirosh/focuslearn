import React from 'react';
import { Trash2, AlertTriangle } from 'lucide-react';

export interface DeletionRequest {
  id: string;
  user_id: string;
  status: string;
  requested_at: string;
  scheduled_for: string;
}

interface UsersTabProps {
  deletions: DeletionRequest[];
  onTriggerDeletionJob: () => void;
}

export const UsersTab: React.FC<UsersTabProps> = ({ deletions, onTriggerDeletionJob }) => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-lg)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Users & Account Deletions</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>GDPR and Sri Lanka PDPA compliance queue for user erasure requests.</p>
        </div>
        <button className="btn btn-primary" onClick={onTriggerDeletionJob}>
          <Trash2 size={16} /> Execute Eligible Erasures
        </button>
      </div>

      <div className="card">
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-md)', marginBottom: 'var(--fl-space-md)' }}>
          <AlertTriangle color="var(--fl-color-warning)" size={20} />
          <div style={{ fontSize: '14px' }}>
            Users have a 7-day grace period to cancel deletion requests. After 7 days, execution permanently scrubs profile, sessions, notes, timetable, and R2 file objects.
          </div>
        </div>

        <table>
          <thead>
            <tr>
              <th>Request ID</th>
              <th>User ID</th>
              <th>Requested At</th>
              <th>Scheduled For</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {deletions.map((d) => (
              <tr key={d.id}>
                <td style={{ fontFamily: 'monospace', fontSize: '12px' }}>{d.id.slice(0, 8)}...</td>
                <td style={{ fontFamily: 'monospace', fontSize: '12px' }}>{d.user_id.slice(0, 8)}...</td>
                <td style={{ fontSize: '13px' }}>{new Date(d.requested_at).toLocaleString()}</td>
                <td style={{ fontSize: '13px' }}>{new Date(d.scheduled_for).toLocaleString()}</td>
                <td>
                  <span className={`badge badge-${d.status === 'pending' ? 'pending' : 'success'}`}>
                    {d.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

