"""Pure study-timer math shared by the server, web, mobile and CLI.

The timer is never a counter. A task stores:
  total_elapsed     seconds banked from finished runs (pause / stop)
  timer_started_at  epoch ms when the current run began (0 when not running)
so the elapsed time at any instant is derived from a timestamp:
  elapsed = total_elapsed + (now - timer_started_at) / 1000
which stays correct across throttled tabs, sleeps, reloads and devices.
Every function takes `now_ms` explicitly so callers pass their own clock.
"""

glob RUNNING: str = "running",
     PAUSED: str = "paused",
     STOPPED: str = "stopped",
     IDLE: str = "idle";

"""Seconds in the current (unbanked) run."""
def current_run_seconds(status: str, started_at_ms: float, now_ms: float) -> float {
    if status != RUNNING or started_at_ms <= 0 {
        return 0.0;
    }
    return max(0.0, (now_ms - started_at_ms) / 1000.0);
}

"""Total worked seconds, capped at the planned duration."""
def elapsed_seconds(
    total_elapsed: float,
    status: str,
    started_at_ms: float,
    planned_seconds: float,
    now_ms: float
) -> float {
    raw = total_elapsed + current_run_seconds(status, started_at_ms, now_ms);
    return min(raw, planned_seconds) if planned_seconds > 0 else raw;
}

def is_finished(elapsed: float, planned_seconds: float) -> bool {
    return planned_seconds > 0 and elapsed >= planned_seconds;
}

"""Fraction (0..1) of the planned block that has actually been worked."""
def progress_fraction(elapsed: float, planned_seconds: float) -> float {
    if planned_seconds <= 0 {
        return 0.0;
    }
    return min(1.0, max(0.0, elapsed / planned_seconds));
}
