import React, { useState } from 'react';
import { Shield, AlertTriangle, Plus, Key, Lock, CheckCircle2 } from 'lucide-react';

export interface AdminPolicyItem {
  id: string;
  student_id: string;
  creator_id: string;
  title: string;
  mode: string;
  blocked_packages: string[];
  active: boolean;
  created_at: string;
}

export interface AdminViolationItem {
  id: string;
  student_id: string;
  package_name: string;
  violation_type: string;
  occurred_at: string;
}

export interface AdminOverrideItem {
  id: string;
  student_id: string;
  reason: string;
  duration_minutes: number;
  created_at: string;
}

const initialPolicies: AdminPolicyItem[] = [
  {
    id: 'pol-101',
    student_id: 'usr-3333-4444',
    creator_id: 'parent-001',
    title: 'G.C.E. A/L Exam Preparation Strict Focus',
    mode: 'focus_session_lock',
    blocked_packages: ['com.instagram.android', 'com.zhiliaoapp.musically', 'com.google.android.youtube'],
    active: true,
    created_at: new Date(Date.now() - 86400000 * 3).toISOString(),
  },
  {
    id: 'pol-102',
    student_id: 'usr-5555-6666',
    creator_id: 'teacher-101',
    title: 'Combined Maths Study Block (Weekday 16:00-18:00)',
    mode: 'scheduled_window',
    blocked_packages: ['com.facebook.katana', 'com.reddit.frontpage'],
    active: true,
    created_at: new Date(Date.now() - 86400000 * 5).toISOString(),
  },
];

const initialViolations: AdminViolationItem[] = [
  {
    id: 'v-001',
    student_id: 'usr-3333-4444',
    package_name: 'com.instagram.android',
    violation_type: 'distraction_opened',
    occurred_at: new Date(Date.now() - 3600000 * 2).toISOString(),
  },
  {
    id: 'v-002',
    student_id: 'usr-5555-6666',
    package_name: 'com.zhiliaoapp.musically',
    violation_type: 'distraction_opened',
    occurred_at: new Date(Date.now() - 3600000 * 8).toISOString(),
  },
];

const initialOverrides: AdminOverrideItem[] = [
  {
    id: 'o-001',
    student_id: 'usr-3333-4444',
    reason: 'Teacher sent study material link on Telegram',
    duration_minutes: 15,
    created_at: new Date(Date.now() - 3600000 * 5).toISOString(),
  },
];

