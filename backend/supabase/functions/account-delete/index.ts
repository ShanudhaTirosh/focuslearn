import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { getServiceRoleClient } from '../_shared/supabase.ts';

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Protect via service role authorization header or webhook secret
  const authHeader = req.headers.get('Authorization') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  if (!authHeader.includes(serviceKey) && !authHeader.includes('Bearer service_role')) {
    // Also allow cron invocation with shared secret
    const cronSecret = req.headers.get('x-cron-secret');
    if (cronSecret !== Deno.env.get('CRON_SECRET')) {
      return new Response(JSON.stringify({ error: 'Unauthorized invocation' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  }

  const adminClient = getServiceRoleClient();

  try {
    // Find eligible deletion requests
    const nowIso = new Date().toISOString();
    const { data: requests, error: fetchErr } = await adminClient
      .from('deletion_requests')
      .select('id, user_id, scheduled_for')
      .eq('status', 'pending')
      .lte('scheduled_for', nowIso)
      .limit(20);

    if (fetchErr) throw fetchErr;

    const results = [];

    for (const item of (requests ?? [])) {
      const userId = item.user_id;

      // 1. Mark processing
      await adminClient
        .from('deletion_requests')
        .update({ status: 'processing' })
        .eq('id', item.id);

      // 2. Soft-delete / clean up file objects
      await adminClient
        .from('file_objects')
        .update({ deleted_at: nowIso })
        .eq('owner_id', userId);

      // 3. Delete user from auth (cascades profiles, devices, preferences, sessions, notes, timetable)
      const { error: deleteUserErr } = await adminClient.auth.admin.deleteUser(userId);

      if (deleteUserErr) {
        console.error(`Failed to delete user ${userId}:`, deleteUserErr);
        results.push({ id: item.id, user_id: userId, success: false, error: deleteUserErr.message });
      } else {
        // 4. Mark done
        await adminClient
          .from('deletion_requests')
          .update({ status: 'done' })
          .eq('id', item.id);

        results.push({ id: item.id, user_id: userId, success: true });
      }
    }

    return new Response(JSON.stringify({ processedCount: results.length, details: results }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

