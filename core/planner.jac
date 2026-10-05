"""Stunny planner service: the single source of truth for every client.

Graph shape (all hanging off `root`, persisted by the Jac runtime):

    root --> Category --> Task          deleting a Category deletes its Tasks
    root --> DayInfo                    goal + note for one date
    root --> StudySession               one row per finished timer run

Study hours are the sum of StudySession rows, i.e. real timer time, never the
sum of scheduled durations. Sessions are kept even if their task is deleted.

Every mutation stamps time with the server clock, and `settle()` auto-finishes
any running timer that has reached its planned duration, so the web app, the
phone and the CLI all observe the same timer state.
"""

import time;
import from datetime { datetime, timedelta }
import from core.utils.time_utils {
    DAY_START_HOUR,
    validate_range,
    duration_minutes,
    minutes_to_label,
    time_to_minutes,
    end_time_to_minutes
}
import from core.utils.timer_utils {
    RUNNING,
    PAUSED,
    STOPPED,
    IDLE,
    elapsed_seconds,
    is_finished
}

glob CATEGORY_COLORS: list[str] = [
         "yellow", "pink", "green", "blue", "purple", "orange"
     ];

# ---------------------------------------------------------------------------
# Persisted graph
# ---------------------------------------------------------------------------

node Category {
    has name: str,
        color: str = "pink";
}

node Task {
    has title: str,
        date: str,
        planned_start: int,
        planned_end: int,
        completed: bool = False,
        timer_status: str = "idle",
        total_elapsed: float = 0.0,
        timer_started_at: float = 0.0,
        timer_paused_at: float = 0.0;
}

node DayInfo {
    has date: str,
        goal: str = "",
        note: str = "";
}

node StudySession {
    has task_id: str,
        task_title: str,
        date: str,
        started_at: float,
        ended_at: float,
        seconds: float;
}

# ---------------------------------------------------------------------------
# Wire views (what the clients receive)
# ---------------------------------------------------------------------------

obj CategoryView {
    has id: str,
        name: str,
        color: str;
}

obj TaskView {
    has id: str,
        title: str,
        category_id: str,
        category_name: str,
        color: str,
        date: str,
        planned_start: int,
        planned_end: int,
        duration: int,
        time_label: str,
        completed: bool,
        timer_status: str,
        total_elapsed_time: float,
        timer_started_at: float,
        timer_paused_at: float;
}

obj PlannerDay {
    has date: str,
        goal: str,
        note: str,
        categories: list[CategoryView],
        tasks: list[TaskView],
        study_seconds: float,
        active_task_id: str,
        server_now: float;
}

obj ActionResult {
    has ok: bool,
        error: str = "",
        id: str = "";
}

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def:priv now_ms -> float {
    return time.time() * 1000.0;
}

"""The planner day starts at 4 AM, so 1 AM on the 6th still belongs to the 5th."""
def:priv planner_today -> str {
    return (datetime.now() - timedelta(hours=DAY_START_HOUR)).strftime("%Y-%m-%d");
}

def:priv resolve_date(date: str) -> str {
    return date if date else planner_today();
}

def:priv ok(id: str = "") -> ActionResult {
    return ActionResult(ok=True, id=id);
}

def:priv fail(msg: str) -> ActionResult {
    return ActionResult(ok=False, error=msg);
}

def:priv all_categories -> list[Category] {
    return [root -->][?:Category];
}

def:priv all_tasks -> list[Task] {
    out: list[Task] = [];
    for c in all_categories() {
        out.extend([c -->][?:Task]);
    }
    return out;
}

def:priv find_category(id: str) -> Category | None {
    for c in all_categories() {
        if jid(c) == id {
            return c;
        }
    }
    return None;
}

def:priv find_task(id: str) -> Task | None {
    for t in all_tasks() {
        if jid(t) == id {
            return t;
        }
    }
    return None;
}

def:priv category_of(t: Task) -> Category | None {
    owners = [t <--][?:Category];
    return owners[0] if owners else None;
}

def:priv find_day_info(date: str) -> DayInfo | None {
    for d in [root -->][?:DayInfo] {
        if d.date == date {
            return d;
        }
    }
    return None;
}

def:priv planned_seconds(t: Task) -> float {
    return float(duration_minutes(t.planned_start, t.planned_end) * 60);
}

def:priv task_elapsed(t: Task, now: float) -> float {
    return elapsed_seconds(
        t.total_elapsed, t.timer_status, t.timer_started_at, planned_seconds(t), now
    );
}

"""Bank the current run into total_elapsed and log it as a StudySession."""
def:priv bank_run(t: Task, now: float) {
    if t.timer_status != RUNNING {
        return;
    }
    before = t.total_elapsed;
    after = task_elapsed(t, now);
    worked = after - before;
    if worked > 0 {
        root ++> StudySession(
            task_id=jid(t),
            task_title=t.title,
            date=t.date,
            started_at=t.timer_started_at,
            ended_at=now,
            seconds=worked
        );
    }
    t.total_elapsed = after;
    t.timer_started_at = 0.0;
}

