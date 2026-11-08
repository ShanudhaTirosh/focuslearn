// Cloudflare R2 / S3 presigned URL generator using Web Crypto API.

async function hmacSha256(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  return await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(data));
}

async function sha256Hex(data: string): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return Array.from(new Uint8Array(hash))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export interface PresignedUrlOptions {
  method: 'GET' | 'PUT';
  key: string;
  expiresInSeconds?: number;
  contentType?: string;
}

export async function createR2PresignedUrl(options: PresignedUrlOptions): Promise<string> {
  const accountId = Deno.env.get('R2_ACCOUNT_ID') ?? 'mock-account';
  const accessKeyId = Deno.env.get('R2_ACCESS_KEY_ID') ?? 'mock-key';
  const secretAccessKey = Deno.env.get('R2_SECRET_ACCESS_KEY') ?? 'mock-secret';
  const bucket = Deno.env.get('R2_BUCKET_PRIVATE') ?? 'focuslearn-private';
  const endpoint = Deno.env.get('R2_ENDPOINT') ?? `https://${accountId}.r2.cloudflarestorage.com`;

  const expiresIn = options.expiresInSeconds ?? 300;
  const now = new Date();
  const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
  const dateStamp = amzDate.substring(0, 8);
  const region = 'auto';
  const service = 's3';

  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const host = new URL(endpoint).host;
  const path = `/${bucket}/${options.key}`;

  const queryParams: Record<string, string> = {
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': `${accessKeyId}/${credentialScope}`,
    'X-Amz-Date': amzDate,
    'X-Amz-Expires': expiresIn.toString(),
    'X-Amz-SignedHeaders': 'host',
  };

  const sortedQuery = Object.keys(queryParams)
    .sort()
    .map(k => `${encodeURIComponent(k)}=${encodeURIComponent(queryParams[k])}`)
    .join('&');

  const canonicalHeaders = `host:${host}\n`;
  const signedHeaders = 'host';
  const payloadHash = 'UNSIGNED-PAYLOAD';

  const canonicalRequest = [
    options.method,
    path,
    sortedQuery,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');

  const hashedCanonicalRequest = await sha256Hex(canonicalRequest);
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    hashedCanonicalRequest,
  ].join('\n');

  // Derive signing key
  const kSecret = new TextEncoder().encode(`AWS4${secretAccessKey}`);
  const kDate = await hmacSha256(kSecret, dateStamp);
  const kRegion = await hmacSha256(kDate, region);
  const kService = await hmacSha256(kRegion, service);
  const kSigning = await hmacSha256(kService, 'aws4_request');

  const signature = toHex(await hmacSha256(kSigning, stringToSign));

  return `${endpoint}${path}?${sortedQuery}&X-Amz-Signature=${signature}`;
}

