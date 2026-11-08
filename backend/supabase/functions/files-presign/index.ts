import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { authenticateUser, getServiceRoleClient } from '../_shared/supabase.ts';
import { createR2PresignedUrl } from '../_shared/r2.ts';

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
    const { filename, size, mimeType } = body;

    if (!filename || typeof size !== 'number' || size <= 0) {
      return new Response(JSON.stringify({ error: 'Invalid file payload' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB
    if (size > MAX_FILE_SIZE) {
      return new Response(JSON.stringify({ error: 'File exceeds 50MB limit' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // Check user quota
    const { data: quota } = await adminClient
      .from('user_quotas')
      .select('bytes_used, bytes_limit')
      .eq('user_id', user.id)
      .maybeSingle();

    const bytesUsed = quota?.bytes_used ?? 0;
    const bytesLimit = quota?.bytes_limit ?? (100 * 1024 * 1024);

    if (bytesUsed + size > bytesLimit) {
      return new Response(JSON.stringify({ error: 'Storage quota exceeded' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
    const objectUuid = crypto.randomUUID();
    const r2Key = `objects/${user.id}/${objectUuid}/${safeName}`;

    // Register file object
    const { data: fileObj, error: insertError } = await adminClient
      .from('file_objects')
      .insert({
        id: objectUuid,
        r2_key: r2Key,
        owner_id: user.id,
        size: size,
        sniffed_mime: mimeType || 'application/octet-stream',
        status: 'pending',
      })
      .select('id, r2_key')
      .single();

    if (insertError) {
      throw insertError;
    }

    const presignedUrl = await createR2PresignedUrl({
      method: 'PUT',
      key: r2Key,
      expiresInSeconds: 300,
      contentType: mimeType,
    });

    return new Response(
      JSON.stringify({
        fileId: fileObj.id,
        key: fileObj.r2_key,
        presignedUrl,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

