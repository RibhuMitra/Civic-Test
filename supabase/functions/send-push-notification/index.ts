import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
  priority?: 'high' | 'normal'
  ttl?: number // Time to live in seconds
}

interface FCMResponse {
  multicast_id: number
  success: number
  failure: number
  canonical_ids: number
  results: Array<{
    message_id?: string
    error?: string
    registration_id?: string
  }>
}

// Validate the payload
function validatePayload(payload: any): payload is NotificationPayload {
  if (!payload.userId || typeof payload.userId !== 'string') {
    throw new Error('userId is required and must be a string')
  }
  if (!payload.title || typeof payload.title !== 'string') {
    throw new Error('title is required and must be a string')
  }
  if (!payload.message || typeof payload.message !== 'string') {
    throw new Error('message is required and must be a string')
  }
  if (!Array.isArray(payload.deviceTokens) || payload.deviceTokens.length === 0) {
    throw new Error('deviceTokens must be a non-empty array')
  }
  if (payload.deviceTokens.length > 1000) {
    throw new Error('Cannot send to more than 1000 devices at once')
  }
  return true
}

// Log notification attempts for debugging and monitoring
async function logNotificationAttempt(
  supabase: any,
  userId: string,
  success: boolean,
  error?: string
) {
  try {
    await supabase.from('notification_logs').insert({
      user_id: userId,
      success,
      error,
      created_at: new Date().toISOString(),
    })
  } catch (logError) {
    console.error('Failed to log notification attempt:', logError)
  }
}

// Update invalid device tokens in the database
async function updateInvalidTokens(
  supabase: any,
  userId: string,
  invalidTokens: string[]
) {
  if (invalidTokens.length === 0) return

  try {
    // Get current tokens
    const { data, error } = await supabase
      .from('notification_preferences')
      .select('device_tokens')
      .eq('user_id', userId)
      .single()

    if (error) throw error

    // Filter out invalid tokens
    const validTokens = (data.device_tokens || []).filter(
      (token: string) => !invalidTokens.includes(token)
    )

    // Update with valid tokens only
    await supabase
      .from('notification_preferences')
      .update({ device_tokens: validTokens })
      .eq('user_id', userId)
  } catch (error) {
    console.error('Failed to update invalid tokens:', error)
  }
}

