import { createClient } from 'npm:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';

interface ReminderCandidate {
  user_id: string;
  recent_poster_names: string[] | null;
}

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers':
        'authorization, apikey, content-type, x-cron-secret',
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
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
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

  const data = (await res.json()) as { access_token: string };
  return data.access_token;
}

function parseFcmError(body: string): { code: string; message: string } {
  try {
    const parsed = JSON.parse(body) as {
      error?: {
        message?: string;
        details?: Array<{ errorCode?: string }>;
      };
    };
    const details = parsed.error?.details ?? [];
    for (const detail of details) {
      if (detail.errorCode) {
        return {
          code: detail.errorCode,
          message: parsed.error?.message ?? detail.errorCode,
        };
      }
    }
    return {
      code: 'FCM_ERROR',
      message: (parsed.error?.message ?? body).trim(),
    };
  } catch {
    return { code: 'FCM_ERROR', message: body.trim() };
  }
}

function buildPostReminderNotification(names: string[]) {
  const title = '食事の記録を投稿しませんか？';
  const cleaned = names.map((name) => name.trim()).filter((name) => name.length > 0);

  if (cleaned.length === 0) {
    return {
      title,
      body: '最後の投稿から24時間が経ちました。今日の食事を記録してみましょう。',
    };
  }
  if (cleaned.length === 1) {
    return {
      title,
      body: `${cleaned[0]}さんも食事を投稿しています。あなたも記録しませんか？`,
    };
  }
  if (cleaned.length === 2) {
    return {
      title,
      body: `${cleaned[0]}さん、${cleaned[1]}さんも食事を投稿しています。あなたも記録しませんか？`,
    };
  }
  return {
    title,
    body: `${cleaned[0]}さん、${cleaned[1]}さんほかも食事を投稿しています。あなたも記録しませんか？`,
  };
}

function isAuthorized(req: Request, cronSecret: string, serviceRoleKey: string) {
  if (!cronSecret && !serviceRoleKey) return false;

  const headerSecret = (req.headers.get('x-cron-secret') ?? '').trim();
  if (cronSecret && headerSecret === cronSecret) return true;

  const authHeader = req.headers.get('Authorization') ?? '';
  const bearer = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
  if (cronSecret && bearer === cronSecret) return true;
  if (serviceRoleKey && bearer === serviceRoleKey) return true;

  return false;
}

async function sendFcmToUser(
  admin: ReturnType<typeof createClient>,
  accessToken: string,
  fcmProjectId: string,
  userId: string,
  notification: { title: string; body: string },
) {
  const { data: tokenRows, error: tokenError } = await admin
    .from('whoeats_device_push_tokens')
    .select('fcm_token')
    .eq('user_id', userId);

  if (tokenError) {
    throw new Error(tokenError.message);
  }

  const tokens = (tokenRows ?? [])
    .map((row) => (row.fcm_token ?? '').toString())
    .filter((token) => token.length > 0);

  if (tokens.length === 0) {
    return { sent: 0, failed: 0 };
  }

  let sent = 0;
  let failed = 0;
  const dataPayload = {
    event_type: 'post_reminder',
    target_user_id: userId,
  };

  for (const token of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification,
            data: dataPayload,
            android: { priority: 'high' },
            apns: {
              headers: { 'apns-priority': '10' },
              payload: {
                aps: {
                  alert: {
                    title: notification.title,
                    body: notification.body,
                  },
                  sound: 'default',
                },
              },
            },
          },
        }),
      },
    );

    if (!res.ok) {
      failed += 1;
      const parsed = parseFcmError(await res.text());
      if (parsed.code === 'UNREGISTERED' || parsed.code === 'INVALID_ARGUMENT') {
        await admin.from('whoeats_device_push_tokens').delete().eq('fcm_token', token);
      }
      continue;
    }

    sent += 1;
  }

  return { sent, failed };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers':
          'authorization, apikey, content-type, x-cron-secret',
      },
    });
  }

  if (req.method !== 'POST') {
    return json(405, { error: 'Method not allowed' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const fcmProjectId = (Deno.env.get('FCM_PROJECT_ID') ?? '').trim();
  const serviceAccountJson = (Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? '').trim();
  const cronSecret = (Deno.env.get('CRON_SECRET') ?? '').trim();

  if (!supabaseUrl || !supabaseServiceRoleKey || !fcmProjectId || !serviceAccountJson) {
    return json(500, { error: 'Missing required environment variables' });
  }

  if (!isAuthorized(req, cronSecret, supabaseServiceRoleKey)) {
    return json(401, { error: 'Unauthorized' });
  }

  let limit = 100;
  try {
    const body = (await req.json()) as { limit?: number };
    if (typeof body.limit === 'number' && body.limit > 0) {
      limit = Math.min(body.limit, 500);
    }
  } catch {
    // empty body is fine
  }

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey);
  const { data: candidates, error: candidateError } = await admin.rpc(
    'list_post_reminder_candidates',
    { p_limit: limit },
  );

  if (candidateError) {
    return json(500, { error: candidateError.message });
  }

  const rows = (candidates ?? []) as ReminderCandidate[];
  if (rows.length === 0) {
    return json(200, { ok: true, candidates: 0, sent: 0, failed: 0 });
  }

  const accessToken = await getGoogleAccessToken(serviceAccountJson);
  let totalSent = 0;
  let totalFailed = 0;
  let processed = 0;
  const errors: Array<{ user_id: string; error: string }> = [];

  for (const row of rows) {
    const userId = (row.user_id ?? '').toString();
    if (!userId) continue;

    const names = Array.isArray(row.recent_poster_names)
      ? row.recent_poster_names.map((name) => name.toString())
      : [];
    const notification = buildPostReminderNotification(names);

    try {
      const result = await sendFcmToUser(
        admin,
        accessToken,
        fcmProjectId,
        userId,
        notification,
      );
      totalSent += result.sent;
      totalFailed += result.failed;

      if (result.sent > 0) {
        const { error: markError } = await admin.rpc('mark_post_reminder_sent', {
          p_user_id: userId,
        });
        if (markError) {
          errors.push({ user_id: userId, error: markError.message });
        } else {
          processed += 1;
        }
      }
    } catch (error) {
      errors.push({
        user_id: userId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return json(200, {
    ok: true,
    candidates: rows.length,
    processed,
    sent: totalSent,
    failed: totalFailed,
    errors,
  });
});
