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
    const { fileId } = await req.json();

    if (!fileId) {
      return new Response(JSON.stringify({ error: 'fileId is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // Verify ownership and fetch file metadata
    const { data: fileObj, error: fetchErr } = await adminClient
      .from('file_objects')
      .select('*')
      .eq('id', fileId)
      .eq('owner_id', user.id)
      .single();

    if (fetchErr || !fileObj) {
      return new Response(JSON.stringify({ error: 'File not found or unauthorized' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Update status to ready
    const { error: updateErr } = await adminClient
      .from('file_objects')
      .update({
        status: 'ready',
        scan_state: 'clean',
        updated_at: new Date().toISOString(),
      })
      .eq('id', fileId);

    if (updateErr) throw updateErr;

    // Update user quota
    const { data: quota } = await adminClient
      .from('user_quotas')
      .select('bytes_used')
      .eq('user_id', user.id)
      .maybeSingle();

    const currentUsed = quota?.bytes_used ?? 0;
    await adminClient
      .from('user_quotas')
      .upsert({
        user_id: user.id,
        bytes_used: currentUsed + fileObj.size,
        updated_at: new Date().toISOString(),
      });

    return new Response(JSON.stringify({ success: true, status: 'ready' }), {
      status: 200,
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

