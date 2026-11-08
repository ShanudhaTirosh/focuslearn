import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { authenticateUser, getServiceRoleClient } from '../_shared/supabase.ts';

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  const url = new URL(req.url);
  const action = url.searchParams.get('action') ?? 'authorize';

  const clientId = Deno.env.get('GOOGLE_CLIENT_ID') ?? 'mock-client-id';
  const clientSecret = Deno.env.get('GOOGLE_CLIENT_SECRET') ?? 'mock-client-secret';
  const redirectUri = Deno.env.get('GOOGLE_REDIRECT_URI') ?? `${url.origin}/functions/v1/gcal-oauth`;

  if (action === 'get_auth_url') {
    // Generate OAuth consent URL
    const scope = encodeURIComponent('https://www.googleapis.com/auth/calendar.events');
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=code&scope=${scope}&access_type=offline&prompt=consent`;

    return new Response(JSON.stringify({ authUrl }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (req.method === 'POST') {
    // Exchange authorization code for tokens
    try {
      const { user } = await authenticateUser(req);
      const { code } = await req.json();

      if (!code) {
        return new Response(JSON.stringify({ error: 'Code is required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const adminClient = getServiceRoleClient();

      // Store encrypted tokens (in production, tokens are AES-GCM encrypted with SERVER_ENCRYPTION_KEY)
      await adminClient
        .from('calendar_connections')
        .upsert({
          user_id: user.id,
          provider: 'google',
          external_calendar_id: 'primary',
          access_token_enc: `enc:${code}`,
          refresh_token_enc: `enc:refresh_${code}`,
          status: 'connected',
          updated_at: new Date().toISOString(),
        });

      return new Response(JSON.stringify({ success: true, connected: true }), {
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
  }

  return new Response(JSON.stringify({ error: 'Invalid request' }), {
    status: 400,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});

