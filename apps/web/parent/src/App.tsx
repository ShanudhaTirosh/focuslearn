import React, { useState, useEffect } from 'react';
import { supabase } from './lib/supabase';
import type { ChildProfile, SupervisedDevice, RemoteCommand } from './lib/types';
import { OverviewTab } from './components/OverviewTab';
import { ChildrenTab } from './components/ChildrenTab';
import { DevicesTab } from './components/DevicesTab';
import { ScreenTimeTab } from './components/ScreenTimeTab';
import { AppRestrictionsTab } from './components/AppRestrictionsTab';
import { ViolationsTab } from './components/ViolationsTab';
import { CommandHistoryTab } from './components/CommandHistoryTab';
import {
  Shield,
  LayoutDashboard,
  Users,
  Smartphone,
  Clock,
  ShieldBan,
  AlertTriangle,
  History,
  LogOut,
  Moon,
  Sun,
  Radio,
  Lock,
} from 'lucide-react';

type TabType = 'overview' | 'children' | 'devices' | 'screentime' | 'restrictions' | 'violations' | 'commands';

export function App() {
  const [session, setSession] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<TabType>('overview');
  const [isDark, setIsDark] = useState(false);

  // Core state
  const [childrenList, setChildrenList] = useState<ChildProfile[]>([]);
  const [devicesList, setDevicesList] = useState<SupervisedDevice[]>([]);
  const [commandsList, setCommandsList] = useState<RemoteCommand[]>([]);

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

  // Fetch children and supervised devices
  const loadParentData = async () => {
    if (!session?.user?.id) return;

    try {
      // 1. Fetch children linked to this parent
      const { data: links, error: linksError } = await supabase
        .from('parent_child_links')
        .select('*')
        .eq('parent_id', session.user.id);

      if (linksError) throw linksError;
      const linksData: ChildProfile[] = links || [];
      setChildrenList(linksData);

      // 2. Fetch supervised devices for linked children
      if (linksData.length > 0) {
        const childIds = linksData.map((c) => c.child_id);
        const { data: devices, error: devError } = await supabase
          .from('devices')
          .select('*')
          .in('user_id', childIds);

        if (devError) throw devError;
        setDevicesList(devices || []);
      } else {
        setDevicesList([]);
      }

      // 3. Fetch recent remote commands
      const { data: commands, error: cmdError } = await supabase
        .from('remote_commands')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(50);

      if (cmdError) throw cmdError;
      setCommandsList(commands || []);
    } catch (err) {
      console.error('Error loading parent dashboard data:', err);
    }
  };

  useEffect(() => {
    if (session) {
      loadParentData();

      // Realtime subscription to remote commands & heartbeats
      const cmdSub = supabase
        .channel('parent-commands')
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'remote_commands' },
          () => {
            loadParentData();
          }
        )
        .subscribe();

      const devSub = supabase
        .channel('parent-devices')
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'devices' },
          () => {
            loadParentData();
          }
        )
        .subscribe();

      return () => {
        supabase.removeChannel(cmdSub);
        supabase.removeChannel(devSub);
      };
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
          <Shield className="w-12 h-12 animate-pulse text-primary-600 mx-auto mb-3" />
          <p className="text-gray-500 text-sm font-medium">Connecting to FocusLearn Parental Service...</p>
        </div>
      </div>
    );
  }

  // Not signed in -> show Auth Form
  if (!session) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900 px-4">
        <div className="card max-w-md w-full p-8 shadow-xl">
          <div className="flex items-center justify-center gap-2 mb-6 text-primary-600 dark:text-primary-400">
            <Shield className="w-10 h-10" />
            <h1 className="text-2xl font-black tracking-tight text-gray-900 dark:text-white">
              FocusLearn <span className="text-primary-600">Family</span>
            </h1>
          </div>
          <p className="text-center text-sm text-gray-500 dark:text-gray-400 mb-6">
            Parental Controls, Screen Time Schedules & Remote Android Companion Hub
          </p>

          {authError && (
            <div className="mb-4 p-3 bg-rose-50 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 text-sm rounded-lg">
              {authError}
            </div>
          )}

          <form onSubmit={handleAuth} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold uppercase text-gray-500 mb-1">
                Parent Email
              </label>
              <input
                type="email"
                required
                value={authEmail}
                onChange={(e) => setAuthEmail(e.target.value)}
                placeholder="parent@example.com"
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
              className="btn-primary w-full py-2.5 flex items-center justify-center gap-2"
            >
              <Lock className="w-4 h-4" />
              {authSubmitting
                ? 'Processing...'
                : authMode === 'signin'
                ? 'Sign In to Parent Portal'
                : 'Create Parent Account'}
            </button>
          </form>

          <div className="mt-6 text-center text-sm text-gray-500">
            {authMode === 'signin' ? (
              <button
                type="button"
                onClick={() => setAuthMode('signup')}
                className="text-primary-600 hover:underline"
              >
                Need an account? Sign up as a parent
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setAuthMode('signin')}
                className="text-primary-600 hover:underline"
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
    { id: 'overview', label: 'Overview', icon: LayoutDashboard },
    { id: 'children', label: 'Children & Pairing', icon: Users },
    { id: 'devices', label: 'Supervised Devices', icon: Smartphone },
    { id: 'screentime', label: 'Screen Time & Schedules', icon: Clock },
    { id: 'restrictions', label: 'App Restrictions & Safety', icon: ShieldBan },
    { id: 'violations', label: 'Distraction & Alerts', icon: AlertTriangle },
    { id: 'commands', label: 'Remote Command Log', icon: History },
  ];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 flex flex-col">
      {/* Top Header */}
      <header className="bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 sticky top-0 z-30">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="bg-primary-500/10 dark:bg-primary-400/20 p-2 rounded-xl text-primary-600 dark:text-primary-400">
              <Shield className="w-6 h-6" />
            </div>
            <div>
              <span className="font-black text-lg text-gray-900 dark:text-white">
                FocusLearn <span className="text-primary-600">Parent Hub</span>
              </span>
              <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-emerald-100 text-emerald-800 dark:bg-emerald-900/50 dark:text-emerald-300">
                <Radio className="w-3 h-3 mr-1 animate-pulse" /> Live Remote Sync
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
              className="btn-secondary py-1.5 px-3 text-xs flex items-center gap-1.5"
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
                    ? 'bg-primary-50 dark:bg-primary-900/40 text-primary-700 dark:text-primary-300 font-semibold shadow-sm'
                    : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'
                }`}
              >
                <Icon className={`w-4 h-4 ${isActive ? 'text-primary-600 dark:text-primary-400' : 'text-gray-400'}`} />
                {item.label}
              </button>
            );
          })}
        </nav>

        {/* Content Area */}
        <main className="flex-1 min-w-0">
          {activeTab === 'overview' && (
            <OverviewTab
              childrenList={childrenList}
              devicesList={devicesList}
              onNavigate={(tab) => setActiveTab(tab as TabType)}
            />
          )}
          {activeTab === 'children' && (
            <ChildrenTab
              childrenList={childrenList}
              onRefresh={loadParentData}
            />
          )}
          {activeTab === 'devices' && (
            <DevicesTab
              devicesList={devicesList}
              childrenList={childrenList}
              onRefresh={loadParentData}
            />
          )}
          {activeTab === 'screentime' && (
            <ScreenTimeTab
              childrenList={childrenList}
            />
          )}
          {activeTab === 'restrictions' && (
            <AppRestrictionsTab
              childrenList={childrenList}
            />
          )}
          {activeTab === 'violations' && (
            <ViolationsTab
              childrenList={childrenList}
            />
          )}
          {activeTab === 'commands' && (
            <CommandHistoryTab
              commands={commandsList}
              onRefresh={loadParentData}
            />
          )}
        </main>
      </div>
    </div>
  );
}
