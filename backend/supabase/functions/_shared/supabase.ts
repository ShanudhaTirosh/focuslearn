import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

export function getServiceRoleClient() {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'http://localhost:8000';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  return createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });
}

export function getUserClient(authHeader: string | null) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'http://localhost:8000';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  return createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false },
    global: {
      headers: authHeader ? { Authorization: authHeader } : {},
    },
  });
}

export async function authenticateUser(req: Request) {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    throw new Error('Missing Authorization header');
  }
  const client = getUserClient(authHeader);
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) {
    throw new Error(`Unauthorized: ${error?.message ?? 'No user found'}`);
  }
  return { user, client };
}

