import React, { useState, useEffect } from 'react';
import { supabase } from './lib/supabase';
import type { Classroom } from './lib/types';
import { ClassroomsTab } from './components/ClassroomsTab';
import { StudentsTab } from './components/StudentsTab';
import { HomeworkTab } from './components/HomeworkTab';
import { LearningGoalsTab } from './components/LearningGoalsTab';
import {
  GraduationCap,
  School,
  Users,
  BookOpen,
  Target,
  LogOut,
  Moon,
  Sun,
  Lock,
} from 'lucide-react';

type TabType = 'classrooms' | 'students' | 'homework' | 'goals';

export function App() {
  const [session, setSession] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<TabType>('classrooms');
  const [isDark, setIsDark] = useState(false);

  const [classrooms, setClassrooms] = useState<Classroom[]>([]);

  // Auth form state
  const [authMode, setAuthMode] = useState<'signin' | 'signup'>('signin');
  const [authEmail, setAuthEmail] = useState('');
  const [authPassword, setAuthPassword] = useState('');
  const [authError, setAuthError] = useState<string | null>(null);
  const [authSubmitting, setAuthSubmitting] = useState(false);

  // Initialize theme
  useEffect(() => {
    const savedTheme = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
      setIsDark(true);
      document.documentElement.classList.add('dark');
    }
  }, []);

  const toggleTheme = () => {
    setIsDark(!isDark);
    if (!isDark) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('theme', 'light');
    }
  };

  // Auth session tracking
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });

    return () => subscription.unsubscribe();
  }, []);

  // Fetch teacher classrooms
  const loadClassrooms = async () => {
    if (!session?.user?.id) return;
    try {
      const { data, error } = await supabase
        .from('classrooms')
        .select('*')
        .eq('teacher_id', session.user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setClassrooms(data || []);
    } catch (err) {
      console.error('Error fetching teacher classrooms:', err);
    }
  };

  useEffect(() => {
    if (session) {
      loadClassrooms();
    }
  }, [session]);

  const handleAuth = async (e: React.FormEvent) => {
    e.preventDefault();
    setAuthError(null);
    setAuthSubmitting(true);
    try {
      if (authMode === 'signin') {
        const { error } = await supabase.auth.signInWithPassword({
          email: authEmail,
          password: authPassword,
        });
        if (error) throw error;
      } else {
        const { error } = await supabase.auth.signUp({
          email: authEmail,
          password: authPassword,
        });
        if (error) throw error;
      }
    } catch (err: any) {
      setAuthError(err.message || 'Authentication failed');
    } finally {
      setAuthSubmitting(false);
    }
  };

  const handleSignOut = async () => {
    await supabase.auth.signOut();
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900">
        <div className="text-center">
          <GraduationCap className="w-12 h-12 animate-pulse text-teal-600 mx-auto mb-3" />
          <p className="text-gray-500 text-sm font-medium">Connecting to FocusLearn Educator Hub...</p>
        </div>
      </div>
    );
  }

  // Not signed in -> show Auth Form
  if (!session) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900 px-4">
        <div className="card max-w-md w-full p-8 shadow-xl">
          <div className="flex items-center justify-center gap-2 mb-6 text-teal-600 dark:text-teal-400">
            <GraduationCap className="w-10 h-10" />
            <h1 className="text-2xl font-black tracking-tight text-gray-900 dark:text-white">
              FocusLearn <span className="text-teal-600">Educator</span>
            </h1>
          </div>
          <p className="text-center text-sm text-gray-500 dark:text-gray-400 mb-6">
            Classroom Management, Student Progress & Homework Assignment Portal
          </p>

          {authError && (
            <div className="mb-4 p-3 bg-rose-50 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 text-sm rounded-lg">
              {authError}
            </div>
          )}

          <form onSubmit={handleAuth} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Teacher Email
              </label>
              <input
                type="email"
                required
                value={authEmail}
                onChange={(e) => setAuthEmail(e.target.value)}
                placeholder="teacher@school.edu"
                className="input-field"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Password
              </label>
              <input
                type="password"
                required
                value={authPassword}
                onChange={(e) => setAuthPassword(e.target.value)}
                placeholder="••••••••"
                className="input-field"
              />
            </div>
            <button
              type="submit"
              disabled={authSubmitting}
              className="btn btn-primary w-full py-2.5 flex items-center justify-center gap-2"
            >
              <Lock className="w-4 h-4" />
              {authSubmitting
                ? 'Processing...'
                : authMode === 'signin'
                ? 'Sign In to Educator Portal'
                : 'Create Teacher Account'}
            </button>
          </form>

          <div className="mt-6 text-center text-sm text-gray-500">
            {authMode === 'signin' ? (
              <button
                type="button"
                onClick={() => setAuthMode('signup')}
                className="text-teal-600 hover:underline"
              >
                Need an account? Sign up as a teacher
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setAuthMode('signin')}
                className="text-teal-600 hover:underline"
              >
                Already have an account? Sign in
              </button>
            )}
          </div>
        </div>
      </div>
    );
  }

  const navItems = [
    { id: 'classrooms', label: 'Classrooms & Codes', icon: School },
    { id: 'students', label: 'Students & Progress', icon: Users },
    { id: 'homework', label: 'Homework & Assignments', icon: BookOpen },
    { id: 'goals', label: 'Learning Goals', icon: Target },
  ];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 flex flex-col">
      {/* Top Header */}
      <header className="bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 sticky top-0 z-30">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="bg-teal-500/10 dark:bg-teal-400/20 p-2 rounded-xl text-teal-600 dark:text-teal-400">
              <GraduationCap className="w-6 h-6" />
            </div>
            <div>
              <span className="font-black text-lg text-gray-900 dark:text-white">
                FocusLearn <span className="text-teal-600">Educator Portal</span>
              </span>
            </div>
          </div>

          <div className="flex items-center gap-4">
            <span className="text-xs text-gray-500 hidden md:inline-block font-mono">
              {session.user.email}
            </span>
            <button
              onClick={toggleTheme}
              className="p-2 rounded-lg text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700"
              title="Toggle theme"
            >
              {isDark ? <Sun className="w-5 h-5 text-amber-400" /> : <Moon className="w-5 h-5" />}
            </button>
            <button
              onClick={handleSignOut}
              className="btn btn-secondary py-1.5 px-3 text-xs flex items-center gap-1.5"
            >
              <LogOut className="w-4 h-4" />
              Sign Out
            </button>
          </div>
        </div>
      </header>

      {/* Main layout */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 flex-1 w-full flex flex-col md:flex-row gap-6">
        {/* Sidebar Nav */}
        <nav className="w-full md:w-64 space-y-1 shrink-0">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id as TabType)}
                className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-teal-50 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300 font-semibold shadow-sm'
                    : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'
                }`}
              >
                <Icon className={`w-4 h-4 ${isActive ? 'text-teal-600 dark:text-teal-400' : 'text-gray-400'}`} />
                {item.label}
              </button>
            );
          })}
        </nav>

        {/* Content Area */}
        <main className="flex-1 min-w-0">
          {activeTab === 'classrooms' && (
            <ClassroomsTab
              classrooms={classrooms}
              onRefresh={loadClassrooms}
            />
          )}
          {activeTab === 'students' && (
            <StudentsTab
              classrooms={classrooms}
            />
          )}
          {activeTab === 'homework' && (
            <HomeworkTab
              classrooms={classrooms}
            />
          )}
          {activeTab === 'goals' && (
            <LearningGoalsTab
              classrooms={classrooms}
            />
          )}
        </main>
      </div>
    </div>
  );
}
