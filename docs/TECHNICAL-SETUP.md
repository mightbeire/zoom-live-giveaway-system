# Technical Setup

This guide uses the exact node names in the supplied workflows.

## Required services

- n8n Cloud or another public n8n deployment
- Supabase Postgres
- Zoom account and Zoom OAuth app
- Google account with Google Sheets access
- Static hosting for the optional dashboard

## A. Database setup

### Create Supabase

1. Create a Supabase project.
2. Open **Connect** in the project dashboard.
3. Use the **Session pooler** details for the n8n Postgres credential.
4. Keep the database password private.

### Create the n8n Postgres credential

Open any Postgres node and create a new Postgres credential.

Fill in the values from the Supabase connection details:

- **Host**: the pooler host
- **Database**: usually `postgres`
- **User**: the full pooler username, including the project reference
- **Password**: the Supabase database password
- **Port**: the session-pooler port shown by Supabase
- **SSL**: enabled

Select the same credential in every purple Postgres node.

### Install the schema

Preferred method:

1. Open Workflow 1.
2. Run `RUN ONCE — Install Database`.
3. Check `Database Setup Complete`.

Fallback method:

1. Open Supabase SQL Editor.
2. Paste `database/schema.sql`.
3. Run it.

The schema creates:

- `entrants`
- `staff`
- `zoom_events`
- `participant_sessions`
- `giveaway_locks`
- `giveaway_lock_entries`
- `meeting_counters`
- `app_secrets`
- the database functions called by the workflows

### Add the real staff list

Use `database/add-staff.example.sql` as a template.

For every team member, add as many identifiers as are available:

- email;
- Zoom user ID;
- Zoom registrant ID;
- role.

The system checks staff during attendance processing and again when the final list is locked.

## B. Workflow 1: registration

### Zoom credential

Open `Zoom — Add Meeting Registrant`.

The node uses the predefined **Zoom OAuth2 API** credential in an HTTP Request because the required action is the Zoom endpoint:

`POST /v2/meetings/{meetingId}/registrants`

The Zoom app needs the granular scope:

- `meeting:write:registrant`, or
- `meeting:write:registrant:admin` when acting across the account.

The host must meet Zoom's requirements for a registration-enabled meeting.

### Registration webhook

Production path:

`POST /webhook/zoom-giveaway/register`

Expected JSON:

```json
{
  "fullName": "Ada Okafor",
  "email": "ada@example.com",
  "meetingId": "123456789",
  "source": "creator-registration-form"
}
```

The response contains the entrant's permanent serial number and unique Zoom join URL.

The calling form or email system must deliver that personal link to the entrant.

## C. Workflow 2: Zoom attendance

### Save the webhook Secret Token

Open `Zoom Webhook Secret — Paste Once`, enter the Event Subscription Secret Token, and run `RUN ONCE — Save Zoom Webhook Secret`.

The production event path is:

`POST /webhook/zoom-giveaway/events`

Use the exact **Production URL** shown by the `Zoom Events Webhook` node in the Zoom app's event-subscription settings.

Subscribe to:

- `meeting.participant_joined`
- `meeting.participant_left`

The Zoom app also needs the participant-read scope required by Zoom for these event subscriptions.

### Why the signature Code node remains

`Verify Zoom Signature & Normalize` must read the raw request body, verify the HMAC signature, reject stale requests, answer Zoom's validation challenge, and create a duplicate-event key.

A normal mapping node cannot safely replace those steps.

## D. Workflow 3: status, locking and Google Sheets

### Header Auth

Create one Header Auth credential in either webhook node.

Suggested header name:

`x-admin-key`

Use a long random value and apply the same credential to:

- `Live Status Webhook`
- `Lock Giveaway Webhook`

### Google Sheets OAuth2

Connect one Google Sheets OAuth2 credential to:

- `Create Locked Spreadsheet`
- `Append Eligible Rows`
- `Protect & Format Spreadsheet`

The first two use native Google Sheets operations. The final HTTP Request remains because tab protection and formatting are not provided by the native operation used here.

### Dashboard endpoints

Status:

`GET /webhook/zoom-giveaway/status?meetingId=...&meetingUuid=...`

Lock:

`POST /webhook/zoom-giveaway/lock`

```json
{
  "meetingId": "123456789",
  "meetingUuid": "ACTUAL_MEETING_INSTANCE_UUID",
  "requestedBy": "creator-dashboard"
}
```

The meeting UUID identifies the exact occurrence. It is different from the public meeting number and is required to stop one meeting instance from being mixed with another.

## E. Dashboard setup

1. Copy `dashboard/config.example.js` to `dashboard/config.js`.
2. Enter the n8n base URL and preferred header name.
3. Do not put the admin key in the file.
4. Deploy the `dashboard` folder on a static host.
5. Enter the key in the page when operating the giveaway.

## F. Final production checks

Before the livestream:

- all three workflows active;
- real staff records added;
- Zoom webhook validated;
- test join and leave events received;
- Google spreadsheet creation tested;
- lock tested twice without reshuffling;
- n8n execution and concurrency limits reviewed for the expected audience size;
- manual fallback agreed.
