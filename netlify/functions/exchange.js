// Serverless function to exchange Supabase recovery code for an access_token
// Requires SERVICE_ROLE_KEY environment variable in Netlify site settings.
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://uolzrncnaoccwnqbbwuy.supabase.co';

exports.handler = async function(event, context) {
  // Allow only POST
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers: { 'Allow': 'POST', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'Method not allowed' })
    };
  }

  const SERVICE_ROLE_KEY = process.env.SERVICE_ROLE_KEY;
  if (!SERVICE_ROLE_KEY) {
    return {
      statusCode: 500,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'Service role key not configured' })
    };
  }

  let recoveryToken = null;
  try {
    const payload = JSON.parse(event.body || '{}');
    recoveryToken = payload.recovery_token || payload.code || null;
  } catch (e) {
    // Try form-encoded
    try {
      const params = new URLSearchParams(event.body || '');
      recoveryToken = params.get('recovery_token') || params.get('code');
    } catch (err) {
      recoveryToken = null;
    }
  }

  if (!recoveryToken) {
    return {
      statusCode: 400,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'Missing recovery_token' })
    };
  }

  // Call Supabase GoTrue token endpoint using the service role key
  try {
    const tokenUrl = `${SUPABASE_URL}/auth/v1/token`;
    const resp = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`
      },
      body: `grant_type=recovery&recovery_token=${encodeURIComponent(recoveryToken)}`
    });

    const body = await resp.text();
    let parsed = null;
    try { parsed = JSON.parse(body); } catch (e) { parsed = { raw: body }; }

    if (!resp.ok) {
      return {
        statusCode: resp.status,
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ error: 'Exchange failed', status: resp.status, body: parsed })
      };
    }

    return {
      statusCode: 200,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify(parsed)
    };
  } catch (e) {
    return {
      statusCode: 500,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'Server error', details: String(e) })
    };
  }
};
