# Testing

## A. Demo test without real Zoom attendance

Use the manual triggers in this order.

### 1. Install the database

Workflow 1:

`RUN ONCE — Install Database`

Expected: database setup completes without an error.

### 2. Seed demo data

Workflow 1:

`DEMO — Reset & Seed 25 Entrants`

Expected:

- 25 entrants;
- 3 staff members;
- old demo attendance and locks removed.

### 3. Reset attendance

Workflow 2:

`DEMO 0 — Reset Attendance`

Expected: zero connected sessions.

### 4. Join entrants

Workflow 2:

`DEMO 1 — Join 25 Entrants`

Expected: 25 identified entrants and 25 eligible entrants.

### 5. Join staff

Workflow 2:

`DEMO 2 — Join 3 Staff`

Expected:

- connected sessions rise to 28;
- staff connected becomes 3;
- eligible entrants remain 25.

### 6. Five entrants leave

Workflow 2:

`DEMO 3 — Five Entrants Leave`

Expected:

- identified entrants becomes 20;
- eligible entrants becomes 20;
- staff remains excluded.

### 7. Check status

Workflow 3:

`DEMO — Check Live Status`

Expected:

```text
registered: 25
connectedSessions: 23
identifiedEntrants: 20
staffConnected: 3
currentlyEligible: 20
locked: false
```

### 8. Lock and create the sheet

Workflow 3:

`DEMO — Lock & Create Google Sheet`

Expected:

- one lock is created;
- 20 rows are written;
- random-number range is `1–20`;
- staff are absent;
- emails are masked.

### 9. Run the same lock again

Expected: the original lock and sheet are returned. Entrants are not renumbered.

## B. Private Zoom rehearsal

Test these cases with real credentials before production:

| Test | Expected result |
|---|---|
| Registered entrant joins using personal link | Matched and eligible |
| Entrant leaves | No longer currently eligible before lock |
| Entrant reconnects | Eligible again without a duplicate entrant |
| Entrant uses two devices | Two sessions, one eligible entrant |
| One device leaves, one stays | Entrant remains eligible |
| Staff member joins | Counted as staff, never eligible |
| Unregistered guest joins | Counted as unmatched, never eligible |
| Same webhook event is retried | Marked duplicate; state is not changed twice |
| Invalid webhook signature | Rejected before attendance update |
| Lock is pressed twice | Same immutable snapshot returned |
| Entrant joins after lock | Does not enter locked list |
| Entrant leaves after lock | Locked list remains unchanged |
| Google Sheet call fails after lock | Database snapshot remains the official list |

## C. Load and plan check

A small demo does not prove that the current n8n Cloud plan can process the real event burst.

Before the public event, review:

- monthly execution allowance;
- concurrent execution allowance;
- expected join, leave and reconnect events;
- Zoom and Google API rate limits;
- database connection limits.

For a very large live event, the team may choose to move webhook intake to a lightweight endpoint or queue while keeping n8n for registration, locking and reporting.
