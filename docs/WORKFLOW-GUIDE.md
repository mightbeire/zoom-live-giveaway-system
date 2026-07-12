# Workflow Guide

## Workflow 1 — Registration + Setup + Demo Seed

File: `workflows/01-registration-setup-demo.json`

### Setup branch

`RUN ONCE — Install Database` installs or upgrades the tables and database functions.

**Why this exists:** the workflow can be handed to another team without asking them to rebuild the database by hand.

### Demo branch

`DEMO — Reset & Seed 25 Entrants` creates 25 fake entrants and 3 fake staff records.

**Why this exists:** the team can demonstrate the system without access to the creator's real Zoom account or attendee data.

### Registration branch

```text
Registration Webhook
→ Validate Registration
→ Find Existing Entrant
→ If duplicate, return existing record
→ Zoom — Add Meeting Registrant
→ Save Entrant & Allocate Serial
→ Return Registration Success
```

`Save Entrant & Allocate Serial` uses Postgres so two registrations arriving together cannot receive the same serial number.

## Workflow 2 — Attendance + Demo Simulator

File: `workflows/02-attendance-demo.json`

### Secret setup branch

`RUN ONCE — Save Zoom Webhook Secret` stores the Zoom Secret Token in Postgres.

### Production webhook branch

```text
Zoom Events Webhook
→ Read Zoom Webhook Secret
→ Verify Zoom Signature & Normalize
→ Answer URL-validation challenge, or acknowledge valid event
→ Process Attendance Transaction
```

`Process Attendance Transaction` does four linked jobs:

1. rejects a duplicate event;
2. matches the participant to an entrant;
3. checks whether the participant is staff;
4. updates that exact Zoom session.

**Why one database transaction is used:** these steps must agree even when many join events arrive close together.

### Demo branches

- `DEMO 0 — Reset Attendance`
- `DEMO 1 — Join 25 Entrants`
- `DEMO 2 — Join 3 Staff`
- `DEMO 3 — Five Entrants Leave`

These branches change the same database tables used by the production flow. Only the event source is simulated.

## Workflow 3 — Status + Lock + Google Sheet

File: `workflows/03-status-lock-google-sheet.json`

### Status routes

The production webhook and demo trigger both call the same database status function.

The result separates:

- registrations;
- active sessions;
- identified entrants;
- staff;
- unmatched guests;
- current eligibility;
- locked state.

### Lock route

```text
Lock request
→ Create or Get Immutable Snapshot
→ If a sheet already exists, return it
→ Otherwise create Google spreadsheet
→ Append eligible rows
→ Protect and format it
→ Save sheet URL on the lock record
→ Return RNG range
```

`Create or Get Immutable Snapshot` is the most important step. It takes a database lock for the meeting UUID, selects eligible entrants, sorts them by permanent serial, and assigns temporary draw numbers from `1` to `N`.

**Why pressing Lock twice does not reshuffle:** the database allows only one lock per meeting UUID. The second request returns the same snapshot.

### Google Sheet columns

- Draw Number
- Original Serial
- Participant Name
- Masked Email
- Present At Lock
- Eligibility

The public random-number generator uses the **Draw Number**, not the original serial.
