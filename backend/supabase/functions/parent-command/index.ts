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
    const { deviceId, commandType, payload } = body;

    if (!deviceId || !commandType) {
      return new Response(JSON.stringify({ error: 'Missing deviceId or commandType' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // Verify calling user is parent of the child owning this device, or is admin
    // Match device by either uuid primary key or install_id
    const { data: dev } = await adminClient
      .from('devices')
      .select('id, install_id, user_id')
      .or(`id.eq.${deviceId},install_id.eq.${deviceId}`)
      .maybeSingle();

    if (!dev) {
      return new Response(JSON.stringify({ error: 'Target device not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: link } = await adminClient
      .from('parent_child_links')
      .select('id, status')
      .eq('parent_id', user.id)
      .eq('child_id', dev.user_id)
      .eq('status', 'active')
      .maybeSingle();

    const { data: adminRole } = await adminClient
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('role', 'admin')
      .maybeSingle();

    if (!link && !adminRole && dev.user_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Unauthorized to issue commands to this device' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Insert remote command into queue (target install_id)
    const idempotencyKey = `cmd-${dev.install_id}-${Date.now()}-${Math.random().toString(36).substring(2, 8)}`;
    const { data: command, error: cmdErr } = await adminClient
      .from('remote_commands')
      .insert({
        device_id: String(dev.install_id),
        parent_id: user.id,
        command_type: commandType,
        payload: payload ?? {},
        idempotency_key: idempotencyKey,
        status: 'pending',
      })
      .select('id, command_type, status, created_at')
      .single();

    if (cmdErr) throw cmdErr;

    // Trigger push-send edge function to dispatch high-priority wake-up data message
    try {
      await adminClient.functions.invoke('push-send', {
        body: {
          recipientUserId: dev.user_id,
          recipientDeviceId: String(dev.install_id),
          kind: 'remote_command',
          title: 'Remote Command',
          body: `New ${commandType} command queued`,
          data: {
            command_id: command.id,
            command_type: commandType,
          },
        },
      });
    } catch (_) {
      // Non-blocking fallback; device sync will pick it up on next polling/heartbeat interval
    }

    return new Response(
      JSON.stringify({
        success: true,
        commandId: command.id,
        status: command.status,
        createdAt: command.created_at,
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
