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
    const { fileId } = await req.json();

    if (!fileId) {
      return new Response(JSON.stringify({ error: 'fileId is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const adminClient = getServiceRoleClient();

    // Check file exists and is ready
    const { data: fileObj, error: fileErr } = await adminClient
      .from('file_objects')
      .select('id, r2_key, owner_id, status, deleted_at')
      .eq('id', fileId)
      .is('deleted_at', null)
      .single();

    if (fileErr || !fileObj || fileObj.status !== 'ready') {
      return new Response(JSON.stringify({ error: 'File not available' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Access authorization:
    // 1. Owner always has access
    // 2. Otherwise check if file is linked to a shared note or conversation member
    let authorized = fileObj.owner_id === user.id;

    if (!authorized) {
      // Check if file is linked to a note shared with the requesting user
      const { data: noteWithAttachment } = await adminClient
        .from('notes')
        .select('id')
        .filter('attachments', 'cs', JSON.stringify([fileId]))
        .limit(1);

      if (noteWithAttachment && noteWithAttachment.length > 0) {
        const noteId = noteWithAttachment[0].id;
        const { count: shareCount } = await adminClient
          .from('note_shares')
          .select('id', { count: 'exact', head: true })
          .eq('note_id', noteId)
          .eq('grantee_user_id', user.id);

        if (shareCount && shareCount > 0) {
          authorized = true;
        }
      }
    }

    if (!authorized) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const expiresInSeconds = 120; // 2 minutes TTL
    const downloadUrl = await createR2PresignedUrl({
      method: 'GET',
      key: fileObj.r2_key,
      expiresInSeconds,
    });

    return new Response(
      JSON.stringify({
        downloadUrl,
        expiresInSeconds,
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

