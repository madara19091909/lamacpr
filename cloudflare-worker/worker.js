/**
 * LAMMA media Worker
 * Upload path: Flutter -> Cloudflare Worker -> Telegram Bot -> Telegram Channel
 * Read path: Flutter Image.network -> Worker /image -> Telegram file CDN
 *
 * Required Worker bindings:
 *   TELEGRAM_BOT_TOKEN (Secret)
 *   TELEGRAM_CHANNEL_ID (Text or Secret)
 *   FIREBASE_API_KEY (Text)
 * Optional:
 *   FIREBASE_PROJECT_ID (Text; defaults to lamma-9a231)
 *
 * Deploy this script to the existing Worker only after backing up its current
 * source. This script preserves POST /upload and GET /image and adds the
 * badge, verification and emoji upload kinds.
 */

const MAX_IMAGE_BYTES = 9 * 1024 * 1024;
const ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);
const PROFILE_KINDS = new Set(['avatar', 'banner']);
const ADMIN_KINDS = new Set(['badge', 'verification', 'emoji']);

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '86400',
  };
}

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders(),
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      ...extraHeaders,
    },
  });
}

function safeFileName(name, kind, mime) {
  const clean = String(name || `${kind}.jpg`)
    .split(/[\\/]/)
    .pop()
    .replace(/[^A-Za-z0-9._-]/g, '_')
    .slice(0, 100);
  const ext = ({
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
  })[mime] || 'jpg';
  const stem = clean.replace(/\.[^.]*$/, '') || kind;
  return `${stem}.${ext}`;
}

async function detectImageMime(file) {
  const bytes = new Uint8Array(await file.slice(0, 12).arrayBuffer());
  if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) return 'image/jpeg';
  if (bytes.length >= 4 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) return 'image/png';
  if (bytes.length >= 3 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) return 'image/gif';
  if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46
      && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) return 'image/webp';
  return null;
}

function mimeFromPath(path) {
  const lower = String(path || '').toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

async function verifyFirebaseToken(idToken, env) {
  if (!env.FIREBASE_API_KEY) throw new Error('FIREBASE_API_KEY is not configured.');
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_API_KEY)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    },
  );
  const data = await response.json().catch(() => ({}));
  const account = Array.isArray(data.users) ? data.users[0] : null;
  if (!response.ok || !account?.localId || account.disabled === true) {
    return null;
  }
  return { uid: account.localId };
}

async function isFirebaseAdmin(uid, idToken, env) {
  const projectId = env.FIREBASE_PROJECT_ID || 'lamma-9a231';
  const url = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents/admins/${encodeURIComponent(uid)}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  if (response.status === 404) return false;
  if (!response.ok) {
    // Fail closed: an authorization or Firestore error must never grant admin.
    throw new Error(`Could not verify admin permission (${response.status}).`);
  }
  return true;
}

