import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import type { Classroom, LearningGoal, ClassroomStudent } from '../lib/types';
import { Target, Plus, CheckCircle, Clock, Trash2, RefreshCw } from 'lucide-react';

interface LearningGoalsTabProps {
  classrooms: Classroom[];
}

export const LearningGoalsTab: React.FC<LearningGoalsTabProps> = ({ classrooms }) => {
  const [goals, setGoals] = useState<LearningGoal[]>([]);
  const [students, setStudents] = useState<ClassroomStudent[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);

  const [selectedClassroomId, setSelectedClassroomId] = useState<string>('');
  const [selectedStudentId, setSelectedStudentId] = useState<string>('');
  const [title, setTitle] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (classrooms.length > 0 && !selectedClassroomId) {
      setSelectedClassroomId(classrooms[0].id);
    }
  }, [classrooms]);

  // Load students for dropdown
  useEffect(() => {
    const fetchStudentsForClass = async () => {
      if (!selectedClassroomId) return;
      const { data } = await supabase
        .from('classroom_students')
        .select('*')
        .eq('classroom_id', selectedClassroomId)
        .eq('status', 'active');

      const list: ClassroomStudent[] = data || [];
      if (list.length > 0) {
        // Fetch profiles
        const sIds = list.map((s) => s.child_id);
        const { data: profs } = await supabase.from('profiles').select('user_id, full_name').in('user_id', sIds);
        const pMap = new Map<string, string>();
        (profs || []).forEach((p: any) => pMap.set(p.user_id, p.full_name || 'Student'));

        const augmented = list.map((s) => ({
          ...s,
          student_name: pMap.get(s.child_id) || 'Student ID: ' + s.child_id.slice(0, 8),
        }));
        setStudents(augmented);
        setSelectedStudentId(augmented[0].child_id);
      } else {
        setStudents([]);
        setSelectedStudentId('');
      }
    };
    fetchStudentsForClass();
  }, [selectedClassroomId]);

  const fetchGoals = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('learning_goals')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      const rawGoals: LearningGoal[] = data || [];

      if (rawGoals.length > 0) {
        const sIds = Array.from(new Set(rawGoals.map((g) => g.child_id)));
        const { data: profs } = await supabase.from('profiles').select('user_id, full_name').in('user_id', sIds);
        const pMap = new Map<string, string>();
        (profs || []).forEach((p: any) => pMap.set(p.user_id, p.full_name || 'Student'));

        setGoals(
          rawGoals.map((g) => ({
            ...g,
            student_name: pMap.get(g.child_id) || 'Student ' + g.child_id.slice(0, 8),
          }))
        );
      } else {
        setGoals([]);
      }
    } catch (err) {
      console.error('Error fetching learning goals:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchGoals();
  }, []);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !selectedClassroomId || !selectedStudentId) return;

    setSubmitting(true);
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error } = await supabase.from('learning_goals').insert({
        classroom_id: selectedClassroomId,
        child_id: selectedStudentId,
        teacher_id: user.id,
        title: title.trim(),
        target_date: targetDate || null,
        status: 'active',
      });

      if (error) throw error;
      setTitle('');
      setTargetDate('');
      setShowCreate(false);
      fetchGoals();
    } catch (err: any) {
      alert(`Error setting learning goal: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleToggleStatus = async (goalId: string, currentStatus: string) => {
    const nextStatus = currentStatus === 'active' ? 'achieved' : 'active';
    try {
      const { error } = await supabase
        .from('learning_goals')
        .update({ status: nextStatus })
        .eq('id', goalId);

      if (error) throw error;
      fetchGoals();
    } catch (err: any) {
      alert(`Error updating goal status: ${err.message}`);
    }
  };

  const handleDelete = async (goalId: string) => {
    if (!confirm('Delete this learning goal?')) return;
    try {
      const { error } = await supabase.from('learning_goals').delete().eq('id', goalId);
      if (error) throw error;
      fetchGoals();
    } catch (err: any) {
      alert(`Error deleting goal: ${err.message}`);
    }
  };

  const getClassroomName = (classId: string) => {
    const c = classrooms.find((cls) => cls.id === classId);
    return c ? c.name : 'Unknown Class';
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold flex items-center gap-2">
            <Target className="w-5 h-5 text-teal-600" />
            Educational & Learning Goals
          </h2>
          <p className="text-sm text-gray-500">
            Define individual milestones, study goals, and exam preparation targets for students.
          </p>
        </div>

        <button
          onClick={() => setShowCreate(!showCreate)}
          className="btn btn-primary"
        >
          <Plus className="w-4 h-4 mr-1.5" />
          {showCreate ? 'Cancel' : 'Set New Goal'}
        </button>
      </div>

      {showCreate && (
        <form onSubmit={handleCreate} className="card space-y-4 border-teal-500/30">
          <h3 className="text-base font-semibold">Set Learning Goal</h3>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Classroom *
              </label>
              <select
                required
                value={selectedClassroomId}
                onChange={(e) => setSelectedClassroomId(e.target.value)}
                className="input-field"
              >
                {classrooms.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Student *
              </label>
              <select
                required
                value={selectedStudentId}
                onChange={(e) => setSelectedStudentId(e.target.value)}
                className="input-field"
                disabled={students.length === 0}
              >
                {students.length === 0 ? (
                  <option value="">No enrolled students in class</option>
                ) : (
                  students.map((s) => (
                    <option key={s.child_id} value={s.child_id}>
                      {s.student_name}
                    </option>
                  ))
                )}
              </select>
            </div>

            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Target Date
              </label>
              <input
                type="date"
                value={targetDate}
                onChange={(e) => setTargetDate(e.target.value)}
                className="input-field"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
              Goal Objective / Milestone *
            </label>
            <input
              type="text"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Complete 20 Past Paper questions on Thermodynamics"
              className="input-field"
            />
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
              disabled={submitting || students.length === 0}
              className="btn btn-primary"
            >
              {submitting ? 'Setting Goal...' : 'Assign Goal'}
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <div className="card text-center py-12">
          <RefreshCw className="w-8 h-8 animate-spin mx-auto text-teal-600 mb-2" />
          <p className="text-sm text-gray-500">Loading student learning goals...</p>
        </div>
      ) : goals.length === 0 ? (
        <div className="card text-center py-12">
          <Target className="w-12 h-12 mx-auto text-teal-600 mb-3 opacity-60" />
          <h3 className="text-base font-semibold">No active learning goals</h3>
          <p className="text-sm text-gray-500 mt-1 max-w-sm mx-auto">
            Set study objectives and target milestones for enrolled students to track their educational progress.
          </p>
        </div>
      ) : (
        <div className="card p-0 overflow-hidden">
          <div className="overflow-x-auto">
            <table>
              <thead>
                <tr>
                  <th>Goal Objective</th>
                  <th>Student</th>
                  <th>Classroom</th>
                  <th>Target Date</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {goals.map((g) => {
                  const isAchieved = g.status === 'achieved';
                  return (
                    <tr key={g.id}>
                      <td>
                        <span className={`font-semibold ${isAchieved ? 'line-through text-gray-400' : 'text-gray-900 dark:text-gray-100'}`}>
                          {g.title}
                        </span>
                      </td>
                      <td>
                        <div className="font-medium text-gray-800 dark:text-gray-200">
                          {g.student_name}
                        </div>
                      </td>
                      <td>
                        <span className="badge badge-info">
                          {getClassroomName(g.classroom_id)}
                        </span>
                      </td>
                      <td className="text-xs text-gray-500">
                        {g.target_date ? (
                          <div className="flex items-center gap-1">
                            <Clock className="w-3.5 h-3.5" />
                            {new Date(g.target_date).toLocaleDateString()}
                          </div>
                        ) : (
                          'No deadline'
                        )}
                      </td>
                      <td>
                        <button
                          onClick={() => handleToggleStatus(g.id, g.status)}
                          className={`badge ${isAchieved ? 'badge-success' : 'badge-warning'} cursor-pointer hover:opacity-80`}
                        >
                          {isAchieved ? (
                            <>
                              <CheckCircle className="w-3 h-3 mr-1" /> Achieved
                            </>
                          ) : (
                            'In Progress'
                          )}
                        </button>
                      </td>
                      <td>
                        <button
                          onClick={() => handleDelete(g.id)}
                          className="btn btn-secondary py-1 px-2 text-rose-600 hover:bg-rose-50"
                          title="Delete goal"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
