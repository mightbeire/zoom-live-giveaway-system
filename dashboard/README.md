# Dashboard Setup

The dashboard is a static private operator page for live status and locking.

## Configure

1. Copy `config.example.js` to `config.js`.
2. Set `n8nBaseUrl` to the n8n workspace base URL.
3. Set `authHeaderName` to the same header name used by Workflow 3.
4. Optionally enter default meeting values.
5. Do not place the admin key inside the file.

## Local preview

From the repository root:

```bash
python -m http.server 8080 --directory dashboard
```

Open `http://localhost:8080`.

## Deploy

Any static host can serve this folder. Only the public n8n base URL and header name are stored in the configuration. The operator enters the private key at runtime.

## Meeting UUID

The meeting UUID identifies the exact meeting occurrence. During a real event, the team can obtain it from the live status data after Zoom participant events begin arriving, or from the event payload/execution in Workflow 2.
