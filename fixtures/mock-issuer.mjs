// A tiny mock AID issuer for exercising tests/07-federation. NOT an implementation to copy:
// it answers just enough of the issuer requirements R1-R6 to drive the tests down their
// pass, fail and skip paths. Usage: node mock-issuer.mjs <good|bad> <port>
import http from 'node:http'
import { generateKeyPairSync, createSign } from 'node:crypto'

const mode = process.argv[2] ?? 'good'
const port = Number(process.argv[3] ?? 0)
const good = mode === 'good'
const b64u = b => Buffer.from(b).toString('base64url')
const REGISTERED = 'https://crm.acme.example'
const CLIENT = { id: 'rp', secret: 'rp-secret' }

const keys = [generateKeyPairSync('rsa', { modulusLength: 2048 })]
if (good) keys.push(generateKeyPairSync('rsa', { modulusLength: 2048 })) // rotation overlap: new key first
const kid = i => (good || i === 0 ? `key-${i}` : undefined)
const jwks = { keys: keys.map((k, i) => ({ ...k.publicKey.export({ format: 'jwk' }), use: 'sig', alg: 'RS256', ...(good ? { kid: kid(i) } : {}) })) }
const sign = (claims) => {
  const header = b64u(JSON.stringify({ alg: 'RS256', typ: 'JWT', ...(good ? { kid: kid(0) } : {}) }))
  const body = b64u(JSON.stringify(claims))
  const s = createSign('RSA-SHA256').update(`${header}.${body}`).sign(keys[0].privateKey)
  return `${header}.${body}.${b64u(s)}`
}

let base = ''
const json = (res, status, obj) => { res.writeHead(status, { 'content-type': 'application/json' }); res.end(JSON.stringify(obj)) }
const form = req => new Promise(r => { let d = ''; req.on('data', c => { d += c }); req.on('end', () => r(new URLSearchParams(d))) })
const decode = t => { try { return JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString()) } catch { return null } }

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x')
  if (url.pathname === '/.well-known/oauth-authorization-server') {
    return json(res, 200, { issuer: base, token_endpoint: `${base}/token`, jwks_uri: `${base}/jwks.json`, introspection_endpoint: `${base}/introspect` })
  }
  if (url.pathname === '/jwks.json') return json(res, 200, jwks)
  if (url.pathname === '/token') {
    const f = await form(req); const resource = f.get('resource')
    if (resource && good && resource !== REGISTERED) return json(res, 400, { error: 'invalid_target' })
    const now = Math.floor(Date.now() / 1000)
    const scopes = ['contacts:read', 'contacts:create']
    const claims = { iss: base, sub: 'agent:ag-1', agent_id: 'ag-1', iat: now, exp: now + 900, jti: `j${now}`,
      aud: good ? (resource ? [resource] : ['aid-generic']) : ['client_app', 'api_service'], scopes, ...(good ? { scope: scopes.join(' ') } : {}) }
    return json(res, 200, { access_token: sign(claims), token_type: 'Bearer' })
  }
  if (url.pathname === '/introspect') {
    const f = await form(req)
    if (good) {
      const auth = req.headers.authorization ?? ''
      if (auth !== `Basic ${Buffer.from(`${CLIENT.id}:${CLIENT.secret}`).toString('base64')}`) return json(res, 401, { error: 'invalid_client' })
    }
    const c = decode(f.get('token') ?? '')
    if (!c || c.sub === 'agent:revoked') return json(res, 200, { active: false })
    return json(res, 200, { active: true, sub: c.sub, agent_id: c.agent_id, agent_status: 'active', agent_role: 'support', ...(good ? { sponsor: 'ana@acme.example' } : {}) })
  }
  if (url.pathname === '/revoked-token') {
    const now = Math.floor(Date.now() / 1000)
    return json(res, 200, { token: sign({ iss: base, sub: 'agent:revoked', agent_id: 'revoked', iat: now, exp: now + 900, aud: ['aid-generic'] }) })
  }
  if (url.pathname === '/sample-event') {
    const now = Math.floor(Date.now() / 1000)
    const claims = { iss: base, aud: 'https://rp.example/_events', iat: now, jti: `e${now}`,
      events: { 'urn:aid:event:agent-suspended': { subject: { agent_id: 'ag-1', agent_address: 'lola@acme.example' } } } }
    return json(res, 200, { event: sign(claims) })
  }
  json(res, 404, { error: 'not_found' })
})
server.listen(port, '127.0.0.1', () => { base = `http://127.0.0.1:${server.address().port}`; console.log(server.address().port) })