// Send notification with retry logic
async function sendNotificationWithRetry(
  fcmEndpoint: string,
  fcmServerKey: string,
  notification: any,
  maxRetries: number = 3
): Promise<FCMResponse | null> {
  let lastError: Error | null = null

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(fcmEndpoint, {
        method: 'POST',
        headers: {
          'Authorization': `key=${fcmServerKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(notification),
      })

      if (!response.ok) {
        throw new Error(`FCM responded with status: ${response.status}`)
      }

      const result: FCMResponse = await response.json()
      return result
    } catch (error) {
      lastError = error as Error
      console.error(`Attempt ${attempt} failed:`, error)

      // Don't retry on client errors (4xx)
      if (error.message.includes('status: 4')) {
        break
      }

      // Exponential backoff for retries
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000))
      }
    }
  }

  console.error('All retry attempts failed:', lastError)
  return null
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Initialize Supabase client
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')

  // Validate environment variables
  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(
      JSON.stringify({ error: 'Server configuration error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  if (!fcmServerKey) {
    return new Response(
      JSON.stringify({ error: 'FCM configuration missing' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  try {
    // Parse and validate request body
    const payload: NotificationPayload = await req.json()
    validatePayload(payload)

    const { 
      userId,
      title, 
      message, 
      issueId, 
      distanceKm, 
      deviceTokens,
      priority = 'high',
      ttl = 86400 // Default 24 hours
    } = payload

    // Check if user has notifications enabled
    const { data: prefs } = await supabase
      .from('notification_preferences')
      .select('push_enabled, quiet_hours_start, quiet_hours_end')
      .eq('user_id', userId)
      .single()

    if (prefs && !prefs.push_enabled) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'User has disabled push notifications' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check quiet hours
    if (prefs?.quiet_hours_start && prefs?.quiet_hours_end) {
      const now = new Date()
      const currentTime = now.getHours() * 60 + now.getMinutes()
      
      const [startHour, startMin] = prefs.quiet_hours_start.split(':').map(Number)
      const [endHour, endMin] = prefs.quiet_hours_end.split(':').map(Number)
      
      const quietStart = startHour * 60 + startMin
      const quietEnd = endHour * 60 + endMin

      const inQuietHours = quietStart <= quietEnd 
        ? currentTime >= quietStart && currentTime <= quietEnd
        : currentTime >= quietStart || currentTime <= quietEnd

      if (inQuietHours) {
        return new Response(
          JSON.stringify({ 
            success: false, 
            message: 'Notification blocked during quiet hours' 
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    const fcmEndpoint = 'https://fcm.googleapis.com/fcm/send'
    
    // Prepare notification payload
    const baseNotification = {
      notification: {
        title,
        body: message,
        sound: 'default',
        badge: 1,
        icon: 'ic_notification', // Add your app icon
        color: '#2196F3', // Your app theme color
      },
      data: {
        issueId: issueId || '',
        distanceKm: distanceKm?.toString() || '',
        type: 'new_issue_alert',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        timestamp: new Date().toISOString(),
      },
      priority,
      time_to_live: ttl,
      content_available: true,
    }

    // Send notifications in batches (FCM supports max 1000 per request)
    const batchSize = 500
    const batches = []
    
    for (let i = 0; i < deviceTokens.length; i += batchSize) {
      const batch = deviceTokens.slice(i, i + batchSize)
      
      if (batch.length === 1) {
        // Single device
        batches.push({
          ...baseNotification,
          to: batch[0],
        })
      } else {
        // Multiple devices
        batches.push({
          ...baseNotification,
          registration_ids: batch,
        })
      }
    }

    // Send all batches
    const results: FCMResponse[] = []
    const invalidTokens: string[] = []
    let totalSuccess = 0
    let totalFailure = 0

    for (const [index, batch] of batches.entries()) {
      const result = await sendNotificationWithRetry(
        fcmEndpoint,
        fcmServerKey,
        batch
      )

      if (result) {
        results.push(result)
        totalSuccess += result.success
        totalFailure += result.failure

        // Collect invalid tokens
        if (result.results) {
          const batchTokens = 'registration_ids' in batch 
            ? batch.registration_ids 
            : [batch.to]

          result.results.forEach((res, idx) => {
            if (res.error === 'InvalidRegistration' || 
                res.error === 'NotRegistered') {
              invalidTokens.push(batchTokens[idx])
            }
          })
        }
      } else {
        // Count entire batch as failed if request failed
        const batchSize = 'registration_ids' in batch 
          ? batch.registration_ids.length 
          : 1
        totalFailure += batchSize
      }
    }

    // Clean up invalid tokens
    if (invalidTokens.length > 0) {
      await updateInvalidTokens(supabase, userId, invalidTokens)
    }

    // Log the notification attempt
    await logNotificationAttempt(
      supabase,
      userId,
      totalSuccess > 0,
      totalFailure > 0 ? `Failed to send to ${totalFailure} devices` : undefined
    )

    // Store notification in alerts table for in-app display
    if (issueId && totalSuccess > 0) {
      await supabase.from('alerts').insert({
        user_id: userId,
        issue_id: issueId,
        distance_km: distanceKm || 0,
        alert_type: 'new_issue',
        title,
        message,
        created_at: new Date().toISOString(),
      })
    }

    return new Response(
      JSON.stringify({ 
        success: totalSuccess > 0,
        sent: totalSuccess,
        failed: totalFailure,
        invalidTokens: invalidTokens.length,
        message: `Sent to ${totalSuccess} devices, failed for ${totalFailure} devices`,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    console.error('Notification error:', error)
    
    // Log error for debugging
    if (supabase && payload?.userId) {
      await logNotificationAttempt(
        supabase,
        payload.userId,
        false,
        error.message
      )
    }

    return new Response(
      JSON.stringify({ 
        error: error.message || 'Failed to send notification',
        details: process.env.NODE_ENV === 'development' ? error.stack : undefined
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})