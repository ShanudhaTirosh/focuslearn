import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import type { Classroom } from '../lib/types';
import { School, Plus, Copy, Check, RefreshCw, Users, BookOpen } from 'lucide-react';

interface ClassroomsTabProps {
  classrooms: Classroom[];
  onRefresh: () => void;
}

export const ClassroomsTab: React.FC<ClassroomsTabProps> = ({ classrooms, onRefresh }) => {
  const [showCreate, setShowCreate] = useState(false);
  const [name, setName] = useState('');
  const [subject, setSubject] = useState('');
  const [schoolName, setSchoolName] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

  const generateInviteCode = () => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  };

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setSubmitting(true);
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const inviteCode = generateInviteCode();
      const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(); // 30 days

      const { error } = await supabase.from('classrooms').insert({
        teacher_id: user.id,
        name: name.trim(),
        subject: subject.trim() || null,
        school_name: schoolName.trim() || null,
        invite_code: inviteCode,
        invite_expires_at: expiresAt,
      });

      if (error) throw error;
      setName('');
      setSubject('');
      setSchoolName('');
      setShowCreate(false);
      onRefresh();
    } catch (err: any) {
      alert(`Error creating classroom: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const copyCode = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(code);
    setTimeout(() => setCopiedCode(null), 2500);
  };

  const handleRegenerateCode = async (classroomId: string) => {
    const newCode = generateInviteCode();
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    try {
      const { error } = await supabase
        .from('classrooms')
        .update({
          invite_code: newCode,
          invite_expires_at: expiresAt,
        })
        .eq('id', classroomId);

      if (error) throw error;
      onRefresh();
    } catch (err: any) {
      alert(`Error regenerating code: ${err.message}`);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold flex items-center gap-2">
            <School className="w-5 h-5 text-teal-600" />
            Classroom Management
          </h2>
          <p className="text-sm text-gray-500">
            Create classrooms, share 6-character enrollment codes with students and parents.
          </p>
        </div>

        <button
          onClick={() => setShowCreate(!showCreate)}
          className="btn btn-primary"
        >
          <Plus className="w-4 h-4 mr-1.5" />
          {showCreate ? 'Cancel' : 'New Classroom'}
        </button>
      </div>

      {showCreate && (
        <form onSubmit={handleCreate} className="card space-y-4 border-teal-500/30">
          <h3 className="text-base font-semibold text-gray-900 dark:text-gray-100">
            Create a New Classroom
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Classroom Name *
              </label>
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Grade 12 - Physics A"
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Subject
              </label>
              <input
                type="text"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                placeholder="e.g. Combined Mathematics"
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                School or Institution
              </label>
              <input
                type="text"
                value={schoolName}
                onChange={(e) => setSchoolName(e.target.value)}
                placeholder="e.g. Royal College"
                className="input-field"
              />
            </div>
          </div>
          <div className="flex justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={() => setShowCreate(false)}
              className="btn btn-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="btn btn-primary"
            >
              {submitting ? 'Creating...' : 'Create Classroom & Generate Code'}
            </button>
          </div>
        </form>
      )}

      {classrooms.length === 0 ? (
        <div className="card text-center py-12">
          <BookOpen className="w-12 h-12 mx-auto text-teal-600 mb-3 opacity-60" />
          <h3 className="text-base font-semibold">No classrooms created yet</h3>
          <p className="text-sm text-gray-500 mt-1 max-w-sm mx-auto">
            Create your first classroom to get an enrollment code for your students and begin tracking educational goals.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {classrooms.map((c) => (
            <div key={c.id} className="card flex flex-col justify-between">
              <div>
                <div className="flex items-start justify-between">
                  <h3 className="font-bold text-lg text-gray-900 dark:text-gray-100">
                    {c.name}
                  </h3>
                  {c.subject && (
                    <span className="badge badge-info">{c.subject}</span>
                  )}
                </div>
                {c.school_name && (
                  <p className="text-xs text-gray-500 mt-0.5">{c.school_name}</p>
                )}

                <div className="mt-5 p-3 rounded-lg bg-gray-50 dark:bg-gray-800/80 border border-gray-100 dark:border-gray-700">
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-gray-500 font-medium">Student Invite Code</span>
                    <button
                      onClick={() => handleRegenerateCode(c.id)}
                      title="Generate new invite code"
                      className="text-xs text-teal-600 hover:underline flex items-center gap-1"
                    >
                      <RefreshCw className="w-3 h-3" /> Regenerate
                    </button>
                  </div>
                  <div className="flex items-center justify-between mt-1">
                    <span className="font-mono text-xl font-bold tracking-widest text-teal-600 dark:text-teal-400">
                      {c.invite_code || '------'}
                    </span>
                    {c.invite_code && (
                      <button
                        onClick={() => copyCode(c.invite_code!)}
                        className="btn btn-secondary py-1 px-2.5 text-xs"
                      >
                        {copiedCode === c.invite_code ? (
                          <>
                            <Check className="w-3.5 h-3.5 text-emerald-500 mr-1" /> Copied
                          </>
                        ) : (
                          <>
                            <Copy className="w-3.5 h-3.5 mr-1" /> Copy Code
                          </>
                        )}
                      </button>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-5 pt-3 border-t border-gray-100 dark:border-gray-800 text-xs text-gray-400 flex items-center justify-between">
                <span>Created {new Date(c.created_at).toLocaleDateString()}</span>
                <span className="flex items-center gap-1 text-teal-600 font-medium">
                  <Users className="w-3.5 h-3.5" /> Enrolled Students
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
