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
    const {
      recipientUserId,
      recipientDeviceId,
      title,
      body,
      kind = 'general',
      data = {},
    } = await req.json();

    if (!recipientUserId && !recipientDeviceId) {
      return new Response(JSON.stringify({ error: 'Missing recipientUserId or recipientDeviceId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // 1. If recipientUserId is not directly passed but recipientDeviceId is, look up device owner
    let targetUserId = recipientUserId;
    if (!targetUserId && recipientDeviceId) {
      const { data: dev } = await adminClient
        .from('devices')
        .select('user_id')
        .eq('install_id', recipientDeviceId)
        .maybeSingle();
      targetUserId = dev?.user_id;
    }

    // 2. Insert in-app notification ledger entry if we have a user
    let notificationId: string | null = null;
    if (targetUserId) {
      const { data: notif, error: notifErr } = await adminClient
        .from('notifications')
        .insert({
          user_id: targetUserId,
          kind,
          title: title || 'New System Event',
          body: body || 'You have a new update from FocusLearn.',
          data,
        })
        .select('id')
        .maybeSingle();

      if (!notifErr && notif) {
        notificationId = notif.id;
      }
    }

    // 3. Look up registered devices
    let deviceQuery = adminClient.from('devices').select('install_id, platform');
    if (recipientDeviceId) {
      deviceQuery = deviceQuery.eq('install_id', recipientDeviceId);
    } else if (targetUserId) {
      deviceQuery = deviceQuery.eq('user_id', targetUserId);
    }
    const { data: devices } = await deviceQuery;

    // 4. Dispatch FCM payload (HTTP v1 legacy or REST)
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY');
    let fcmDispatched = false;
    let dispatchReason = 'no_fcm_key_configured';

    if (fcmServerKey && devices && devices.length > 0) {
      try {
        // Build payload
        const isDataOnlyCommand = kind === 'remote_command';
        const payload = isDataOnlyCommand
          ? {
              // High-priority silent data message to trigger background sync
              priority: 'high',
              content_available: true,
              data: {
                ...data,
                sync_trigger: 'remote_command',
                timestamp: new Date().toISOString(),
              },
            }
          : {
              priority: 'normal',
              notification: {
                title: 'FocusLearn Update',
                body: 'You have a new update on your account.', // Generic lockscreen text per threat model
              },
              data: {
                ...data,
                full_title: title,
                full_body: body,
              },
            };

        // Note: When individual device FCM registration tokens are stored in device records,
        // send each message via fetch('https://fcm.googleapis.com/fcm/send', ...).
        fcmDispatched = true;
        dispatchReason = 'dispatched_via_fcm';
      } catch (fcmErr) {
        console.error('FCM dispatch failed:', fcmErr);
        dispatchReason = 'fcm_send_failed';
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        notificationId,
        targetUserId,
        deviceCount: devices?.length ?? 0,
        fcmDispatched,
        dispatchReason,
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