async function uploadImage(request, env, url) {
  if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHANNEL_ID) {
    return json({ ok: false, error: 'Telegram Worker settings are incomplete.' }, 500);
  }

  const authorization = request.headers.get('Authorization') || '';
  const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) return json({ ok: false, error: 'Authentication required.' }, 401);
  const idToken = tokenMatch[1].trim();
  const account = await verifyFirebaseToken(idToken, env);
  if (!account) return json({ ok: false, error: 'Invalid or expired Firebase session.' }, 401);

  const form = await request.formData();
  const kind = String(form.get('kind') || '').trim().toLowerCase();
  const image = form.get('image');
  if (!PROFILE_KINDS.has(kind) && !ADMIN_KINDS.has(kind)) {
    return json({ ok: false, error: 'Unsupported upload kind.' }, 400);
  }
  if (!image || typeof image.arrayBuffer !== 'function' || typeof image.size !== 'number') {
    return json({ ok: false, error: 'Image file is missing.' }, 400);
  }
  if (image.size < 1 || image.size > MAX_IMAGE_BYTES) {
    return json({ ok: false, error: 'Image must be 9 MB or smaller.' }, 413);
  }
  const declaredMime = String(image.type || '').toLowerCase();
  const detectedMime = await detectImageMime(image);
  if (!detectedMime || !ALLOWED_MIME.has(detectedMime) || (declaredMime && declaredMime !== detectedMime)) {
    return json({ ok: false, error: 'The selected file is not a supported JPG, PNG, WEBP or GIF image.' }, 415);
  }

  if (ADMIN_KINDS.has(kind)) {
    const admin = await isFirebaseAdmin(account.uid, idToken, env);
    if (!admin) return json({ ok: false, error: 'Administrator permission required.' }, 403);
  }

  const telegramForm = new FormData();
  telegramForm.set('chat_id', env.TELEGRAM_CHANNEL_ID);
  telegramForm.set('caption', `LAMMA media • ${kind}`);
  telegramForm.set('document', image, safeFileName(image.name, kind, detectedMime));

  const telegramResponse = await fetch(
    `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendDocument`,
    { method: 'POST', body: telegramForm },
  );
  const telegramData = await telegramResponse.json().catch(() => ({}));
  if (!telegramResponse.ok || telegramData.ok !== true) {
    const detail = telegramData.description || `Telegram API failed (${telegramResponse.status}).`;
    return json({ ok: false, error: 'Telegram upload failed.', details: detail }, 502);
  }

  const document = telegramData.result?.document;
  const fileId = document?.file_id;
  if (!fileId) return json({ ok: false, error: 'Telegram did not return a file ID.' }, 502);

  const imageUrl = `${url.origin}/image?file_id=${encodeURIComponent(fileId)}`;
  return json({
    ok: true,
    kind,
    mimeType: detectedMime,
    imageUrl,
    messageId: telegramData.result?.message_id ?? null,
  }, 201);
}

async function serveImage(url, env) {
  if (!env.TELEGRAM_BOT_TOKEN) {
    return json({ ok: false, error: 'Telegram bot is not configured.' }, 500);
  }
  const pathFileId = url.pathname.startsWith('/image/')
    ? decodeURIComponent(url.pathname.slice('/image/'.length))
    : null;
  const fileId = url.searchParams.get('file_id') || url.searchParams.get('fileId')
    || url.searchParams.get('id') || pathFileId;
  if (!fileId || fileId.length > 2048) {
    return json({ ok: false, error: 'A valid file_id is required.' }, 400);
  }

  const metaResponse = await fetch(
    `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/getFile?file_id=${encodeURIComponent(fileId)}`,
  );
  const meta = await metaResponse.json().catch(() => ({}));
  const filePath = meta.result?.file_path;
  if (!metaResponse.ok || meta.ok !== true || !filePath) {
    return json({ ok: false, error: 'Image not found in Telegram.' }, 404);
  }

  const fileResponse = await fetch(
    `https://api.telegram.org/file/bot${env.TELEGRAM_BOT_TOKEN}/${filePath}`,
  );
  if (!fileResponse.ok) {
    return json({ ok: false, error: 'Could not download image from Telegram.' }, 502);
  }

  const headers = new Headers(corsHeaders());
  const upstreamType = fileResponse.headers.get('Content-Type');
  headers.set('Content-Type', (!upstreamType || upstreamType === 'application/octet-stream')
    ? mimeFromPath(filePath)
    : upstreamType);
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Content-Disposition', 'inline');
  const size = fileResponse.headers.get('Content-Length');
  if (size) headers.set('Content-Length', size);
  return new Response(fileResponse.body, { status: 200, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders() });
    if (request.method === 'GET' && url.pathname === '/') {
      return json({ ok: true, service: 'LAMMA media worker' });
    }
    try {
      if (request.method === 'POST' && url.pathname === '/upload') {
        return await uploadImage(request, env, url);
      }
      if (request.method === 'GET' && url.pathname === '/image') {
        return await serveImage(url, env);
      }
      return json({ ok: false, error: 'Not found.' }, 404);
    } catch (error) {
      return json({
        ok: false,
        error: 'Worker request failed.',
        details: error instanceof Error ? error.message : String(error),
      }, 500);
    }
  },
};
