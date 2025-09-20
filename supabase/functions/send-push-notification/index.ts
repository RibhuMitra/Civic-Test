import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  userId: string
  title: string
  message: string
  issueId?: string
  distanceKm?: number
  deviceTokens: string[]
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload: NotificationPayload = await req.json()
    const { title, message, issueId, distanceKm, deviceTokens } = payload

    // Prepare FCM notification
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    const fcmEndpoint = 'https://fcm.googleapis.com/fcm/send'

    const notifications = deviceTokens.map(token => ({
      to: token,
      notification: {
        title,
        body: message,
        sound: 'default',
        badge: 1,
      },
      data: {
        issueId,
        distanceKm: distanceKm?.toString(),
        type: 'new_issue_alert',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      priority: 'high',
    }))

    // Send notifications
    const promises = notifications.map(notification =>
      fetch(fcmEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `key=${fcmServerKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(notification),
      })
    )

    const responses = await Promise.all(promises)
    const results = await Promise.all(
      responses.map(r => r.json())
    )

    return new Response(
      JSON.stringify({ 
        success: true, 
        sent: results.filter(r => r.success === 1).length,
        failed: results.filter(r => r.failure === 1).length,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})