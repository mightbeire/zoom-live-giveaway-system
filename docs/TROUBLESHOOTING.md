# Troubleshooting

## Zoom cannot validate the event endpoint

Check:

- Workflow 2 is active.
- The Zoom app uses the **Production URL** from `Zoom Events Webhook`.
- The saved Secret Token matches the Zoom app.
- The endpoint is public HTTPS.
- The Webhook node still has raw-body handling enabled.
- The validation branch returns both `plainToken` and `encryptedToken`.

## Zoom events arrive but attendees are not identified

Check:

- the attendee registered for this exact meeting;
- they used their personal Zoom link;
- the meeting ID stored with the entrant matches the event;
- Zoom returned a registrant ID or email;
- they did not enter through a shared generic link.

## A staff member appears eligible

Add more of the staff member's known identifiers to the `staff` table:

- email;
- Zoom user ID;
- Zoom registrant ID.

Then have them leave and rejoin before testing again. The lock function also performs a second staff check.

## Connected sessions are higher than eligible entrants

This can be normal.

Connected sessions may include:

- staff;
- unmatched guests;
- one entrant using more than one device.

Eligibility is counted by entrant, not by device.

## The dashboard says unauthorized

Check:

- the header name in `dashboard/config.js` matches the n8n Header Auth credential;
- the operator entered the correct key;
- both status and lock webhooks use the same credential;
- the dashboard points to the correct n8n domain.

## The Google Sheet was not created

Check the Google OAuth credential in all three Google-related nodes.

Do not create a new attendance snapshot. The database lock may already exist.

After fixing Google access, run the lock route again. It should reuse the same database lock rather than reselect attendees.

## The sheet exists but the workflow reports an error

The spreadsheet may have been created before a later protection or audit step failed.

Check the n8n execution and the `giveaway_locks` record before retrying. Avoid manually creating a second official sheet for the same lock.

## Lock returns “No eligible registered attendees”

Check:

- the meeting ID;
- the meeting UUID;
- participant sessions are active;
- entrants were matched;
- staff records are not accidentally matching entrants;
- entrants are not marked disqualified.

## Postgres will not connect

Use the Supabase connection information from **Connect**.

For a cloud workflow, the Session pooler is usually easier than the direct IPv6 connection. Confirm:

- full pooler username;
- correct database password;
- correct port;
- SSL enabled.
