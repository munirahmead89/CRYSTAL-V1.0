# Crystal Real-time Server (Erlang)

This is the live heart of Crystal Messenger - a tiny WhatsApp-style
message switchboard written in Erlang/OTP, the same language that
powered the original WhatsApp backends.

## What it does

- Keeps one ultra-light process per connected phone.
- Delivers chat messages, typing dots, read receipts and call rings
  between users instantly.
- If someone is offline, their messages wait on disk and are delivered
  the moment they come back (like WhatsApp's ticks going from one to
  two).
- Handles multiple devices per person.
- **Verifies every connection's Supabase JWT** before it may speak
  (when configured - see Auth below).

## The app talks to it automatically

The phone app connects to this server first. If this server is not
running or unreachable, the app quietly falls back to Supabase
Realtime, and if even that is unavailable, messages queue on the
device and send later. Nothing ever gets lost.

## Run it on your computer

1. Install Erlang once: https://www.erlang.org/downloads
   (or `winget install Erlang.ErlangOTP`)
2. Double-click nothing needed - just run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File server\start.ps1
   ```

3. The console prints:
   `=== Crystal Messenger real-time server listening on port 8081 ===`

## Point the app at it

Add this line to `.env` using your computer's LAN IP
(find it with `ipconfig`):

```
EXPO_PUBLIC_CRYSTAL_WS_URL=ws://192.168.1.10:8081/ws
```

Rebuild/reinstall the app so the new setting is picked up.

---

## Production deployment (Docker)

```bash
cd server
cp .env.server.example .env.server   # fill in SUPABASE_JWT_SECRET
docker compose up -d --build
curl http://your-server:8081/health  # -> {"status":"ok",...}
```

The offline queue persists across restarts in the `crystal-data`
volume. Logs are size-capped. The container restarts automatically.

Put a TLS-terminating reverse proxy in front (Caddy, Traefik, nginx,
ALB) and point the app at `wss://your-domain.com/ws`. To terminate TLS
inside Erlang instead, mount certs and set `CRYSTAL_WS_CERTFILE` /
`CRYSTAL_WS_KEYFILE`.

## Authentication (IMPORTANT before public launch)

| Mode | When | Behaviour |
|---|---|---|
| `dev_trust` | No `SUPABASE_JWT_SECRET` set | Any user id accepted. **Local development only.** |
| `enforced` | Secret set | Every auth frame must carry a valid Supabase access token (HS256): signature verified, expiry checked (30s grace), `sub` must match the claimed user id. |

Get the secret from Supabase Dashboard -> Settings -> API -> JWT
Secret. The app sends its access token automatically on every connect;
tokens are re-fetched fresh on each reconnect so expired tokens never
brick the connection.

The startup banner always prints the active mode:

```
=== Auth mode: ENFORCED (Supabase JWT verification) ===
!!! Auth mode: DEV TRUST ... Set SUPABASE_JWT_SECRET before production.
```

## Abuse protection

- Per-connection send rate limit (120 events / 10s) - offenders are
  disconnected and reconnect cleanly with backoff.
- Inbound frames larger than 256 KiB are rejected by Cowboy itself.
- Connection cap configurable via `CRYSTAL_WS_MAX_CONN`.
- Dead sockets dropped after 120s of silence (the app pings every 30s).

## Health checks & monitoring

`GET /health` returns JSON stats for load balancers / uptime monitors:

```json
{"status":"ok","uptime_s":3600,"online_users":7,"sockets":9,"auth_mode":"enforced"}
```

## Configuration reference

| Variable | Default | Purpose |
|---|---|---|
| `CRYSTAL_WS_PORT` | `8081` | Listen port |
| `SUPABASE_JWT_SECRET` | *(unset)* | Enables enforced JWT auth |
| `CRYSTAL_DATA_DIR` | `.` | Offline queue location (`/data` in Docker) |
| `CRYSTAL_WS_MAX_CONN` | `50000` | Max simultaneous connections |
| `CRYSTAL_WS_CERTFILE` / `CRYSTAL_WS_KEYFILE` | *(unset)* | Terminate TLS inside the server |

## Changing things (all in `server/src`)

| File              | What lives there                                   |
| ----------------- | -------------------------------------------------- |
| `crystal_ws.erl`    | One process per phone; reads/writes JSON frames, rate limiting |
| `crystal_registry.erl` | Which users are online right now                 |
| `crystal_router.erl`   | Delivery logic: push now, or park for later      |
| `crystal_store.erl`    | Offline waiting-room (survives restarts)         |
| `crystal_auth.erl`     | Supabase JWT verification (HS256)                |
| `crystal_health.erl`   | `/health` monitoring endpoint                    |

## Wire format (JSON text frames)

Client -> Server:

```json
{"type":"auth","user_id":"<sub>","token":"<supabase access_token>"}
{"type":"ping"}
{"type":"send","ref":"m1","to":"user2","event":"message","data":{"text":"hi"}}
```

Server -> Client:

```json
{"type":"welcome","user_id":"abc123"}
{"type":"pong"}
{"type":"ack","ref":"m1","ok":true,"mode":"delivered"}
{"type":"event","from":"user2","event":"message","data":{"text":"hi"}}
{"type":"error","reason":"token_expired"}
```

## Port

Default `8081`. Change with the `CRYSTAL_WS_PORT` environment variable.

## Why Erlang?

Erlang was built by Ericsson for phone switches that must never go
down: millions of lightweight processes, crash-only design, and hot
code reload. A message switch is exactly its home turf - which is why
WhatsApp chose it and why Crystal Messenger uses it too.
