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
    const { deviceId, batteryLevel, isCharging, networkType, osVersion, appVersion } = body;

    if (!deviceId) {
      return new Response(JSON.stringify({ error: 'Missing deviceId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // Verify device belongs to user
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
      return new Response(JSON.stringify({ error: 'Device is revoked' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Insert heartbeat record
    const { data: heartbeat, error: hbErr } = await adminClient
      .from('device_heartbeats')
      .insert({
        device_id: deviceId,
        battery_level: typeof batteryLevel === 'number' ? Math.round(batteryLevel) : null,
        is_charging: typeof isCharging === 'boolean' ? isCharging : null,
        network_type: networkType ?? 'unknown',
        os_version: osVersion ?? null,
        app_version: appVersion ?? null,
        is_connected: true,
      })
      .select('id, reported_at')
      .single();

    if (hbErr) throw hbErr;

    // Refresh device last_seen_at & app_version
    await adminClient
      .from('devices')
      .update({
        last_seen_at: new Date().toISOString(),
        ...(appVersion ? { app_version: appVersion } : {}),
      })
      .eq('id', deviceId);

    return new Response(
      JSON.stringify({
        success: true,
        heartbeatId: heartbeat.id,
        reportedAt: heartbeat.reported_at,
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