export const EnforcementTab: React.FC = () => {
  const [policies, setPolicies] = useState<AdminPolicyItem[]>(initialPolicies);
  const [violations] = useState<AdminViolationItem[]>(initialViolations);
  const [overrides] = useState<AdminOverrideItem[]>(initialOverrides);

  // New policy form state
  const [showAddForm, setShowAddForm] = useState(false);
  const [studentId, setStudentId] = useState('');
  const [policyTitle, setPolicyTitle] = useState('');
  const [blockedPackages, setBlockedPackages] = useState('com.instagram.android, com.zhiliaoapp.musically');

  const handleCreatePolicy = (e: React.FormEvent) => {
    e.preventDefault();
    if (!studentId || !policyTitle) return;

    const newPolicy: AdminPolicyItem = {
      id: `pol-${Date.now()}`,
      student_id: studentId,
      creator_id: 'current-admin',
      title: policyTitle,
      mode: 'focus_session_lock',
      blocked_packages: blockedPackages.split(',').map(s => s.trim()).filter(Boolean),
      active: true,
      created_at: new Date().toISOString(),
    };

    setPolicies([newPolicy, ...policies]);
    setShowAddForm(false);
    setStudentId('');
    setPolicyTitle('');
  };

  const handleTogglePolicy = (policyId: string) => {
    setPolicies(prev =>
      prev.map(p => (p.id === policyId ? { ...p, active: !p.active } : p))
    );
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Study Rules & Enforcement</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>
            Supervise study hours, configure app blocklists, and audit student distractions & overrides.
          </p>
        </div>
        <button
          className="btn btn-primary"
          onClick={() => setShowAddForm(!showAddForm)}
        >
          <Plus size={18} /> {showAddForm ? 'Cancel' : 'Create Enforcement Rule'}
        </button>
      </div>

      {showAddForm && (
        <form onSubmit={handleCreatePolicy} className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-md)' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 600 }}>Create New Student Rule</h3>
          <div>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, marginBottom: 'var(--fl-space-xs)' }}>Student User ID</label>
            <input
              type="text"
              placeholder="e.g. usr-1234-5678"
              value={studentId}
              onChange={e => setStudentId(e.target.value)}
              style={{ width: '100%', padding: 'var(--fl-space-sm)', borderRadius: 'var(--fl-radius-md)', border: '1px solid var(--fl-color-border)' }}
              required
            />
          </div>
          <div>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, marginBottom: 'var(--fl-space-xs)' }}>Rule Title</label>
            <input
              type="text"
              placeholder="e.g. Evening Study Focus"
              value={policyTitle}
              onChange={e => setPolicyTitle(e.target.value)}
              style={{ width: '100%', padding: 'var(--fl-space-sm)', borderRadius: 'var(--fl-radius-md)', border: '1px solid var(--fl-color-border)' }}
              required
            />
          </div>
          <div>
            <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, marginBottom: 'var(--fl-space-xs)' }}>Blocked Packages (comma-separated)</label>
            <input
              type="text"
              value={blockedPackages}
              onChange={e => setBlockedPackages(e.target.value)}
              style={{ width: '100%', padding: 'var(--fl-space-sm)', borderRadius: 'var(--fl-radius-md)', border: '1px solid var(--fl-color-border)' }}
              required
            />
          </div>
          <button type="submit" className="btn btn-primary" style={{ alignSelf: 'flex-start' }}>Save Rule</button>
        </form>
      )}

      {/* Active Rules Table */}
      <div className="card">
        <h3 style={{ fontSize: '18px', marginBottom: 'var(--fl-space-md)', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
          <Shield size={20} color="var(--fl-color-primary)" /> Configured Policies ({policies.length})
        </h3>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--fl-color-border)' }}>
                <th style={{ padding: 'var(--fl-space-sm)' }}>Rule Title</th>
                <th style={{ padding: 'var(--fl-space-sm)' }}>Student</th>
                <th style={{ padding: 'var(--fl-space-sm)' }}>Restricted Packages</th>
                <th style={{ padding: 'var(--fl-space-sm)' }}>Status</th>
                <th style={{ padding: 'var(--fl-space-sm)' }}>Action</th>
              </tr>
            </thead>
            <tbody>
              {policies.map(p => (
                <tr key={p.id} style={{ borderBottom: '1px solid var(--fl-color-border)' }}>
                  <td style={{ padding: 'var(--fl-space-md)' }}>
                    <div style={{ fontWeight: 600 }}>{p.title}</div>
                    <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>{p.mode}</div>
                  </td>
                  <td style={{ padding: 'var(--fl-space-md)', fontFamily: 'monospace', fontSize: '12px' }}>{p.student_id}</td>
                  <td style={{ padding: 'var(--fl-space-md)' }}>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--fl-space-xs)' }}>
                      {p.blocked_packages.map(pkg => (
                        <span key={pkg} className="badge badge-secondary" style={{ fontSize: '11px' }}>
                          {pkg.split('.').pop()}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td style={{ padding: 'var(--fl-space-md)' }}>
                    <span className={`badge ${p.active ? 'badge-success' : 'badge-secondary'}`}>
                      {p.active ? 'Active' : 'Disabled'}
                    </span>
                  </td>
                  <td style={{ padding: 'var(--fl-space-md)' }}>
                    <button
                      className="btn btn-secondary"
                      style={{ padding: '4px 8px', fontSize: '12px' }}
                      onClick={() => handleTogglePolicy(p.id)}
                    >
                      {p.active ? 'Disable' : 'Enable'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Grid of Violations and Overrides */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--fl-space-lg)' }}>
        {/* Violations Stream */}
        <div className="card">
          <h3 style={{ fontSize: '18px', marginBottom: 'var(--fl-space-md)', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
            <AlertTriangle size={20} color="var(--fl-color-warning)" /> Intercepted Distractions ({violations.length})
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-sm)' }}>
            {violations.map(v => (
              <div key={v.id} style={{ padding: 'var(--fl-space-sm)', borderBottom: '1px solid var(--fl-color-border)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontWeight: 600 }}>{v.package_name}</span>
                  <span style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>
                    {new Date(v.occurred_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </span>
                </div>
                <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Student: {v.student_id}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Emergency Overrides Stream */}
        <div className="card">
          <h3 style={{ fontSize: '18px', marginBottom: 'var(--fl-space-md)', display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
            <Key size={20} color="var(--fl-color-primary)" /> Emergency Overrides ({overrides.length})
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-sm)' }}>
            {overrides.map(o => (
              <div key={o.id} style={{ padding: 'var(--fl-space-sm)', borderBottom: '1px solid var(--fl-color-border)' }}>
                <div style={{ fontWeight: 600 }}>Reason: "{o.reason}"</div>
                <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)', marginTop: '2px' }}>
                  Student: {o.student_id} • {o.duration_minutes} min unlocked
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
