# Plinket feedback relay on Raspberry Pi

This dependency-free Node.js 24 service accepts the app's reports and JPEG
screenshots, uploads screenshots to Linear, then creates an issue in the Plinket
project's **Triage** state. The Linear API key lives only on the Pi. The app never
needs a Linear account or key. Use a 64-bit Raspberry Pi OS with Docker Compose,
or run Node.js 24 directly.

## Setup

1. Copy this directory to the Pi and run `cp .env.example .env`.
2. Create a Linear personal API key with issue read/create and file upload access
   for team **4z**. Enter it in `.env` as `LINEAR_API_KEY`. Keep `.env` private
   (`chmod 600 .env`); it is excluded from Git and the Docker build context.
3. The example includes the current Plinket team, project and Triage UUIDs. Verify
   them if the Linear workspace changes. No state or routing is supplied by clients.
4. Run `docker compose up -d --build`. The published port binds to localhost only.
5. Put your existing HTTPS reverse proxy in front of `127.0.0.1:8080`. For Caddy
   running directly on the Pi, with your own domain and DNS pointing to the Pi:

   ```caddyfile
   plinketreport.4z.nu {
       reverse_proxy 127.0.0.1:8080 {
           header_up X-Forwarded-For {remote_host}
       }
   }
   ```

   Allow inbound HTTPS to Caddy; never expose port 8080 directly. The example
   `.env` sets `TRUST_PROXY=true`, so the proxy **must overwrite**
   `X-Forwarded-For` with the actual client address. With additional proxies or
   tunnels, configure the trusted hop's verified client address instead. Set
   `TRUST_PROXY=false` when running without a proxy. A proxy in another container
   needs its own private network connection to this service.
6. Check `curl --fail https://plinketreport.4z.nu/health`. This checks the HTTP
   service only; it does not check the Linear credential or create a test issue.
7. `PLINKET_FEEDBACK_URL` in `project.yml` already points to
   `https://plinketreport.4z.nu/report`. If that address changes, update the setting
   and run `xcodegen generate` before archiving. Or pass
   `PLINKET_FEEDBACK_URL=https://…/report` to `xcodebuild`. An empty setting disables
   Send with an explanatory message. Do not put any secret in this URL or the
   app's build settings.

Without Docker, set the environment variables from `.env` in your service
manager and run `node server.mjs`. It binds to `127.0.0.1:8080` by default;
`HOST` and `PORT` can override that. Use a service manager to restart it.

## Verify and operate

Run `npm test` (or `node --test`) with Node.js 24. Tests use an in-process fake
Linear API: they upload nothing and create no real issues. The service has no npm
dependencies. `docker compose logs --tail 50 feedback` shows startup and generic
submission failures. Reports, screenshots, IPs and credentials are never logged.

After deploying, submit one report from an app build with the real URL configured,
including a screenshot. Verify its image and metadata in **Plinket → Triage** in
Linear. This is the end-to-end check; local tests cannot verify your Linear key,
permissions, DNS, TLS or reverse proxy.

The endpoint is intentionally public, with no credential embedded in the app.
It limits requests to 5 per client IP and 50 globally per 10 minutes, at most four
concurrent submissions, 9 MiB of JSON, and three JPEG screenshots of 2 MiB each.
Put stronger traffic controls at the reverse proxy if needed. Rate counters are
in memory and reset on restart; run one instance. The relay accepts requests only
on POST `/report` and does not enable browser CORS.

A stable, namespaced issue UUID makes a retry of the same report return success
without creating another issue, including after restarting the Pi. Concurrent
retries in one process share the same operation. An issue is created only after
all screenshot uploads succeed. Failed uploads can leave unreferenced files in
Linear; no report is marked successful unless issue creation is confirmed.
Deleting an issue removes the deduplication record, so a later retry can recreate
it. Editing a draft after a failed attempt starts a new report ID.

No report data is persisted on the Pi. Linear stores the report and screenshots.
To stop intake, run `docker compose stop feedback`. Rotate the API key in Linear
and `.env`, then recreate the container with `docker compose up -d --force-recreate`.
