import webPush from 'web-push'
import { createClient } from '@supabase/supabase-js'

/**
 * Delivers a web push to every device of one user.
 *
 * Invoked by a Supabase Database Webhook on `notifications` INSERT (see
 * supabase/migrations README). The webhook must send our shared secret in the
 * `x-push-secret` header. Body is either the raw webhook payload
 * ({ type, table, record }) or a direct { user_id, title, body, url }.
 */

// Map a notification type to the in-app screen its click should open.
function urlForType(type?: string): string {
  switch (type) {
    case 'swap_request':
    case 'recruit_apply':
    case 'recruit_approved':
      return '/requests'
    case 'schedule_published':
      return '/schedule'
    case 'swap_accepted':
      return '/history'
    default:
      return '/notifications'
  }
}

export default defineEventHandler(async (event) => {
  const cfg = useRuntimeConfig()
  const secret = cfg.pushWebhookSecret
  const vapidPublic = cfg.public.vapidPublicKey
  const vapidPrivate = cfg.vapidPrivateKey
  const serviceKey = cfg.supabaseServiceKey
  const supabaseUrl = process.env.SUPABASE_URL

  if (!secret || !vapidPublic || !vapidPrivate || !serviceKey || !supabaseUrl) {
    throw createError({ statusCode: 500, statusMessage: 'Push not configured' })
  }

  // Auth: reject anything without the shared secret.
  if (getHeader(event, 'x-push-secret') !== secret) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
  }

  // Parse the raw body ourselves: pg_net can send a Content-Type that trips
  // H3's readBody ("Invalid JSON body"), even though the JSON itself is valid.
  const raw = await readRawBody(event, 'utf8')
  let payload: any = {}
  if (raw) {
    try {
      payload = JSON.parse(raw)
    } catch {
      console.error('[push] non-JSON body; content-type =', getHeader(event, 'content-type'))
      throw createError({ statusCode: 400, statusMessage: 'Invalid JSON body' })
    }
  }
  const record = payload?.record ?? payload
  const userId: string | undefined = record?.user_id
  if (!userId) throw createError({ statusCode: 400, statusMessage: 'Missing user_id' })

  const title: string = record?.title ?? 'DeskMate'
  const body: string = record?.body ?? ''
  const url: string = record?.url ?? urlForType(record?.type)

  webPush.setVapidDetails(cfg.vapidSubject || 'mailto:admin@deskmate.app', vapidPublic, vapidPrivate)

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  })

  const { data: subs } = await supabase
    .from('push_subscriptions')
    .select('endpoint, p256dh, auth')
    .eq('user_id', userId)

  if (!subs?.length) return { sent: 0, total: 0 }

  const message = JSON.stringify({ title, body, url })
  const staleEndpoints: string[] = []
  let sent = 0

  await Promise.allSettled(
    subs.map(async (s) => {
      try {
        await webPush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          message
        )
        sent++
      } catch (err: any) {
        // 404/410 → subscription gone; drop it.
        if (err?.statusCode === 404 || err?.statusCode === 410) {
          staleEndpoints.push(s.endpoint)
        }
      }
    })
  )

  if (staleEndpoints.length) {
    await supabase.from('push_subscriptions').delete().in('endpoint', staleEndpoints)
  }

  return { sent, total: subs.length }
})
