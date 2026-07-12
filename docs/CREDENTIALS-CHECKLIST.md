# Credentials Checklist

| Credential | Used in | What the team provides |
|---|---|---|
| Postgres | Every Postgres node | Supabase Session pooler host, database, user, password, port, SSL |
| Zoom OAuth2 API | `Zoom — Add Meeting Registrant` | Zoom OAuth app Client ID/Secret and required registrant scope |
| Google Sheets OAuth2 | Three Google-related nodes in Workflow 3 | Google account authorization |
| Header Auth | `Live Status Webhook`, `Lock Giveaway Webhook` | One private header name and value |
| Zoom webhook Secret Token | Saved once through Workflow 2 | Secret Token from Zoom Event Subscription |

## Rules

- Reuse one credential per service.
- Do not paste credentials into sticky notes or documentation.
- Do not commit `dashboard/config.js` if it contains private deployment values.
- Do not share screenshots showing credential fields.
