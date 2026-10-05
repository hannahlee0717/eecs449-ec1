# Stunny: a time-block study planner

Hannah Lee
UMID: 74432964
EECS 449, Assignment 1

I plan my days on paper with a time-block sheet: one row per hour, little
10-minute boxes, and I color in what I actually got done. Stunny is that sheet,
built in Jac, with a study timer attached. I plan blocks on the web, run the
timer from my laptop or phone, and add or check off tasks from the terminal
without opening a browser. All three talk to the same Jac server, so they always
show the same data.

![Web planner](docs/web.png)

## Features

- **Day sheet.** Date (with arrows to move between days), a goal for the day, and notes.
  All of it is saved per day on the server.
- **Timetable from 4 AM to 4 AM** in 10-minute cells. I study late, so the day doesn't
  end at midnight, and a block like 11 PM–1 AM is a single task.
- **Drag to plan.** Click and drag across empty cells and the Add Task window opens with
  the start and end times filled in. You can also add a task with the + next to a category.
- **Categories** (e.g. a class or "Recruiting") with six soft colors. You can rename,
  recolor or delete them. Deleting a category asks first and removes its tasks.
- **Editing.** Click a block to change its title or times, or to delete it. The block
  moves as soon as you save.
- **Validation.** The title can't be empty, the end has to be after the start, and two
  blocks can't overlap.
- **Study timer.** Start, pause, resume, stop early, or mark done. It counts down the
  planned length of the task. When it runs out, the task is marked complete automatically.
- **Study hours.** The counter is the time the timer actually ran, not the time I
  planned. If I finish a 60-minute block and stop another one after 25 minutes, it
  shows 01:25.
- **Partial coloring.** A finished block is filled in with its category color. If I only
  worked 45 minutes of a 2-hour block, only the first 45 minutes get colored in, like I'd
  do on paper.
- **Sync.** The web and phone apps refresh every few seconds, so a task added from the
  terminal shows up on the timetable almost right away.

## Setup

You need the Jac CLI, version 0.37.23 (check with `jac --version`). Install instructions
are at https://jaclang.org/docs/latest. Nothing else is needed for the web app or the
CLI: Jac brings its own JavaScript tooling and installs the npm packages on the first run.

## Running the web app and server

From the repo root:

```bash
jac run
```

Then open http://localhost:8000. This starts the web app with the planner server in the
same process. Data is stored by Jac's built-in database, so it survives refreshes and
restarts.

To try it:
1. Click **Add Category**, give it a name and pick a color.
2. Drag across some empty cells, type a title and click **DONE**.
3. Press **START** on the timer panel and watch the block fill in on the timetable.
4. Try **PAUSE** / **RESUME** and **Stop early**, or let the timer run out.
5. Click a block to edit it, or click a category name to edit or delete the category.

## CLI

Start the server first (`jac run`), then in another terminal:

```bash
jac run cli -- --help
jac run cli -- category add "EECS 449" --color pink
jac run cli -- category                       # list categories
jac run cli -- add "Read spec" -c "EECS 449" -s 09:00 -e 10:00
jac run cli -- today                          # today's plan, timers and study hours
jac run cli -- timer start 1                  # 1 = the task's number in `today`
jac run cli -- timer pause spec               # or any unique part of the title
jac run cli -- timer stop 1                   # stop early (keeps the time, not marked done)
jac run cli -- done 1                         # mark done (`undo 1` reopens it)
```

Times are 24-hour `HH:MM`. I use `alias stunny="jac run cli --"` so it's just
`stunny today`. The CLI connects to `http://localhost:8000` by default. Set
`STUNNY_SERVER=http://<host>:8000` to use a different server. If the server isn't
running, the CLI tells you to start it.

## Mobile app

The mobile app is written with Jac's mobUI components. The same code runs as a native
React Native app (through Expo) or in a browser. It doesn't have its own data; it
calls the same planner server as the web app and CLI.

**In a browser (easiest, no phone needed).** Use two terminals:

```bash
jac run --no-dev                                  # terminal 1: web app + server
jac run --dev --platform web --port 8100 mobile   # terminal 2: the phone app
```

Open http://localhost:8100. Your browser's phone-size view makes it look right. The web
app here uses `--no-dev` because two Jac dev servers in the same project overwrite each
other's page. If you only want the phone app, `jac run --dev --platform web mobile` on
its own is fine.

