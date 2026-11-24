import React, { useState } from 'react';
import { Users, Plus, Key, Smartphone, Trash2, CheckCircle2, Clock } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { ChildProfile, ChildDevice } from '../lib/types';

interface ChildrenTabProps {
  children: ChildProfile[];
  devices: ChildDevice[];
  onRefresh: () => void;
}

export const ChildrenTab: React.FC<ChildrenTabProps> = ({ children, devices, onRefresh }) => {
  const [showAddModal, setShowAddModal] = useState(false);
  const [displayName, setDisplayName] = useState('');
  const [birthYear, setBirthYear] = useState(new Date().getFullYear() - 14);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [createdPairingCode, setCreatedPairingCode] = useState<string | null>(null);

  const handleAddChild = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!displayName.trim()) return;

    setIsSubmitting(true);
    try {
      const { data: user } = await supabase.auth.getUser();
      const parentId = user.user?.id || 'demo-parent';

      // 1. Get or create family
      let familyId: string;
      const { data: existingFamily } = await supabase
        .from('families')
        .select('id')
        .eq('owner_id', parentId)
        .maybeSingle();

      if (existingFamily) {
        familyId = existingFamily.id;
      } else {
        const { data: newFamily } = await supabase
          .from('families')
          .insert({
            owner_id: parentId,
            name: `${displayName}'s Family`,
          })
          .select('id')
          .single();
        familyId = newFamily?.id || `fam-${Date.now()}`;
      }

      // Generate 6-digit numeric pairing code
      const pairingCode = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = new Date(Date.now() + 48 * 3600 * 1000).toISOString();

      // Insert parent_child_links row
      await supabase.from('parent_child_links').insert({
        family_id: familyId,
        parent_id: parentId,
        display_name: displayName.trim(),
        birth_year: birthYear,
        pairing_code: pairingCode,
        pairing_expires_at: expiresAt,
        status: 'pending',
      });

      setCreatedPairingCode(pairingCode);
      onRefresh();
    } catch (err) {
      console.error('Error adding child:', err);
    } finally {
      setIsSubmitting(false);
      setDisplayName('');
    }
  };

  const handleRegenerateCode = async (linkId: string) => {
    const newCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 48 * 3600 * 1000).toISOString();

    await supabase
      .from('parent_child_links')
      .update({
        pairing_code: newCode,
        pairing_expires_at: expiresAt,
      })
      .eq('id', linkId);

    onRefresh();
  };

  const handleRemoveChild = async (linkId: string) => {
    if (!confirm('Are you sure you want to remove this child profile and revoke connected device supervision?')) return;
    await supabase.from('parent_child_links').delete().eq('id', linkId);
    onRefresh();
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-xl)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold' }}>Children & Pairing Management</h2>
          <p style={{ color: 'var(--fl-color-text-muted)' }}>
            Register your children, generate device pairing codes, and supervise connected devices.
          </p>
        </div>
        <button className="btn btn-primary" onClick={() => { setShowAddModal(true); setCreatedPairingCode(null); }}>
          <Plus size={16} /> Add Child Profile
        </button>
      </div>

      {/* Modal / Form to Add Child */}
      {showAddModal && (
        <div className="card" style={{ borderColor: 'var(--fl-color-primary)', background: 'var(--fl-color-surface-variant)' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 600, marginBottom: 'var(--fl-space-sm)' }}>
            Register New Child Profile
          </h3>
          <p style={{ color: 'var(--fl-color-text-muted)', fontSize: '13px', marginBottom: 'var(--fl-space-md)' }}>
            Enter your child's display name and birth year. A secure 6-digit code will be generated to pair their Android device.
          </p>

          {createdPairingCode ? (
            <div style={{ background: 'var(--fl-color-background)', padding: 'var(--fl-space-lg)', borderRadius: 'var(--fl-radius-md)', textAlign: 'center' }}>
              <CheckCircle2 size={36} color="var(--fl-color-success)" style={{ margin: '0 auto var(--fl-space-sm)' }} />
              <div style={{ fontWeight: 600, fontSize: '16px' }}>Child Profile Created!</div>
              <div style={{ fontSize: '13px', color: 'var(--fl-color-text-muted)', marginTop: '4px' }}>
                Open FocusLearn on your child's Android phone → Settings → Parental Device Management → Enter this code:
              </div>
              <div style={{
                fontSize: '32px',
                fontWeight: 'bold',
                letterSpacing: '8px',
                color: 'var(--fl-color-primary)',
                padding: 'var(--fl-space-md)',
                margin: 'var(--fl-space-md) auto',
                background: 'var(--fl-color-surface-variant)',
                borderRadius: 'var(--fl-radius-md)',
                display: 'inline-block'
              }}>
                {createdPairingCode}
              </div>
              <div style={{ fontSize: '12px', color: 'var(--fl-color-text-muted)' }}>Code expires in 48 hours.</div>
              <div style={{ marginTop: 'var(--fl-space-md)' }}>
                <button className="btn btn-primary" onClick={() => { setShowAddModal(false); setCreatedPairingCode(null); }}>
                  Done
                </button>
              </div>
            </div>
          ) : (
            <form onSubmit={handleAddChild} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--fl-space-md)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, marginBottom: 'var(--fl-space-xs)' }}>
                  Child's Name / Nickname
                </label>
                <input
                  type="text"
                  placeholder="e.g. Kasun, Sarah"
                  value={displayName}
                  onChange={e => setDisplayName(e.target.value)}
                  style={{ width: '100%', padding: 'var(--fl-space-sm)', borderRadius: 'var(--fl-radius-md)', border: '1px solid var(--fl-color-border)' }}
                  required
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: 500, marginBottom: 'var(--fl-space-xs)' }}>
                  Birth Year
                </label>
                <input
                  type="number"
                  min="2000"
                  max={new Date().getFullYear()}
                  value={birthYear}
                  onChange={e => setBirthYear(parseInt(e.target.value) || 2010)}
                  style={{ width: '100%', padding: 'var(--fl-space-sm)', borderRadius: 'var(--fl-radius-md)', border: '1px solid var(--fl-color-border)' }}
                  required
                />
              </div>

              <div style={{ display: 'flex', gap: 'var(--fl-space-sm)' }}>
                <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
                  {isSubmitting ? 'Generating...' : 'Create Profile & Generate Pairing Code'}
                </button>
                <button type="button" className="btn btn-secondary" onClick={() => setShowAddModal(false)}>
                  Cancel
                </button>
              </div>
            </form>
          )}
        </div>
      )}

      {/* Children List */}
      <div className="card">
        <h3 style={{ fontSize: '18px', fontWeight: 600, marginBottom: 'var(--fl-space-md)' }}>
          Registered Children ({children.length})
        </h3>

        {children.length === 0 ? (
          <p style={{ color: 'var(--fl-color-text-muted)', fontSize: '14px' }}>
            No children registered. Click "Add Child Profile" above to get started.
          </p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table>
              <thead>
                <tr>
                  <th>Child</th>
                  <th>Age</th>
                  <th>Pairing Status</th>
                  <th>Pairing Code</th>
                  <th>Paired Devices</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {children.map(c => {
                  const childDevs = devices.filter(d => d.user_id === c.child_id && !d.revoked_at);
                  const isPaired = c.status === 'active';
                  return (
                    <tr key={c.id}>
                      <td style={{ fontWeight: 600 }}>{c.display_name}</td>
                      <td>{new Date().getFullYear() - c.birth_year} yrs ({c.birth_year})</td>
                      <td>
                        <span className={`badge ${isPaired ? 'badge-success' : 'badge-warning'}`}>
                          {isPaired ? 'Paired & Active' : 'Waiting for Device'}
                        </span>
                      </td>
                      <td>
                        {c.pairing_code ? (
                          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--fl-space-xs)' }}>
                            <span style={{ fontWeight: 'bold', letterSpacing: '2px', color: 'var(--fl-color-primary)', fontFamily: 'monospace' }}>
                              {c.pairing_code}
                            </span>
                            <button
                              className="btn btn-secondary"
                              style={{ padding: '2px 6px', fontSize: '11px' }}
                              onClick={() => handleRegenerateCode(c.id)}
                              title="Regenerate code"
                            >
                              New
                            </button>
                          </div>
                        ) : (
                          <span style={{ color: 'var(--fl-color-text-muted)', fontSize: '12px' }}>Used</span>
                        )}
                      </td>
                      <td>
                        {childDevs.length === 0 ? (
                          <span style={{ color: 'var(--fl-color-text-muted)', fontSize: '13px' }}>None</span>
                        ) : (
                          childDevs.map(d => (
                            <div key={d.id} style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '13px' }}>
                              <Smartphone size={13} color="var(--fl-color-primary)" /> {d.name}
                            </div>
                          ))
                        )}
                      </td>
                      <td>
                        <button
                          className="btn btn-secondary"
                          style={{ color: 'var(--fl-color-error)', padding: '4px 8px', fontSize: '12px' }}
                          onClick={() => handleRemoveChild(c.id)}
                          title="Remove child"
                        >
                          <Trash2 size={14} /> Remove
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};
