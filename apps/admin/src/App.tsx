import React, { useState } from 'react';
import { LayoutDashboard, ShieldAlert, Users, FileText, Activity } from 'lucide-react';
import { OverviewTab } from './components/OverviewTab';
import { ModerationTab, ReportItem } from './components/ModerationTab';
import { UsersTab, DeletionRequest } from './components/UsersTab';
import { AuditTab, AuditEntry } from './components/AuditTab';
import { StatusTab } from './components/StatusTab';

const initialReports: ReportItem[] = [
  {
    id: 'rep-001',
    reporter_id: 'usr-1111-2222',
    target_type: 'user',
    target_id: 'usr-3333-4444',
    reason: 'Inappropriate profile display name violating minor protection rules',
    details: 'User has non-compliant text in bio',
    status: 'pending',
    created_at: new Date(Date.now() - 3600000 * 4).toISOString(),
  },
  {
    id: 'rep-002',
    reporter_id: 'usr-5555-6666',
    target_type: 'note',
    target_id: 'not-7777-8888',
    reason: 'Copyrighted exam paper re-upload without permission',
    status: 'pending',
    created_at: new Date(Date.now() - 3600000 * 24).toISOString(),
  },
];

const initialDeletions: DeletionRequest[] = [
  {
    id: 'del-101',
    user_id: 'usr-9999-0000',
    status: 'pending',
    requested_at: new Date(Date.now() - 86400000 * 6).toISOString(),
    scheduled_for: new Date(Date.now() + 86400000 * 1).toISOString(),
  },
];

const initialAuditLogs: AuditEntry[] = [
  {
    id: 'aud-001',
    actor_id: 'adm-0000-1111',
    actor_role: 'admin',
    action: 'report_dismissed',
    entity_type: 'report',
    entity_id: 'rep-000',
    created_at: new Date(Date.now() - 3600000 * 12).toISOString(),
  },
  {
    id: 'aud-002',
    actor_id: 'adm-0000-1111',
    actor_role: 'admin',
    action: 'quota_adjusted',
    entity_type: 'user_quotas',
    entity_id: 'usr-1234-5678',
    created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
  },
];

export const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'overview' | 'moderation' | 'users' | 'audit' | 'status'>('overview');
  const [reports, setReports] = useState<ReportItem[]>(initialReports);
  const [deletions, setDeletions] = useState<DeletionRequest[]>(initialDeletions);
  const [auditLogs, setAuditLogs] = useState<AuditEntry[]>(initialAuditLogs);

  const handleActionReport = (reportId: string, status: 'actioned' | 'dismissed') => {
    setReports(prev => prev.map(r => r.id === reportId ? { ...r, status } : r));
    setAuditLogs(prev => [
      {
        id: `aud-${Date.now()}`,
        actor_id: 'current-admin',
        actor_role: 'admin',
        action: `report_${status}`,
        entity_type: 'report',
        entity_id: reportId,
        created_at: new Date().toISOString(),
      },
      ...prev,
    ]);
  };

  const handleTriggerDeletionJob = () => {
    alert('Simulating Edge Function account-delete: scheduled records processed and purged.');
    setDeletions(prev => prev.map(d => ({ ...d, status: 'done' })));
  };

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>
      {/* Sidebar */}
      <aside style={{
        width: '260px',
        backgroundColor: 'var(--fl-color-surface-variant)',
        borderRight: '1px solid var(--fl-color-border)',
        padding: 'var(--fl-space-lg)',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--fl-space-xl)'
      }}>
        <div>
          <div style={{ fontSize: '18px', fontWeight: 'bold', color: 'var(--fl-color-primary)' }}>FocusLearn</div>
          <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Admin & Moderation Portal</div>
        </div>

        <nav style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xs)' }}>
          <button
            onClick={() => setActiveTab('overview')}
            className={`btn ${activeTab === 'overview' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ width: '100%', justifyContent: 'flex-start' }}
          >
            <LayoutDashboard size={18} /> Overview
          </button>
          <button
            onClick={() => setActiveTab('moderation')}
            className={`btn ${activeTab === 'moderation' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ width: '100%', justifyContent: 'flex-start' }}
          >
            <ShieldAlert size={18} /> Moderation Queue
          </button>
          <button
            onClick={() => setActiveTab('users')}
            className={`btn ${activeTab === 'users' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ width: '100%', justifyContent: 'flex-start' }}
          >
            <Users size={18} /> Users & Deletions
          </button>
          <button
            onClick={() => setActiveTab('audit')}
            className={`btn ${activeTab === 'audit' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ width: '100%', justifyContent: 'flex-start' }}
          >
            <FileText size={18} /> Audit Log
          </button>
          <button
            onClick={() => setActiveTab('status')}
            className={`btn ${activeTab === 'status' ? 'btn-primary' : 'btn-secondary'}`}
            style={{ width: '100%', justifyContent: 'flex-start' }}
          >
            <Activity size={18} /> System Status
          </button>
        </nav>
      </aside>

      {/* Main Content Area */}
      <main style={{ flex: 1, padding: 'var(--fl-space-xxl)', overflowY: 'auto' }}>
        {activeTab === 'overview' && (
          <OverviewTab
            reportsCount={reports.filter(r => r.status === 'pending').length}
            deletionsCount={deletions.filter(d => d.status === 'pending').length}
          />
        )}
        {activeTab === 'moderation' && (
          <ModerationTab reports={reports} onAction={handleActionReport} />
        )}
        {activeTab === 'users' && (
          <UsersTab deletions={deletions} onTriggerDeletionJob={handleTriggerDeletionJob} />
        )}
        {activeTab === 'audit' && (
          <AuditTab logs={auditLogs} />
        )}
        {activeTab === 'status' && (
          <StatusTab />
        )}
      </main>
    </div>
  );
};

