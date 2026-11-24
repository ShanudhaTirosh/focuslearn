import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import type { Classroom, HomeworkAssignment } from '../lib/types';
import { BookOpen, Plus, Calendar, Trash2, RefreshCw } from 'lucide-react';

interface HomeworkTabProps {
  classrooms: Classroom[];
}

export const HomeworkTab: React.FC<HomeworkTabProps> = ({ classrooms }) => {
  const [assignments, setAssignments] = useState<HomeworkAssignment[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);

  const [selectedClassroomId, setSelectedClassroomId] = useState<string>('');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (classrooms.length > 0 && !selectedClassroomId) {
      setSelectedClassroomId(classrooms[0].id);
    }
  }, [classrooms]);

  const fetchAssignments = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('homework')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAssignments(data || []);
    } catch (err) {
      console.error('Error fetching homework assignments:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAssignments();
  }, []);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !selectedClassroomId) return;

    setSubmitting(true);
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      const { error } = await supabase.from('homework').insert({
        classroom_id: selectedClassroomId,
        teacher_id: user.id,
        title: title.trim(),
        description: description.trim() || null,
        due_date: dueDate || null,
      });

      if (error) throw error;
      setTitle('');
      setDescription('');
      setDueDate('');
      setShowCreate(false);
      fetchAssignments();
    } catch (err: any) {
      alert(`Error creating homework assignment: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (assignmentId: string) => {
    if (!confirm('Delete this homework assignment?')) return;
    try {
      const { error } = await supabase.from('homework').delete().eq('id', assignmentId);
      if (error) throw error;
      fetchAssignments();
    } catch (err: any) {
      alert(`Error deleting assignment: ${err.message}`);
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
            <BookOpen className="w-5 h-5 text-teal-600" />
            Homework & Assignments
          </h2>
          <p className="text-sm text-gray-500">
            Publish homework assignments, deadlines, and study materials for your classrooms.
          </p>
        </div>

        <button
          onClick={() => setShowCreate(!showCreate)}
          className="btn btn-primary"
        >
          <Plus className="w-4 h-4 mr-1.5" />
          {showCreate ? 'Cancel' : 'Post Assignment'}
        </button>
      </div>

      {showCreate && (
        <form onSubmit={handleCreate} className="card space-y-4 border-teal-500/30">
          <h3 className="text-base font-semibold">Post New Assignment</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
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
                    {c.name} ({c.subject || 'General'})
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Due Date
              </label>
              <input
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
                className="input-field"
              />
            </div>
          </div>
          <div>
            <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
              Assignment Title *
            </label>
            <input
              type="text"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Chapter 4 Exercises: Mechanics & Circular Motion"
              className="input-field"
            />
          </div>
          <div>
            <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
              Description & Instructions
            </label>
            <textarea
              rows={3}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Provide assignment guidelines, required textbook questions, or submission details..."
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
              disabled={submitting}
              className="btn btn-primary"
            >
              {submitting ? 'Publishing...' : 'Publish to Students'}
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <div className="card text-center py-12">
          <RefreshCw className="w-8 h-8 animate-spin mx-auto text-teal-600 mb-2" />
          <p className="text-sm text-gray-500">Loading assignments...</p>
        </div>
      ) : assignments.length === 0 ? (
        <div className="card text-center py-12">
          <BookOpen className="w-12 h-12 mx-auto text-teal-600 mb-3 opacity-60" />
          <h3 className="text-base font-semibold">No homework assigned yet</h3>
          <p className="text-sm text-gray-500 mt-1 max-w-sm mx-auto">
            Click 'Post Assignment' above to publish tasks and homework for your enrolled classroom students.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {assignments.map((a) => (
            <div key={a.id} className="card flex flex-col justify-between">
              <div>
                <div className="flex items-start justify-between gap-3">
                  <h3 className="font-semibold text-gray-900 dark:text-gray-100">
                    {a.title}
                  </h3>
                  <span className="badge badge-info shrink-0">
                    {getClassroomName(a.classroom_id)}
                  </span>
                </div>
                {a.description && (
                  <p className="text-sm text-gray-600 dark:text-gray-400 mt-2 line-clamp-3">
                    {a.description}
                  </p>
                )}
              </div>

              <div className="mt-4 pt-3 border-t border-gray-100 dark:border-gray-800 flex items-center justify-between text-xs text-gray-500">
                <div className="flex items-center gap-1.5">
                  <Calendar className="w-3.5 h-3.5 text-teal-600" />
                  <span>
                    {a.due_date ? `Due ${new Date(a.due_date).toLocaleDateString()}` : 'No due date'}
                  </span>
                </div>
                <button
                  onClick={() => handleDelete(a.id)}
                  className="btn btn-secondary py-1 px-2 text-rose-600 hover:bg-rose-50"
                  title="Delete assignment"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
