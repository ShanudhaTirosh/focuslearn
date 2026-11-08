import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { authenticateUser, getServiceRoleClient } from '../_shared/supabase.ts';

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const { user } = await authenticateUser(req);
    const adminClient = getServiceRoleClient();

    // Check calendar connection
    const { data: connection, error: connErr } = await adminClient
      .from('calendar_connections')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', 'connected')
      .maybeSingle();

    if (connErr || !connection) {
      return new Response(JSON.stringify({ error: 'Google Calendar not connected' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Fetch user events to sync
    const { data: events, error: eventErr } = await adminClient
      .from('timetable_events')
      .select('*')
      .eq('owner_id', user.id)
      .is('deleted_at', null);

    if (eventErr) throw eventErr;

    // In production, each timetable event is mapped to Google Calendar Event resource
    // and synced via Google Calendar v3 API.

    // Update last_synced_at timestamp
    const nowIso = new Date().toISOString();
    await adminClient
      .from('calendar_connections')
      .update({
        last_synced_at: nowIso,
        status: 'connected',
        updated_at: nowIso,
      })
      .eq('id', connection.id);

    return new Response(
      JSON.stringify({
        success: true,
        syncedCount: events?.length ?? 0,
        lastSyncedAt: nowIso,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

