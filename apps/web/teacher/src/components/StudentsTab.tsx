import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import type { Classroom, ClassroomStudent } from '../lib/types';
import { Users, Clock, Award, Trash2, RefreshCw } from 'lucide-react';

interface StudentsTabProps {
  classrooms: Classroom[];
}

export const StudentsTab: React.FC<StudentsTabProps> = ({ classrooms }) => {
  const [selectedClassroomId, setSelectedClassroomId] = useState<string>('all');
  const [students, setStudents] = useState<ClassroomStudent[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchStudents = async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('classroom_students')
        .select('*')
        .eq('status', 'active')
        .order('joined_at', { ascending: false });

      if (selectedClassroomId !== 'all') {
        query = query.eq('classroom_id', selectedClassroomId);
      }

      const { data: enrolled, error: enrollError } = await query;
      if (enrollError) throw enrollError;

      const rawList: ClassroomStudent[] = enrolled || [];
      if (rawList.length === 0) {
        setStudents([]);
        return;
      }

      // Fetch profile names and study hours for enrolled students
      const studentIds = rawList.map((s) => s.child_id);

      const [profilesRes, sessionsRes] = await Promise.all([
        supabase.from('profiles').select('user_id, full_name').in('user_id', studentIds),
        supabase.from('study_sessions').select('user_id, duration_minutes').in('user_id', studentIds),
      ]);

      const profileMap = new Map<string, string>();
      (profilesRes.data || []).forEach((p: any) => {
        profileMap.set(p.user_id, p.full_name || 'Anonymous Student');
      });

      const statsMap = new Map<string, { minutes: number; count: number }>();
      (sessionsRes.data || []).forEach((s: any) => {
        const current = statsMap.get(s.user_id) || { minutes: 0, count: 0 };
        current.minutes += s.duration_minutes || 0;
        current.count += 1;
        statsMap.set(s.user_id, current);
      });

      const augmented = rawList.map((s) => {
        const stats = statsMap.get(s.child_id) || { minutes: 0, count: 0 };
        return {
          ...s,
          student_name: profileMap.get(s.child_id) || 'Student ID: ' + s.child_id.slice(0, 8),
          total_study_minutes: stats.minutes,
          total_sessions: stats.count,
        };
      });

      setStudents(augmented);
    } catch (err) {
      console.error('Error fetching classroom students:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStudents();
  }, [selectedClassroomId, classrooms]);

  const handleRemoveStudent = async (studentId: string, classroomId: string) => {
    if (!confirm('Remove this student from the classroom?')) return;
    try {
      const { error } = await supabase
        .from('classroom_students')
        .update({ status: 'removed' })
        .eq('child_id', studentId)
        .eq('classroom_id', classroomId);

      if (error) throw error;
      fetchStudents();
    } catch (err: any) {
      alert(`Error removing student: ${err.message}`);
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
            <Users className="w-5 h-5 text-teal-600" />
            Enrolled Students & Progress
          </h2>
          <p className="text-sm text-gray-500">
            Monitor educational participation, total study sessions completed, and focus hours.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <select
            value={selectedClassroomId}
            onChange={(e) => setSelectedClassroomId(e.target.value)}
            className="input-field text-sm py-1.5"
          >
            <option value="all">All Classrooms</option>
            {classrooms.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>

          <button
            onClick={fetchStudents}
            disabled={loading}
            className="btn btn-secondary py-1.5 px-3 text-sm flex items-center gap-1.5"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>
      </div>

      {loading ? (
        <div className="card text-center py-12">
          <RefreshCw className="w-8 h-8 animate-spin mx-auto text-teal-600 mb-2" />
          <p className="text-sm text-gray-500">Loading student rosters and study progress...</p>
        </div>
      ) : students.length === 0 ? (
        <div className="card text-center py-12">
          <Users className="w-12 h-12 mx-auto text-teal-600 mb-3 opacity-60" />
          <h3 className="text-base font-semibold">No students currently enrolled</h3>
          <p className="text-sm text-gray-500 mt-1 max-w-sm mx-auto">
            Share your classroom's 6-character code with students. Once enrolled, their study hours and assignments will appear here.
          </p>
        </div>
      ) : (
        <div className="card p-0 overflow-hidden">
          <div className="overflow-x-auto">
            <table>
              <thead>
                <tr>
                  <th>Student</th>
                  <th>Classroom</th>
                  <th>Study Time</th>
                  <th>Focus Sessions</th>
                  <th>Joined Date</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {students.map((s) => (
                  <tr key={s.id}>
                    <td>
                      <div className="font-semibold text-gray-900 dark:text-gray-100">
                        {s.student_name}
                      </div>
                      <div className="text-xs text-gray-400 font-mono">
                        ID: {s.child_id.slice(0, 10)}...
                      </div>
                    </td>
                    <td>
                      <span className="badge badge-info">
                        {getClassroomName(s.classroom_id)}
                      </span>
                    </td>
                    <td>
                      <div className="flex items-center gap-1.5 font-semibold text-teal-600 dark:text-teal-400">
                        <Clock className="w-4 h-4" />
                        {Math.floor((s.total_study_minutes || 0) / 60)}h {(s.total_study_minutes || 0) % 60}m
                      </div>
                    </td>
                    <td>
                      <div className="flex items-center gap-1.5 text-gray-700 dark:text-gray-300">
                        <Award className="w-4 h-4 text-amber-500" />
                        {s.total_sessions || 0} completed
                      </div>
                    </td>
                    <td className="text-xs text-gray-500">
                      {new Date(s.joined_at).toLocaleDateString()}
                    </td>
                    <td>
                      <button
                        onClick={() => handleRemoveStudent(s.child_id, s.classroom_id)}
                        className="btn btn-secondary py-1 px-2.5 text-xs text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-900/20"
                        title="Remove student from class"
                      >
                        <Trash2 className="w-3.5 h-3.5 mr-1" /> Remove
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
