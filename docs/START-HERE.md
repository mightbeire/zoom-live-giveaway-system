# Start Here

This is the shortest path from the repository to a working test.

## 1. Import the workflows

Import these files into n8n in order:

1. `workflows/01-registration-setup-demo.json`
2. `workflows/02-attendance-demo.json`
3. `workflows/03-status-lock-google-sheet.json`

Leave them inactive until the credentials are connected.

## 2. Create one Postgres credential

Create a Supabase project, open its **Connect** panel, and copy the **Session pooler** connection details.

In any Postgres node, create a Postgres credential using:

- Host
- Database
- User
- Password
- Port
- SSL enabled

Select this same credential in every Postgres node across all three workflows.

## 3. Install the database

In Workflow 1, run:

`RUN ONCE — Install Database`

The next node, `Install or Upgrade Database`, creates all required tables and functions.

If that node cannot run the full setup script, open `database/schema.sql` and run it in the Supabase SQL Editor instead.

## 4. Connect Zoom registration

In Workflow 1, open:

`Zoom — Add Meeting Registrant`

Create or select a **Zoom OAuth2 API** credential. The Zoom app needs permission to add meeting registrants.

The meeting itself must require registration and be hosted by an eligible licensed Zoom user.

## 5. Save the Zoom webhook secret

In Workflow 2:

1. Open `Zoom Webhook Secret — Paste Once`.
2. Replace `PASTE_ZOOM_WEBHOOK_SECRET_HERE` with the Zoom Event Subscription Secret Token.
3. Run `RUN ONCE — Save Zoom Webhook Secret`.
4. Confirm `Show Secret Setup Result` says it was saved.
5. Replace the visible value with `SAVED_IN_DATABASE` if the team does not want the secret left on the canvas.

## 6. Connect Google Sheets

In Workflow 3, connect the same Google Sheets OAuth2 credential to:

- `Create Locked Spreadsheet`
- `Append Eligible Rows`
- `Protect & Format Spreadsheet`

The workflow creates a new locked spreadsheet automatically. No spreadsheet ID is required.

## 7. Protect the dashboard webhooks

In Workflow 3, create one Header Auth credential and use it in:

- `Live Status Webhook`
- `Lock Giveaway Webhook`

Use the same header name for both, such as `x-admin-key`.

Do not place the key in GitHub. The dashboard asks the operator to enter it at runtime.

## 8. Run the demo

Follow [`TESTING.md`](TESTING.md). The expected final demo is:

- 25 registered entrants;
- 3 connected staff members who remain excluded;
- 5 entrants who leave;
- 20 eligible entrants;
- final draw range `1–20`.

## 9. Activate the workflows

After the demo passes:

- activate all three workflows;
- copy the production URL from `Zoom Events Webhook` into the Zoom app;
- subscribe to participant joined and participant left events;
- deploy the dashboard;
- run a private live rehearsal.

Do not use the system for a public giveaway before the private rehearsal passes.
