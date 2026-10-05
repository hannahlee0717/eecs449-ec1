"""Display formatting for timers and study hours (no server references, so
every client - web, phone, terminal - can bundle it as-is)."""

def remaining_seconds(elapsed: float, planned_seconds: float) -> float {
    return max(0.0, planned_seconds - elapsed);
}

"""Seconds -> "MM:SS", or "H:MM:SS" once past an hour."""
def format_clock(seconds: float) -> str {
    total = int(seconds);
    h = int(total / 3600);
    m = int((total % 3600) / 60);
    s = total % 60;
    mm = ("0" + str(m)) if m < 10 else str(m);
    ss = ("0" + str(s)) if s < 10 else str(s);
    return (str(h) + ":" + mm + ":" + ss) if h > 0 else (mm + ":" + ss);
}

"""Seconds -> "HH:MM" for the Study Hours counter."""
def format_hours(seconds: float) -> str {
    total_min = int(seconds / 60);
    h = int(total_min / 60);
    m = total_min % 60;
    hh = ("0" + str(h)) if h < 10 else str(h);
    mm = ("0" + str(m)) if m < 10 else str(m);
    return hh + ":" + mm;
}
