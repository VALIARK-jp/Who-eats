import { createClient } from 'npm:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';

type PushEventType = 'like' | 'comment' | 'friend_request' | 'friend_accepted';

interface PushRequestBody {
  target_user_id?: string;
  event_type?: PushEventType;
  post_id?: string;
  comment_id?: string;
  friend_id?: string;
}

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
    },
  });
}

async function getGoogleAccessToken(serviceAccountJson: string) {
  const credentials = JSON.parse(serviceAccountJson) as {
    client_email: string;
    private_key: string;
    token_uri?: string;
  };
  const tokenUri = credentials.token_uri ?? 'https://oauth2.googleapis.com/token';
  const privateKey = credentials.private_key.replace(/\\n/g, '\n');
  const key = await importPKCS8(privateKey, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(credentials.client_email)
    .setSubject(credentials.client_email)
    .setAudience(tokenUri)
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);

  const res = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!res.ok) {
    throw new Error(`Google token exchange failed: ${res.status} ${await res.text()}`);
  }

  const data = await res.json() as { access_token: string };
  return data.access_token;
}

function buildNotification(eventType: PushEventType, actorName: string) {
  switch (eventType) {
    case 'like':
      return {
        title: 'いいねが届きました',
        body: `${actorName} さんがあなたの投稿にいいねしました`,
      };
    case 'comment':
      return {
        title: 'コメントが届きました',
        body: `${actorName} さんがあなたの投稿にコメントしました`,
      };
    case 'friend_request':
      return {
        title: '友達申請が届きました',
        body: `${actorName} さんから友達申請が届きました`,
      };
    case 'friend_accepted':
      return {
        title: '友達になりました',
        body: `${actorName} さんと友達になりました`,
      };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
      },
    });
  }

  if (req.method !== 'POST') {
    return json(405, { error: 'Method not allowed' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const fcmProjectId = Deno.env.get('FCM_PROJECT_ID') ?? '';
  const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? '';

  if (!supabaseUrl || !supabaseServiceRoleKey || !fcmProjectId || !serviceAccountJson) {
    return json(500, { error: 'Missing required environment variables' });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  if (!bearer) return json(401, { error: 'Missing Authorization header' });

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey);
  const { data: authData, error: authError } = await admin.auth.getUser(bearer);
  if (authError || !authData.user) {
    return json(401, { error: 'Unauthorized' });
  }

  const body = (await req.json()) as PushRequestBody;
  const targetUserId = (body.target_user_id ?? '').trim();
  const eventType = body.event_type;
  if (!targetUserId || !eventType) {
    return json(400, { error: 'target_user_id and event_type are required' });
  }

  const { data: actorRow } = await admin
    .from('whoeats_users')
    .select('name, user_code')
    .eq('id', authData.user.id)
    .maybeSingle();
  const actorName = (actorRow?.name ?? actorRow?.user_code ?? 'ユーザー').toString();

  const { data: tokenRows, error: tokenError } = await admin
    .from('whoeats_device_push_tokens')
    .select('fcm_token')
    .eq('user_id', targetUserId);
  if (tokenError) {
    return json(500, { error: tokenError.message });
  }

  const tokens = (tokenRows ?? [])
    .map((row) => (row.fcm_token ?? '').toString())
    .filter((token) => token.length > 0);

  if (tokens.length === 0) {
    return json(200, { ok: true, sent: 0, reason: 'no tokens' });
  }

  const accessToken = await getGoogleAccessToken(serviceAccountJson);
  const notification = buildNotification(eventType, actorName);
  const payload = {
    notification,
    data: {
      event_type: eventType,
      post_id: (body.post_id ?? '').toString(),
      comment_id: (body.comment_id ?? '').toString(),
      friend_id: (body.friend_id ?? '').toString(),
      actor_user_id: authData.user.id,
    },
    android: { priority: 'high' },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  };

  const results = await Promise.allSettled(
    tokens.map(async (token) => {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            ...payload,
          },
        }),
      });
      if (!res.ok) {
        throw new Error(`FCM send failed: ${res.status} ${await res.text()}`);
      }
      return await res.json();
    }),
  );

  const success = results.filter((r) => r.status === 'fulfilled').length;
  const failed = results.length - success;
  return json(200, { ok: true, sent: success, failed });
});
