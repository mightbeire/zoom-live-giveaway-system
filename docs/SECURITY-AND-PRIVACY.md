# Security and Privacy

## Secrets

Keep these values out of GitHub and screenshots:

- Supabase database password;
- Zoom Client ID and Client Secret;
- Zoom webhook Secret Token;
- Google OAuth tokens;
- dashboard Header Auth key.

Use n8n credentials wherever the node supports them.

The one Zoom webhook secret saved through Workflow 2 is stored in the `app_secrets` database table. Restrict database access to the implementation team.

## Attendee information

The system stores:

- name;
- email;
- Zoom registrant ID;
- personal join URL;
- attendance session identifiers;
- join and leave timestamps;
- event payloads;
- locked giveaway records.

Collect only what the giveaway needs.

## Public display

The locked sheet uses masked emails. Do not display full attendee emails during the livestream.

Restrict the generated spreadsheet after the giveaway.

## Retention

Before production, Anthony's team should decide:

- how long raw Zoom event payloads are kept;
- how long registration data and join URLs are kept;
- how long the locked winner record is kept;
- who may access attendance disputes.

Delete personal join URLs and raw events when they are no longer needed.

## Dashboard protection

The included dashboard uses a shared Header Auth key entered at runtime. That is suitable for a controlled MVP with a small operator team.

For a wider product, replace it with named user accounts, short-lived sessions, roles and admin-action logging.

## Operational safety

Do not promise a flawless public event until the system has passed a private rehearsal with the real credentials and meeting setup.
