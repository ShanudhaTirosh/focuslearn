import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { authenticateUser, getServiceRoleClient } from '../_shared/supabase.ts';

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const { user } = await authenticateUser(req);

    // Verify caller is an administrator
    const adminEmails = (Deno.env.get('ADMIN_EMAILS') ?? 'admin@shanutechx.com').split(',');
    const isUserAdmin = adminEmails.some(e => e.trim().toLowerCase() === user.email?.toLowerCase());

    if (!isUserAdmin) {
      return new Response(JSON.stringify({ error: 'Forbidden: Admin access required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();
    const url = new URL(req.url);
    const action = url.searchParams.get('action') ?? 'list_reports';

    if (req.method === 'GET') {
      if (action === 'list_reports') {
        const { data: reports, error } = await adminClient
          .from('reports')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(50);

        if (error) throw error;
        return new Response(JSON.stringify({ reports }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      if (action === 'audit_logs') {
        const { data: logs, error } = await adminClient
          .from('audit_logs')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(100);

        if (error) throw error;
        return new Response(JSON.stringify({ logs }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    if (req.method === 'POST' && action === 'action_report') {
      const { reportId, status, notes } = await req.json();

      const { data: updated, error } = await adminClient
        .from('reports')
        .update({
          status: status,
          action_notes: notes,
          updated_at: new Date().toISOString(),
        })
        .eq('id', reportId)
        .select('*')
        .single();

      if (error) throw error;

      // Log action in audit logs
      await adminClient.from('audit_logs').insert({
        actor_id: user.id,
        actor_role: 'admin',
        action: 'report_status_update',
        entity_type: 'report',
        entity_id: reportId,
        after_state: { status, notes },
      });

      return new Response(JSON.stringify({ success: true, report: updated }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ error: 'Unsupported action' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

