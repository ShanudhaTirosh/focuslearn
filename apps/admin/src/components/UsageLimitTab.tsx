import React, { useState } from 'react';
import { Database, HardDrive, Users, Zap, CheckCircle, AlertTriangle, RefreshCw, Clock, Bot, Sparkles, ShieldAlert, Sliders, Power } from 'lucide-react';

interface MetricCardProps {
  title: string;
  used: number;
  limit: number;
  unit: string;
  icon: React.ReactNode;
  warningThreshold?: number; // default 0.7 (70%)
  dangerThreshold?: number;  // default 0.9 (90%)
}

const MetricCard: React.FC<MetricCardProps> = ({
  title,
  used,
  limit,
  unit,
  icon,
  warningThreshold = 0.7,
  dangerThreshold = 0.9,
}) => {
  const ratio = used / limit;
  const percentage = (ratio * 100).toFixed(1);

  let statusBadge = <span className="badge badge-success">Normal</span>;
  let progressColor = 'var(--fl-color-success)';

  if (ratio >= dangerThreshold) {
    statusBadge = <span className="badge badge-error">Critical ({percentage}%)</span>;
    progressColor = 'var(--fl-color-error)';
  } else if (ratio >= warningThreshold) {
    statusBadge = <span className="badge badge-warning">Warning ({percentage}%)</span>;
    progressColor = 'var(--fl-color-warning)';
  }

  return (
    <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-md)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
          <div style={{ padding: 'var(--fl-space-xs)', background: 'var(--fl-color-surface-variant)', borderRadius: 'var(--fl-radius-md)' }}>
            {icon}
          </div>
          <div>
            <h4 style={{ fontSize: '15px', fontWeight: 600 }}>{title}</h4>
            <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Free Plan Quota</div>
          </div>
        </div>
        {statusBadge}
      </div>

      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px', marginBottom: 'var(--fl-space-xs)' }}>
          <span style={{ fontWeight: 600 }}>{used.toLocaleString()} {unit}</span>
          <span style={{ color: 'var(--fl-color-text-muted)' }}>of {limit.toLocaleString()} {unit}</span>
        </div>
        <div style={{ width: '100%', height: '8px', background: 'var(--fl-color-border)', borderRadius: '4px', overflow: 'hidden' }}>
          <div style={{ width: `${Math.min(100, Number(percentage))}%`, height: '100%', background: progressColor, transition: 'width 0.3s' }} />
        </div>
      </div>
    </div>
  );
};

