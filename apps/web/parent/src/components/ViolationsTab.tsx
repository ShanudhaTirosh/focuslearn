import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import type { PolicyViolation, ChildProfile } from '../lib/types';
import { ShieldAlert, AlertTriangle, Clock, RefreshCw, CheckCircle2 } from 'lucide-react';

interface ViolationsTabProps {
  childrenList: ChildProfile[];
}

export const ViolationsTab: React.FC<ViolationsTabProps> = ({ childrenList }) => {
  const [violations, setViolations] = useState<PolicyViolation[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedChildId, setSelectedChildId] = useState<string>('all');
  const [filterType, setFilterType] = useState<string>('all');

  const fetchViolations = async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('policy_violations')
        .select('*')
        .order('occurred_at', { ascending: false })
        .limit(100);

      if (selectedChildId !== 'all') {
        query = query.eq('student_id', selectedChildId);
      }
      if (filterType !== 'all') {
        query = query.eq('violation_type', filterType);
      }

      const { data, error } = await query;
      if (error) throw error;
      setViolations(data || []);
    } catch (err) {
      console.error('Error fetching policy violations:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchViolations();
  }, [selectedChildId, filterType]);

  const getChildName = (studentId: string) => {
    const child = childrenList.find((c) => c.child_id === studentId);
    return child ? child.child_nickname : 'Unknown Child';
  };

  const formatViolationType = (type: string) => {
    switch (type) {
      case 'distraction_opened':
        return { label: 'Blocked App Launched', color: 'badge-danger' };
      case 'daily_limit_reached':
        return { label: 'Daily Screen Time Exceeded', color: 'badge-warning' };
      case 'schedule_breach':
        return { label: 'Bedtime / Study Breach', color: 'badge-warning' };
      case 'session_aborted':
        return { label: 'Focus Session Force Closed', color: 'badge-info' };
      default:
        return { label: type.replace(/_/g, ' '), color: 'badge-neutral' };
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-gray-900 dark:text-gray-100 flex items-center gap-2">
            <ShieldAlert className="w-5 h-5 text-rose-500" />
            Distraction & Policy Alerts
          </h2>
          <p className="text-sm text-gray-500 dark:text-gray-400">
            Real-time security log of attempted launches of restricted apps and bedtime/schedule breaches.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <select
            value={selectedChildId}
            onChange={(e) => setSelectedChildId(e.target.value)}
            className="input-field text-sm py-1.5"
          >
            <option value="all">All Children</option>
            {childrenList.map((c) => (
              <option key={c.child_id} value={c.child_id}>
                {c.child_nickname}
              </option>
            ))}
          </select>

          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="input-field text-sm py-1.5"
          >
            <option value="all">All Violation Types</option>
            <option value="distraction_opened">Blocked App Launched</option>
            <option value="daily_limit_reached">Daily Limit Reached</option>
            <option value="schedule_breach">Schedule Breach</option>
            <option value="session_aborted">Session Aborted</option>
          </select>

          <button
            onClick={fetchViolations}
            disabled={loading}
            className="btn-secondary flex items-center gap-2 py-1.5 px-3 text-sm"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>
      </div>

      {loading ? (
        <div className="card text-center py-12">
          <RefreshCw className="w-8 h-8 animate-spin mx-auto text-primary-500 mb-2" />
          <p className="text-sm text-gray-500">Loading policy audit logs...</p>
        </div>
      ) : violations.length === 0 ? (
        <div className="card text-center py-12">
          <CheckCircle2 className="w-12 h-12 mx-auto text-emerald-500 mb-3" />
          <h3 className="text-base font-semibold text-gray-900 dark:text-gray-100">
            No policy breaches recorded
          </h3>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1 max-w-md mx-auto">
            Your supervised devices are adhering to daily screen-time schedules and app restriction rules.
          </p>
        </div>
      ) : (
        <div className="card p-0 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm text-gray-600 dark:text-gray-300">
              <thead className="bg-gray-50 dark:bg-gray-800 text-xs font-semibold text-gray-700 dark:text-gray-300 border-b border-gray-200 dark:border-gray-700">
                <tr>
                  <th className="py-3 px-4">Child & Device</th>
                  <th className="py-3 px-4">Event Type</th>
                  <th className="py-3 px-4">Target Application</th>
                  <th className="py-3 px-4">Timestamp</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                {violations.map((v) => {
                  const badge = formatViolationType(v.violation_type);
                  return (
                    <tr key={v.id} className="hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors">
                      <td className="py-3 px-4">
                        <div className="font-medium text-gray-900 dark:text-gray-100">
                          {getChildName(v.student_id)}
                        </div>
                        <div className="text-xs text-gray-400 font-mono">Device: {v.device_id.slice(0, 12)}...</div>
                      </td>
                      <td className="py-3 px-4">
                        <span className={`badge ${badge.color}`}>
                          {badge.label}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <span className="font-mono text-xs bg-gray-100 dark:bg-gray-800 px-2 py-1 rounded text-rose-600 dark:text-rose-400 font-semibold">
                          {v.package_name}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-xs text-gray-500">
                        <div className="flex items-center gap-1.5">
                          <Clock className="w-3.5 h-3.5" />
                          {new Date(v.occurred_at).toLocaleString()}
                        </div>
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
