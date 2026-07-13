
> **Implementation status:** The architecture, workflows, database schema and demo are complete. The system has not been tested with Anthony’s live Zoom credentials. Production deployment requires credential connection and a private rehearsal.
# Zoom Live Giveaway

This project makes sure that only registered people who are still present in a Zoom livestream can enter a giveaway.

It keeps your current existing public draw process:

1. People register for live sessions and receive their personal Zoom join link.
2. Zoom tells the system when each participant joins or leaves.
3. Your -team members are excluded.
4. You click Lock Giveaway List from the custom dashboard.
5. The system freezes the eligible attendees and numbers them from `1` to `N`.
6. A protected Google Sheet is created.
7. You share a browser random-number generator like you already do , generate the one number, and find the matching winner in the sheet.

The winner then chooses the available prize they prefer.

## Start here

Technical team: read [`docs/START-HERE.md`](docs/START-HERE.md). this is if you have an in-house automation or dev-ops expert

Creator(Anthony) or producer: read [`docs/HOW-IT-WORKS.md`](docs/HOW-IT-WORKS.md) and [`docs/RUNNING-THE-GIVEAWAY.md`](docs/RUNNING-THE-GIVEAWAY.md).

## What is included

```text
zoom-live-giveaway/
workflows/                         Final n8n workflow JSON files
database/                          Postgres schema and staff template
dashboard/                         Private status and lock webpage
demo/                              Demo script, data and sample payloads
docs/                              Setup, operating and support guides
assets/                            Architecture diagram
 README.md
```

## The three workflows

1. Registration + setup + demo seed  
   Installs the database, processes demo testers, receives registrations, creates unique Zoom registrants, and stores permanent serial numbers.

2. Attendance + demo simulator  
   Verifies Zoom webhook requests, processes join and leave events, tracks active sessions, excludes staff, and provides demo attendance actions.

3. Status + lock + Google Sheet  
   Reports live numbers, creates one immutable eligible-attendee snapshot, creates a Google Sheet, protects it, and returns the final random-number range.

## Important status note

The workflow files have been structurally checked, but this final build has **not** been tested end to end with Anthony's live Zoom account, real database credentials, and Google credentials.

Before using it for a real giveaway, the team must:

- connect the required credentials;
- run the included demo;
- hold a private Zoom rehearsal;
- confirm the current n8n plan can handle the expected webhook volume;
- agree on a manual fallback if a third-party service is unavailable.

See [`docs/IMPLEMENTATION-STATUS.md`](docs/IMPLEMENTATION-STATUS.md) for the exact boundary between built and verified sp you know how to navigate