"""Auto-finish a running timer once it reaches the planned duration."""
def:priv settle(t: Task, now: float) {
    if t.timer_status == RUNNING and is_finished(task_elapsed(t, now), planned_seconds(t)) {
        finish_at = t.timer_started_at + (planned_seconds(t) - t.total_elapsed) * 1000.0;
        bank_run(t, finish_at);
        t.timer_status = STOPPED;
        t.completed = True;
    }
}

def:priv settle_all(now: float) {
    for t in all_tasks() {
        settle(t, now);
    }
}

def:priv overlapping(date: str, start: int, end: int, ignore_id: str) -> Task | None {
    for t in all_tasks() {
        if t.date == date and jid(t) != ignore_id and start < t.planned_end and t.planned_start < end {
            return t;
        }
    }
    return None;
}

def:priv check_slot(date: str, start: int, end: int, ignore_id: str) -> str {
    err = validate_range(start, end);
    if err {
        return err;
    }
    clash = overlapping(date, start, end, ignore_id);
    if clash {
        return "That time overlaps \"" + clash.title + "\".";
    }
    return "";
}

def:priv task_view(t: Task) -> TaskView {
    cat = category_of(t);
    return TaskView(
        id=jid(t),
        title=t.title,
        category_id=jid(cat) if cat else "",
        category_name=cat.name if cat else "",
        color=cat.color if cat else "pink",
        date=t.date,
        planned_start=t.planned_start,
        planned_end=t.planned_end,
        duration=duration_minutes(t.planned_start, t.planned_end),
        time_label=minutes_to_label(t.planned_start) + " - " + minutes_to_label(t.planned_end),
        completed=t.completed,
        timer_status=t.timer_status,
        total_elapsed_time=t.total_elapsed,
        timer_started_at=t.timer_started_at,
        timer_paused_at=t.timer_paused_at
    );
}

def:priv category_view(c: Category) -> CategoryView {
    return CategoryView(id=jid(c), name=c.name, color=c.color);
}

def:priv build_day(date: str) -> PlannerDay {
    now = now_ms();
    settle_all(now);
    info = find_day_info(date);
    tasks = [task_view(t) for t in all_tasks() if t.date == date];
    tasks.sort(key=lambda (v: TaskView) -> int { return v.planned_start; });
    banked = 0.0;
    for s in [root -->][?:StudySession] {
        if s.date == date {
            banked += s.seconds;
        }
    }
    active = "";
    for t in all_tasks() {
        if t.timer_status == RUNNING {
            active = jid(t);
        }
    }
    return PlannerDay(
        date=date,
        goal=info.goal if info else "",
        note=info.note if info else "",
        categories=[category_view(c) for c in all_categories()],
        tasks=tasks,
        study_seconds=banked,
        active_task_id=active,
        server_now=now
    );
}

# ---------------------------------------------------------------------------
# Public endpoints: day
# ---------------------------------------------------------------------------

"""Everything a client needs to draw one planner day. "" means today."""
def:pub get_day(date: str = "") -> PlannerDay {
    return build_day(resolve_date(date));
}

def:pub today_date -> str {
    return planner_today();
}

def:pub save_day_info(date: str, goal: str, note: str) -> ActionResult {
    d = resolve_date(date);
    info = find_day_info(d);
    if info {
        info.goal = goal;
        info.note = note;
    } else {
        root ++> DayInfo(date=d, goal=goal, note=note);
    }
    return ok();
}

# ---------------------------------------------------------------------------
# Public endpoints: categories
# ---------------------------------------------------------------------------

def:priv clean_category(name: str, color: str, ignore_id: str) -> str {
    if not name.strip() {
        return "Category name cannot be empty.";
    }
    if color not in CATEGORY_COLORS {
        return "Unknown color: " + color;
    }
    for c in all_categories() {
        if jid(c) != ignore_id and c.name.strip().lower() == name.strip().lower() {
            return "Category name already exists.";
        }
    }
    return "";
}

def:pub add_category(name: str, color: str = "pink") -> ActionResult {
    err = clean_category(name, color, "");
    if err {
        return fail(err);
    }
    cat = (root ++> Category(name=name.strip(), color=color)) as Category;
    return ok(jid(cat));
}

def:pub update_category(id: str, name: str, color: str) -> ActionResult {
    cat = find_category(id);
    if not cat {
        return fail("Category not found.");
    }
    err = clean_category(name, color, id);
    if err {
        return fail(err);
    }
    cat.name = name.strip();
    cat.color = color;
    return ok(id);
}

"""Deletes the category and every task in it. Logged study time is kept."""
def:pub delete_category(id: str) -> ActionResult {
    cat = find_category(id);
    if not cat {
        return fail("Category not found.");
    }
    now = now_ms();
    for t in [cat -->][?:Task] {
        bank_run(t, now);
        del t;
    }
    del cat;
    return ok(id);
}

# ---------------------------------------------------------------------------
# Public endpoints: tasks
# ---------------------------------------------------------------------------

