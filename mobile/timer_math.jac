"""Live timer math for the phone.

Same formula as core/utils/timer_utils.jac and core/utils/task_math.jac
(elapsed = banked + (now - started_at) / 1000, capped at the planned length).
It lives here because the jac 0.37 mobile bundler refuses helper modules that
server code also imports, so the phone keeps its own dependency-free copy.
"""

import from ..core.planner { PlannerDay, TaskView }

def planned_seconds_of(t: TaskView) -> float {
    return float(t.duration * 60);
}

def run_seconds(t: TaskView, now: float) -> float {
    if t.timer_status != "running" or t.timer_started_at <= 0 {
        return 0.0;
    }
    return max(0.0, (now - t.timer_started_at) / 1000.0);
}

def task_elapsed(t: TaskView, now: float) -> float {
    return min(t.total_elapsed_time + run_seconds(t, now), planned_seconds_of(t));
}

def live_study_seconds(day: PlannerDay, now: float) -> float {
    live = 0.0;
    for t in day.tasks {
        room = max(0.0, planned_seconds_of(t) - t.total_elapsed_time);
        live += min(run_seconds(t, now), room);
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
