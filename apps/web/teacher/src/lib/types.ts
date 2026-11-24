export interface Classroom {
  id: string;
  teacher_id: string;
  name: string;
  subject: string | null;
  school_name: string | null;
  invite_code: string | null;
  invite_expires_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ClassroomStudent {
  id: string;
  classroom_id: string;
  child_id: string;
  enrolled_by_parent_id: string | null;
  status: 'active' | 'removed';
  joined_at: string;
  // Augmented details
  student_name?: string;
  total_study_minutes?: number;
  total_sessions?: number;
}

export interface HomeworkAssignment {
  id: string;
  classroom_id: string;
  teacher_id: string;
  title: string;
  description: string | null;
  due_date: string | null;
  created_at: string;
  updated_at: string;
}

export interface LearningGoal {
  id: string;
  classroom_id: string;
  child_id: string;
  teacher_id: string;
  title: string;
  target_date: string | null;
  status: 'active' | 'achieved' | 'cancelled';
  created_at: string;
  student_name?: string;
}