def:pub add_task(
    category_id: str,
    title: str,
    planned_start: int,
    planned_end: int,
    date: str = ""
) -> ActionResult {
    cat = find_category(category_id);
    if not cat {
        return fail("Pick a category first.");
    }
    if not title.strip() {
        return fail("Title cannot be empty.");
    }
    d = resolve_date(date);
    err = check_slot(d, planned_start, planned_end, "");
    if err {
        return fail(err);
    }
    made = (cat ++> Task(
        title=title.strip(), date=d, planned_start=planned_start, planned_end=planned_end
    )) as Task;
    return ok(jid(made));
}

"""Same as add_task, but takes 24h clock strings ("09:00", "23:30").

Lets thin clients (phone, terminal) skip planner-minute math entirely.
"""
def:pub add_task_at_times(
    category_id: str, title: str, start: str, end: str, date: str = ""
) -> ActionResult {
    s = -1;
    e = -1;
    try {
        s = time_to_minutes(start.strip());
        e = end_time_to_minutes(end.strip());
    } except ValueError {
        return fail("Times look like 09:00 (24-hour clock).");
    }
    if s < 0 or e < 0 {
        return fail("Times look like 09:00 (24-hour clock).");
    }
    return add_task(category_id, title, s, e, date);
}

def:pub update_task(
    id: str, title: str, planned_start: int, planned_end: int
) -> ActionResult {
    t = find_task(id);
    if not t {
        return fail("Task not found.");
    }
    if not title.strip() {
        return fail("Title cannot be empty.");
    }
    err = check_slot(t.date, planned_start, planned_end, id);
    if err {
        return fail(err);
    }
    now = now_ms();
    settle(t, now);
    t.title = title.strip();
    t.planned_start = planned_start;
    t.planned_end = planned_end;
    # A shorter block may now be fully worked.
    if t.timer_status != RUNNING and t.total_elapsed >= planned_seconds(t) {
        t.total_elapsed = planned_seconds(t);
        t.completed = True;
    }
    settle(t, now);
    return ok(id);
}

def:pub delete_task(id: str) -> ActionResult {
    t = find_task(id);
    if not t {
        return fail("Task not found.");
    }
    bank_run(t, now_ms());
    del t;
    return ok(id);
}

"""Explicitly mark a task done (or not done). Stops its timer if running."""
def:pub set_completed(id: str, completed: bool = True) -> ActionResult {
    t = find_task(id);
    if not t {
        return fail("Task not found.");
    }
    now = now_ms();
    settle(t, now);
    if t.timer_status == RUNNING {
        bank_run(t, now);
        t.timer_status = STOPPED;
    }
    t.completed = completed;
    return ok(id);
}

# ---------------------------------------------------------------------------
# Public endpoints: study timer
# ---------------------------------------------------------------------------

"""Start or resume a task's timer. Only one timer runs at a time."""
def:pub start_timer(id: str) -> ActionResult {
    t = find_task(id);
    if not t {
        return fail("Task not found.");
    }
    now = now_ms();
    settle(t, now);
    if t.completed {
        return fail("\"" + t.title + "\" is already completed.");
    }
    if t.timer_status == RUNNING {
        return ok(id);
    }
    for other in all_tasks() {
        if other.timer_status == RUNNING {
            settle(other, now);
            if other.timer_status == RUNNING {
                bank_run(other, now);
                other.timer_status = PAUSED;
                other.timer_paused_at = now;
            }
        }
    }
    t.timer_status = RUNNING;
    t.timer_started_at = now;
    t.timer_paused_at = 0.0;
    return ok(id);
}

def:pub pause_timer(id: str) -> ActionResult {
    t = find_task(id);
    if not t {
        return fail("Task not found.");
    }
    now = now_ms();
    settle(t, now);
    if t.timer_status != RUNNING {
        return fail("Timer is not running.");
    }
    bank_run(t, now);
    t.timer_status = PAUSED;
    t.timer_paused_at = now;
    return ok(id);
}

"""Stop early: keep the worked time but do NOT mark the task completed."""
def:pub stop_timer(id: str) -> ActionResult {
    t = find_task(id);
    if not t {
        return fail("Task not found.");
    }
    now = now_ms();
    settle(t, now);
    if t.timer_status == RUNNING {
        bank_run(t, now);
    }
    if t.timer_status in [RUNNING, PAUSED] {
        t.timer_status = STOPPED;
        t.timer_paused_at = 0.0;
    }
    return ok(id);
}

"""Called by a client when its local countdown hits zero; the server re-checks."""
def:pub finish_timer(id: str) -> ActionResult {
    t = find_task(id);
    if not t {
        return fail("Task not found.");
    }
    settle(t, now_ms());
    return ok(id);
}

"""Convenience for quick clients: running -> paused, otherwise -> running."""
def:pub toggle_timer(id: str) -> ActionResult {
    t = find_task(id);
    if not t {
        return fail("Task not found.");
    }
    settle(t, now_ms());
    if t.timer_status == RUNNING {
        return pause_timer(id);
    }
    return start_timer(id);
}