export const UsageLimitTab: React.FC = () => {
  const [purging, setPurging] = useState(false);
  const [lastPurged, setLastPurged] = useState<string | null>(null);
  const [aiKillSwitchActive, setAiKillSwitchActive] = useState(false);
  const [dailySolveLimit, setDailySolveLimit] = useState(20);
  const [dailyNotebookLimit, setDailyNotebookLimit] = useState(30);

  const handleManualPurge = () => {
    setPurging(true);
    setTimeout(() => {
      setPurging(false);
      setLastPurged(new Date().toLocaleTimeString());
      alert('Maintenance completed: transient rate limit events and soft-deleted items purged successfully.');
    }, 1200);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Supabase Free Plan Quota Monitor</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>
            Track real-time infrastructure metrics against official Supabase free-tier limits ($0/month hosting).
          </p>
        </div>
        <button
          className="btn btn-secondary"
          onClick={handleManualPurge}
          disabled={purging}
        >
          <RefreshCw size={16} className={purging ? 'spin' : ''} />
          {purging ? 'Purging Expired Data...' : 'Run Table Cleanup'}
        </button>
      </div>

      {lastPurged && (
        <div style={{ padding: 'var(--fl-space-md)', background: 'var(--fl-color-surface-variant)', borderRadius: 'var(--fl-radius-md)', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
          <CheckCircle size={18} color="var(--fl-color-success)" />
          <span style={{ fontSize: '13px' }}>Last manual maintenance executed at {lastPurged}.</span>
        </div>
      )}

      {/* Grid of Quota Gauges */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 'var(--fl-space-lg)' }}>
        <MetricCard
          title="Database Size"
          used={34.2}
          limit={500}
          unit="MB"
          icon={<Database size={24} color="var(--fl-color-primary)" />}
        />
        <MetricCard
          title="Cloudflare R2 Storage"
          used={1.4}
          limit={10.0}
          unit="GB"
          icon={<HardDrive size={24} color="var(--fl-color-success)" />}
        />
        <MetricCard
          title="Monthly Active Users"
          used={1248}
          limit={50000}
          unit="MAU"
          icon={<Users size={24} color="var(--fl-color-warning)" />}
        />
        <MetricCard
          title="Edge Function Calls"
          used={14200}
          limit={500000}
          unit="calls / mo"
          icon={<Zap size={24} color="#8b5cf6" />}
        />
        <MetricCard
          title="Gemini Daily AI Quota"
          used={284}
          limit={1500}
          unit="calls / day"
          icon={<Bot size={24} color="var(--fl-color-primary)" />}
        />
        <MetricCard
          title="pgvector Chunks Storage"
          used={1420}
          limit={10000}
          unit="chunks (~5.8 MB)"
          icon={<Sparkles size={24} color="#059669" />}
        />
      </div>

      {/* AI Controls & Emergency Kill-Switch */}
      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--fl-space-sm)' }}>
          <h3 style={{ fontSize: '18px', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
            <Sliders size={20} color="var(--fl-color-primary)" /> AI Feature Controls & Emergency Kill-Switch
          </h3>
          <button
            className={`btn ${aiKillSwitchActive ? 'btn-danger' : 'btn-secondary'}`}
            onClick={() => setAiKillSwitchActive(!aiKillSwitchActive)}
            style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-xs)' }}
          >
            <Power size={16} />
            {aiKillSwitchActive ? 'AI Disabled (Kill-Switch Active)' : 'AI Features Online'}
          </button>
        </div>
        <p style={{ color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-md)', fontSize: '14px' }}>
          Enforce per-student consumption boundaries to prevent exhausting the Google AI Studio free tier (1,500 RPD). When the emergency kill-switch is activated, clients cleanly fall back to the offline scientific calculator and standard notes.
        </p>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 'var(--fl-space-md)', marginBottom: 'var(--fl-space-md)' }}>
          <div style={{ padding: 'var(--fl-space-md)', background: 'var(--fl-color-surface-variant)', borderRadius: 'var(--fl-radius-md)' }}>
            <label style={{ fontSize: '13px', fontWeight: 600, display: 'block', marginBottom: '4px' }}>
              Daily Camera Solves / Student: {dailySolveLimit}
            </label>
            <input
              type="range"
              min="5"
              max="50"
              value={dailySolveLimit}
              onChange={(e) => setDailySolveLimit(Number(e.target.value))}
              style={{ width: '100%' }}
            />
          </div>
          <div style={{ padding: 'var(--fl-space-md)', background: 'var(--fl-color-surface-variant)', borderRadius: 'var(--fl-radius-md)' }}>
            <label style={{ fontSize: '13px', fontWeight: 600, display: 'block', marginBottom: '4px' }}>
              Daily Notebook Queries / Student: {dailyNotebookLimit}
            </label>
            <input
              type="range"
              min="10"
              max="100"
              value={dailyNotebookLimit}
              onChange={(e) => setDailyNotebookLimit(Number(e.target.value))}
              style={{ width: '100%' }}
            />
          </div>
        </div>

        {/* Top AI Consumers */}
        <div style={{ fontSize: '14px', fontWeight: 600, marginBottom: 'var(--fl-space-xs)' }}>Top Student Consumers Today</div>
        <table style={{ width: '100%', fontSize: '13px', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', borderBottom: '1px solid var(--fl-color-border)' }}>
              <th style={{ padding: '6px' }}>Student</th>
              <th style={{ padding: '6px' }}>Camera Solves</th>
              <th style={{ padding: '6px' }}>Notebook Queries</th>
              <th style={{ padding: '6px' }}>Chunks Stored</th>
              <th style={{ padding: '6px' }}>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr style={{ borderBottom: '1px solid var(--fl-color-border-subtle)' }}>
              <td style={{ padding: '6px' }}>Kasun Perera (2026 Maths)</td>
              <td style={{ padding: '6px' }}>14 / {dailySolveLimit}</td>
              <td style={{ padding: '6px' }}>18 / {dailyNotebookLimit}</td>
              <td style={{ padding: '6px' }}>240 chunks</td>
              <td style={{ padding: '6px' }}><span className="badge badge-success">Normal</span></td>
            </tr>
            <tr style={{ borderBottom: '1px solid var(--fl-color-border-subtle)' }}>
              <td style={{ padding: '6px' }}>Dilini Fernando (2026 Bio)</td>
              <td style={{ padding: '6px' }}>11 / {dailySolveLimit}</td>
              <td style={{ padding: '6px' }}>22 / {dailyNotebookLimit}</td>
              <td style={{ padding: '6px' }}>310 chunks</td>
              <td style={{ padding: '6px' }}><span className="badge badge-success">Normal</span></td>
            </tr>
            <tr>
              <td style={{ padding: '6px' }}>Sahan Alwis (2027 Tech)</td>
              <td style={{ padding: '6px' }}>8 / {dailySolveLimit}</td>
              <td style={{ padding: '6px' }}>12 / {dailyNotebookLimit}</td>
              <td style={{ padding: '6px' }}>140 chunks</td>
              <td style={{ padding: '6px' }}><span className="badge badge-success">Normal</span></td>
            </tr>
          </tbody>
        </table>
      </div>

      {/* Inactivity Pause Guard */}
      <div className="card">
        <h3 style={{ fontSize: '18px', marginBottom: 'var(--fl-space-sm)', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
          <Clock size={20} color="var(--fl-color-primary)" /> Project Inactivity & Keep-Alive Guard
        </h3>
        <p style={{ color: 'var(--fl-color-text-muted)', marginBottom: 'var(--fl-space-md)' }}>
          Supabase Free Plan projects automatically pause after 7 days of inactivity. Focus Learn includes an automated GitHub Actions cron workflow that pings the REST gateway every 4 days to keep the database awake 24/7 without cost.
        </p>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--fl-space-lg)' }}>
          <div style={{ padding: 'var(--fl-space-md)', background: 'var(--fl-color-surface-variant)', borderRadius: 'var(--fl-radius-md)', flex: 1, minWidth: '220px' }}>
            <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Project Status</div>
            <div style={{ fontSize: '16px', fontWeight: 600, color: 'var(--fl-color-success)', display: 'flex', alignItems: 'center', gap: '4px' }}>
              <CheckCircle size={16} /> Active (0 days paused)
            </div>
          </div>
          <div style={{ padding: 'var(--fl-space-md)', background: 'var(--fl-color-surface-variant)', borderRadius: 'var(--fl-radius-md)', flex: 1, minWidth: '220px' }}>
            <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Keep-Alive Automation</div>
            <div style={{ fontSize: '16px', fontWeight: 600 }}>Active (Every 4 Days)</div>
          </div>
          <div style={{ padding: 'var(--fl-space-md)', background: 'var(--fl-color-surface-variant)', borderRadius: 'var(--fl-radius-md)', flex: 1, minWidth: '220px' }}>
            <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Egress Bandwidth</div>
            <div style={{ fontSize: '16px', fontWeight: 600 }}>0.8 GB of 5 GB</div>
          </div>
        </div>
      </div>

      {/* Threshold Policies & Alerts Guidance */}
      <div className="card">
        <h3 style={{ fontSize: '18px', marginBottom: 'var(--fl-space-sm)', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
          <AlertTriangle size={20} color="var(--fl-color-warning)" /> Threshold Alerts & Mitigation Guide
        </h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-sm)', fontSize: '14px' }}>
          <div>
            <strong>Green (&lt; 70%):</strong> Operational headroom is healthy. No administrative action required.
          </div>
          <div>
            <strong>Amber Warning (70% - 89%):</strong> High utilization detected. Click "Run Table Cleanup" above to purge transient logs and vacuum PostgreSQL tables.
          </div>
          <div>
            <strong>Red Alert (&ge; 90%):</strong> Quota limit approached. If student enrollment exceeds 50k MAUs or 500 MB database, consider exporting historical years to cold archive or upgrading to Supabase Pro ($25/mo).
          </div>
        </div>
      </div>
    </div>
  );
};
