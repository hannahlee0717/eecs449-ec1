"""Live timer math on the TaskView objects every client receives."""

import from core.planner { PlannerDay, TaskView }
import from core.utils.timer_utils {
    elapsed_seconds,
    current_run_seconds,
    progress_fraction
}

def planned_seconds_of(t: TaskView) -> float {
    return float(t.duration * 60);
}

"""Worked seconds right now, derived from timestamps (never a counter)."""
def task_elapsed(t: TaskView, now: float) -> float {
    return elapsed_seconds(
        t.total_elapsed_time,
        t.timer_status,
        t.timer_started_at,
        planned_seconds_of(t),
        now
    );
}

def task_progress(t: TaskView, now: float) -> float {
    return 1.0 if t.completed else progress_fraction(task_elapsed(t, now), planned_seconds_of(t));
}

"""Banked study seconds for the day plus whatever the running timer adds."""
def live_study_seconds(day: PlannerDay, now: float) -> float {
    live = 0.0;
    for t in day.tasks {
        if t.timer_status == "running" {
            run = current_run_seconds(t.timer_status, t.timer_started_at, now);
            room = planned_seconds_of(t) - t.total_elapsed_time;
            live += min(run, max(0.0, room));
        }
    }
    return day.study_seconds + live;
}

def find_task_view(day: PlannerDay | None, id: str) -> TaskView | None {
    if not day or not id {
        return None;
    }
    for t in day.tasks {
        if t.id == id {
            return t;
        }
    }
    return None;
}
