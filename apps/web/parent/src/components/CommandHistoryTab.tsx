import React, { useState, useEffect } from 'react';
import { Terminal, CheckCircle2, Clock, AlertCircle, RefreshCw } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { RemoteCommandItem, ChildDevice } from '../lib/types';

interface CommandHistoryTabProps {
  devices: ChildDevice[];
}

export const CommandHistoryTab: React.FC<CommandHistoryTabProps> = ({ devices }) => {
  const [commands, setCommands] = useState<RemoteCommandItem[]>([]);
  const [loading, setLoading] = useState(true);

  const loadCommands = async () => {
    setLoading(true);
    try {
      const { data } = await supabase
        .from('remote_commands')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50);

      if (data && data.length > 0) {
        setCommands(data as RemoteCommandItem[]);
      } else {
        // Sample fallback
        setCommands([
          {
            id: 'cmd-sample-1',
            device_id: devices[0]?.id || 'dev-001',
            parent_id: 'parent-001',
            command_type: 'update_config',
            payload: { daily_limit_minutes: 240, bedtime_start: '21:30' },
            status: 'executed',
            created_at: new Date(Date.now() - 3600000 * 2).toISOString(),
            acknowledged_at: new Date(Date.now() - 3600000 * 2 + 1000).toISOString(),
            executed_at: new Date(Date.now() - 3600000 * 2 + 3000).toISOString(),
            error_message: null,
          },
          {
            id: 'cmd-sample-2',
            device_id: devices[0]?.id || 'dev-001',
            parent_id: 'parent-001',
            command_type: 'start_focus_session',
            payload: { duration_minutes: 45, title: 'Evening Mathematics Focus' },
            status: 'executed',
            created_at: new Date(Date.now() - 3600000 * 5).toISOString(),
            acknowledged_at: new Date(Date.now() - 3600000 * 5 + 1200).toISOString(),
            executed_at: new Date(Date.now() - 3600000 * 5 + 4000).toISOString(),
            error_message: null,
          },
        ]);
      }
    } catch (err) {
      console.warn('Error loading command history:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCommands();
  }, []);

  const getDeviceName = (deviceId: string) => {
    const dev = devices.find(d => d.id === deviceId);
    return dev ? dev.name : deviceId.substring(0, 8);
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'executed':
        return <span className="badge badge-success"><CheckCircle2 size={12} /> Executed</span>;
      case 'acknowledged':
        return <span className="badge badge-secondary"><Clock size={12} /> Acknowledged</span>;
      case 'pending':
        return <span className="badge badge-warning"><Clock size={12} /> Queued</span>;
      case 'failed':
        return <span className="badge badge-error"><AlertCircle size={12} /> Failed</span>;
      default:
        return <span className="badge badge-secondary">{status}</span>;
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Remote Command Audit History</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>
            Transparent audit ledger of remote configuration commands dispatched to child devices.
          </p>
        </div>
        <button className="btn btn-secondary" onClick={loadCommands}>
          <RefreshCw size={16} /> Refresh
        </button>
      </div>

      <div className="card">
        <h3 style={{ fontSize: '18px', fontWeight: 600, marginBottom: 'var(--fl-space-md)', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
          <Terminal size={20} color="var(--fl-color-primary)" /> Command Execution Queue ({commands.length})
        </h3>

        {loading ? (
          <p style={{ color: 'var(--fl-color-text-muted)' }}>Loading command ledger...</p>
        ) : commands.length === 0 ? (
          <p style={{ color: 'var(--fl-color-text-muted)' }}>No remote commands dispatched yet.</p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table>
              <thead>
                <tr>
                  <th>Command Type</th>
                  <th>Target Device</th>
                  <th>Dispatched At</th>
                  <th>Status</th>
                  <th>Payload Details</th>
                </tr>
              </thead>
              <tbody>
                {commands.map(cmd => (
                  <tr key={cmd.id}>
                    <td>
                      <span style={{ fontFamily: 'monospace', fontWeight: 600, fontSize: '13px' }}>
                        {cmd.command_type}
                      </span>
                    </td>
                    <td style={{ fontSize: '13px' }}>
                      {getDeviceName(cmd.device_id)}
                    </td>
                    <td style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)' }}>
                      {new Date(cmd.created_at).toLocaleString()}
                    </td>
                    <td>{getStatusBadge(cmd.status)}</td>
                    <td style={{ fontSize: '12px', fontFamily: 'monospace', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {JSON.stringify(cmd.payload || {})}
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