**On a phone or simulator:**

```bash
jac run                  # terminal 1
jac run --dev mobile     # terminal 2 (the first run sets up an Expo project)
```

Scan the QR code with the Expo Go app (phone on the same Wi-Fi), or press `a` / `i` for
an Android emulator or iOS simulator. I mostly tested the browser version; I didn't
test on a physical device.

<img src="docs/mobile.png" alt="Mobile app" width="300">

On the phone you can see today's tasks and study hours, run the timer (start, pause,
stop early, mark done), tap a task's circle to check it off, and quickly add a task
with a title, category and start/end time.

## How the pieces fit together

```
  web (browser) ──┐
  mobile app   ───┼──>  planner service (core/planner.jac)  ──>  Jac graph database
  CLI          ───┘        Category -> Task, DayInfo, StudySession
```

`jac.toml` defines four apps: `planner` (the server), `web` (the default app),
`mobile` and `cli`. All the planner logic and data is in `core/planner.jac`. The other
three are just clients. They all import the same functions (`get_day`, `add_task`,
`start_timer`, ...), and Jac turns each import into the right kind of call:
- an in-process call on the server
- an RPC call from the browser
- an HTTP bridge call from the phone and the terminal

Because the server owns everything, there's no `localStorage` and no second copy of a
task anywhere. The web app keeps the latest copy of the day from the server in a React
context (`PlannerContext`). Every change is "call the server, then reload the day".

The time and timer helpers in `core/utils/` are shared, so the server, the web app and
the CLI all do the math the same way.

## Design decisions I'm happy with

**The timer doesn't count.** A naive timer adds 1 every second, which drifts when the
browser throttles a background tab. Instead, each task stores:
- how many seconds were already banked from earlier runs
- the timestamp when the current run started

The elapsed time is always `banked + (now - started)`. The once-a-second interval only
redraws the screen, so the timer is still exact after the laptop sleeps or the page
reloads. Pausing just adds the current run to the bank.

**The server's clock wins.** Start and pause times come from the server. Each response
also includes the server's current time, and the clients adjust for the difference, so
my phone and laptop always show the same number.

**Auto-complete happens on the server.** Before every read or write, the server checks
whether a running timer has used up its planned time. If it has, the server stops it,
marks the task done and logs the session. So a timer I start from the terminal still
finishes correctly with nothing else open.

**Study hours come from a log.** Every pause, stop or finish saves a `StudySession`, and
study hours is the sum of those. Deleting a task later doesn't erase time I already
studied.

**Times are minutes from 4 AM.** 8:00 AM is 240 and 1:00 AM is 1260, so a block that
crosses midnight is still just `start < end`. Duration and the list of 10-minute cells a
task covers are calculated from start and end rather than stored separately.

**No state per cell.** The timetable is 144 plain cells. The only drag state is "where
the drag started" and "where the mouse is now". Task blocks are drawn on top, positioned
from their start and end times, so changing a task's time moves its block automatically.

## Project layout

```
jac.toml               apps: planner, web, mobile, cli
core/planner.jac       data model, endpoints, timer rules
core/utils/            shared time/timer helpers, colors, unit tests
web/main.jac           page layout
web/context/           PlannerContext (server data, clock, polling, actions)
web/components/        Sidebar, Timetable, TaskBlock, TaskModal, CategoryModal,
                       DeleteConfirmation, Modal, Timer
mobile/                phone screen, theme, timer math
cli/                   commands and terminal output
```

## Testing

```bash
jac check     # type-checks all four apps
jac test      # unit tests for the time and timer math
```

I also tested end to end against a running server:
- dragging to create, editing, deleting and recoloring on the web
- adding tasks from the CLI and the phone and seeing them appear on the web
- pausing and resuming without losing time
- a 1-minute task finishing on its own at exactly 60 seconds
- refreshing and restarting without losing data

## Limitations

- There's no login. It's a personal planner, so every client shares one planner. That
  also means the CLI and phone need no setup. Supporting multiple users would mean
  switching the endpoints from `def:pub` to `def:protect`.
- `mobile/timer_math.jac` repeats a few lines of the timer formula. The Jac 0.37 mobile
  bundler wouldn't include helper files that the server also imports, so the phone has
  its own copy.
- Overlapping tasks are rejected instead of drawn side by side.
