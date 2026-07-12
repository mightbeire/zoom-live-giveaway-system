# How It Works

## The problem

The original registration sheet shows who intended to attend. It does not show who actually joined the Zoom call or who stayed until the giveaway.

If the creator generates a number from the full registration list, the number may belong to someone who is absent.

## The new process


Person registers
      ↓
Receives a personal Zoom join link
      ↓
Zoom reports when the person joins or leaves
      ↓
The system separates entrants, staff and unmatched guests
      ↓
Creator clicks Lock Giveaway List
      ↓
The eligible list is frozen and numbered 1 to N
      ↓
A protected Google Sheet is created
      ↓
Creator uses a public browser random-number generator
      ↓
The generated number points to one winner
```

## What the dashboard numbers mean

- Registered

Everyone who successfully registered for the giveaway.

- Connected sessions

Every active Zoom connection. One person using two devices may create two sessions.

- Identified entrants

Connected people who were matched to a valid registration.

-Staff connected

The creator and your team members currently on the call. They are shown for awareness but excluded from eligibility.

- Unmatched participants

Connected people the system could not connect to a registration or staff record. They are not included silently.

            Eligible now

Registered entrants who are currently present, are not staff, and are not disqualified.

            Locked

The final eligible list has been frozen for that exact meeting instance. Later joins or departures cannot change it.

 Why each entrant gets a personal Zoom link

Display names are unreliable. Someone may join as “iPhone,” a nickname, or a different spelling of their name.

A personal Zoom registration link gives the system a stronger registrant ID and improves the chance that Zoom provides the participant's email for that meeting.

SO Why the final draw still feel transparent ?

The automation does not secretly choose the winner.

It only creates a correct, frozen list numbered from `1` to the exact eligible total. The creator still shares a normal random-number generator on-screen and generates the winning number publicly.
