import React, { useState, useEffect } from 'react';
import { Shield, Plus, X, Globe, Save, Check, AlertCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { ChildDevice } from '../lib/types';

interface AppRestrictionsTabProps {
  devices: ChildDevice[];
}

const COMMON_APPS = [
  { name: 'TikTok', package: 'com.zhiliaoapp.musically', category: 'Social' },
  { name: 'Instagram', package: 'com.instagram.android', category: 'Social' },
  { name: 'YouTube', package: 'com.google.android.youtube', category: 'Video' },
  { name: 'Facebook', package: 'com.facebook.katana', category: 'Social' },
  { name: 'Snapchat', package: 'com.snapchat.android', category: 'Social' },
  { name: 'Roblox', package: 'com.roblox.client', category: 'Gaming' },
  { name: 'Discord', package: 'com.discord', category: 'Chat' },
  { name: 'Reddit', package: 'com.reddit.frontpage', category: 'Social' },
];

export const AppRestrictionsTab: React.FC<AppRestrictionsTabProps> = ({ devices }) => {
  const activeDevices = devices.filter(d => !d.revoked_at);
  const [selectedDeviceId, setSelectedDeviceId] = useState<string>(activeDevices[0]?.id || '');

  const [blockedPackages, setBlockedPackages] = useState<string[]>([
    'com.zhiliaoapp.musically',
    'com.instagram.android',
    'com.roblox.client',
  ]);
  const [websiteBlocklist, setWebsiteBlocklist] = useState<string[]>([
    'tiktok.com',
    'instagram.com',
    'roblox.com',
  ]);

  const [customPackage, setCustomPackage] = useState('');
  const [customDomain, setCustomDomain] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    if (activeDevices.length > 0 && !selectedDeviceId) {
      setSelectedDeviceId(activeDevices[0].id);
    }
  }, [activeDevices]);

  useEffect(() => {
    if (!selectedDeviceId) return;

    async function loadRules() {
      const { data: config } = await supabase
        .from('device_configs')
        .select('blocked_packages, website_blocklist')
        .eq('device_id', selectedDeviceId)
        .maybeSingle();

      if (config) {
        if (config.blocked_packages && config.blocked_packages.length > 0) {
          setBlockedPackages(config.blocked_packages);
        }
        if (config.website_blocklist && config.website_blocklist.length > 0) {
          setWebsiteBlocklist(config.website_blocklist);
        }
      }
    }

    loadRules();
  }, [selectedDeviceId]);

  const togglePackage = (pkg: string) => {
    setBlockedPackages(prev =>
      prev.includes(pkg) ? prev.filter(p => p !== pkg) : [...prev, pkg]
    );
  };

  const handleAddCustomPackage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!customPackage.trim()) return;
    const clean = customPackage.trim().toLowerCase();
    if (!blockedPackages.includes(clean)) {
      setBlockedPackages([...blockedPackages, clean]);
    }
    setCustomPackage('');
  };

  const handleAddCustomDomain = (e: React.FormEvent) => {
    e.preventDefault();
    if (!customDomain.trim()) return;
    const clean = customDomain.trim().toLowerCase().replace(/^https?:\/\//, '').replace(/\/.*$/, '');
    if (!websiteBlocklist.includes(clean)) {
      setWebsiteBlocklist([...websiteBlocklist, clean]);
    }
    setCustomDomain('');
  };

  const removeDomain = (domain: string) => {
    setWebsiteBlocklist(prev => prev.filter(d => d !== domain));
  };

  const handleSaveRules = async () => {
    if (!selectedDeviceId) return;
    setIsSaving(true);
    setSaveSuccess(false);

    try {
      const { data: user } = await supabase.auth.getUser();
      const parentId = user.user?.id || 'demo-parent';

      await supabase.from('device_configs').upsert({
        device_id: selectedDeviceId,
        parent_id: parentId,
        blocked_packages: blockedPackages,
        website_blocklist: websiteBlocklist,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'device_id' });

      // Queue command to device
      await supabase.from('remote_commands').insert({
        device_id: selectedDeviceId,
        parent_id: parentId,
        command_type: 'update_config',
        payload: {
          blocked_packages: blockedPackages,
          website_blocklist: websiteBlocklist,
        },
        idempotency_key: `apps-${selectedDeviceId}-${Date.now()}`,
        status: 'pending',
      });

      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (err) {
      console.error('Error saving app rules:', err);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Application & Web Restrictions</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>
            Supervise entertainment apps and websites restricted during scheduled study windows.
          </p>
        </div>
        <button className="btn btn-primary" onClick={handleSaveRules} disabled={isSaving || !selectedDeviceId}>
          {saveSuccess ? (
            <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Check size={16} /> Saved!</span>
          ) : (
            <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Save size={16} /> {isSaving ? 'Saving...' : 'Save & Push Rules'}</span>
          )}
        </button>
      </div>

      {activeDevices.length > 1 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
          <label style={{ fontSize: '14px', fontWeight: 500 }}>Target Device:</label>
          <select
            value={selectedDeviceId}
            onChange={e => setSelectedDeviceId(e.target.value)}
            style={{ padding: '6px 12px', borderRadius: 'var(--fl-radius-sm)', border: '1px solid var(--fl-color-border)', background: 'var(--fl-color-background)', color: 'var(--fl-color-text)' }}
          >
            {activeDevices.map(d => (
              <option key={d.id} value={d.id}>{d.name}</option>
            ))}
          </select>
        </div>
      )}

      {/* Grid: App restrictions + Web restrictions */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--fl-space-lg)' }}>
        {/* App Blocklist Card */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-md)' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
            <Shield size={20} color="var(--fl-color-primary)" /> Restricted Applications ({blockedPackages.length})
          </h3>
          <p style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)' }}>
            When a child opens any blocked app during a study session, FocusLearn displays a study overlay and brings the learning app to the front.
          </p>

          {/* Quick Select Common Apps */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xs)' }}>
            {COMMON_APPS.map(app => {
              const isBlocked = blockedPackages.includes(app.package);
              return (
                <div
                  key={app.package}
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    padding: 'var(--fl-space-sm)',
                    borderRadius: 'var(--fl-radius-sm)',
                    background: isBlocked ? 'rgba(220, 38, 38, 0.06)' : 'var(--fl-color-surface-variant)',
                    border: `1px solid ${isBlocked ? 'rgba(220, 38, 38, 0.2)' : 'var(--fl-color-border)'}`,
                  }}
                >
                  <div>
                    <div style={{ fontWeight: 600, fontSize: '14px' }}>{app.name}</div>
                    <div style={{ fontSize: '11px', color: 'var(--fl-color-text-muted)' }}>{app.category} • {app.package}</div>
                  </div>
                  <button
                    type="button"
                    className={`btn ${isBlocked ? 'btn-danger' : 'btn-secondary'}`}
                    style={{ fontSize: '12px', padding: '4px 10px' }}
                    onClick={() => togglePackage(app.package)}
                  >
                    {isBlocked ? 'Blocked' : 'Allow'}
                  </button>
                </div>
              );
            })}
          </div>

          {/* Custom Package Form */}
          <form onSubmit={handleAddCustomPackage} style={{ display: 'flex', gap: 'var(--fl-space-xs)', marginTop: 'var(--fl-space-sm)' }}>
            <input
              type="text"
              placeholder="Custom package e.g. com.game.racing"
              value={customPackage}
              onChange={e => setCustomPackage(e.target.value)}
              style={{ flex: 1, padding: '8px', borderRadius: 'var(--fl-radius-sm)', border: '1px solid var(--fl-color-border)' }}
            />
            <button type="submit" className="btn btn-secondary">
              <Plus size={16} /> Add
            </button>
          </form>
        </div>

        {/* Web Blocklist Card */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-md)' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 'var(--fl-space-sm)' }}>
            <Globe size={20} color="var(--fl-color-info)" /> Website Blocklists ({websiteBlocklist.length})
          </h3>
          <p style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)' }}>
            Filter inappropriate or distracting domains across supported browsers and web links.
          </p>

          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--fl-space-xs)' }}>
            {websiteBlocklist.map(domain => (
              <span
                key={domain}
                className="badge badge-secondary"
                style={{ fontSize: '13px', padding: '6px 10px', display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                {domain}
                <button
                  type="button"
                  onClick={() => removeDomain(domain)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center' }}
                  title="Remove domain"
                >
                  <X size={13} color="var(--fl-color-error)" />
                </button>
              </span>
            ))}
          </div>

          {/* Custom Domain Form */}
          <form onSubmit={handleAddCustomDomain} style={{ display: 'flex', gap: 'var(--fl-space-xs)', marginTop: 'var(--fl-space-md)' }}>
            <input
              type="text"
              placeholder="e.g. distracting-games.com"
              value={customDomain}
              onChange={e => setCustomDomain(e.target.value)}
              style={{ flex: 1, padding: '8px', borderRadius: 'var(--fl-radius-sm)', border: '1px solid var(--fl-color-border)' }}
            />
            <button type="submit" className="btn btn-secondary">
              <Plus size={16} /> Block Site
            </button>
          </form>

          <div style={{ background: 'var(--fl-color-surface-variant)', padding: 'var(--fl-space-md)', borderRadius: 'var(--fl-radius-md)', fontSize: '12px', color: 'var(--fl-color-text-muted)', marginTop: 'auto' }}>
            <strong>Note on Android Filtering:</strong> Website filtering operates on browser navigation intents and DNS policies supported by the child companion application.
          </div>
        </div>
      </div>
    </div>
  );
};
