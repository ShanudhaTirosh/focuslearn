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
    const body = await req.json();
    const { deviceId } = body;

    if (!deviceId) {
      return new Response(JSON.stringify({ error: 'Missing deviceId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // 1. Verify device belongs to this user or user is parent of device owner
    const { data: dev, error: devErr } = await adminClient
      .from('devices')
      .select('id, user_id, revoked_at')
      .eq('id', deviceId)
      .maybeSingle();

    if (devErr || !dev) {
      return new Response(JSON.stringify({ error: 'Device not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (dev.revoked_at) {
      return new Response(JSON.stringify({ error: 'Device has been revoked' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Fetch latest device config
    const { data: config } = await adminClient
      .from('device_configs')
      .select('*')
      .eq('device_id', deviceId)
      .maybeSingle();

    // 3. Fetch and acknowledge pending remote commands
    const { data: commands } = await adminClient
      .from('remote_commands')
      .select('*')
      .eq('device_id', deviceId)
      .eq('status', 'pending')
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: true });

    if (commands && commands.length > 0) {
      const commandIds = commands.map((c) => c.id);
      await adminClient
        .from('remote_commands')
        .update({ status: 'acknowledged', acknowledged_at: new Date().toISOString() })
        .in('id', commandIds);
    }

    // 4. Update last_seen_at for device
    await adminClient
      .from('devices')
      .update({ last_seen_at: new Date().toISOString() })
      .eq('id', deviceId);

    // 5. Fetch recent unread notifications
    const { data: notifications } = await adminClient
      .from('notifications')
      .select('*')
      .eq('user_id', dev.user_id)
      .is('read_at', null)
      .order('created_at', { ascending: false })
      .limit(20);

    return new Response(
      JSON.stringify({
        success: true,
        config: config ?? null,
        commands: commands ?? [],
        notifications: notifications ?? [],
        syncedAt: new Date().toISOString(),
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
