"""Pure time helpers shared by the server, web, mobile and CLI.

Planner time is measured in minutes from the start of the planner day
(4:00 AM), so 0 = 4:00 AM and 1440 = 4:00 AM the next morning. That keeps a
late-night block such as 11 PM - 1 AM a simple increasing range.
"""

glob DAY_START_HOUR: int = 4,
     SLOT_MINUTES: int = 10,
     DAY_MINUTES: int = 1440,
     SLOTS_PER_HOUR: int = 6,
     HOURS_PER_DAY: int = 24;

"""Planner minutes -> 24h clock string, e.g. 240 -> "08:00"."""
def minutes_to_time(planner_min: int) -> str {
    clock = (planner_min + DAY_START_HOUR * 60) % DAY_MINUTES;
    hh = int(clock / 60);
    mm = clock % 60;
    return pad2(hh) + ":" + pad2(mm);
}

"""24h clock string -> planner minutes, e.g. "08:00" -> 240, "01:00" -> 1260."""
def time_to_minutes(clock: str) -> int {
    parts = clock.split(":");
    if len(parts) < 2 {
        return -1;
    }
    hh = int(parts[0]);
    mm = int(parts[1]);
    return ((hh * 60 + mm) - DAY_START_HOUR * 60 + DAY_MINUTES) % DAY_MINUTES;
}

"""Like time_to_minutes, but "04:00" as an END time means the end of the day."""
def end_time_to_minutes(clock: str) -> int {
    m = time_to_minutes(clock);
    return DAY_MINUTES if m == 0 else m;
}

"""Planner minutes -> friendly label, e.g. 240 -> "8:00 AM"."""
def minutes_to_label(planner_min: int) -> str {
    clock = (planner_min + DAY_START_HOUR * 60) % DAY_MINUTES;
    hh = int(clock / 60);
    mm = clock % 60;
    suffix = "AM" if hh < 12 else "PM";
    h12 = hh % 12;
    h12 = 12 if h12 == 0 else h12;
    return str(h12) + ":" + pad2(mm) + " " + suffix;
}

"""Hour-row label for the timetable, e.g. row 0 -> "04 am"."""
def hour_row_label(row: int) -> str {
    hh = (row + DAY_START_HOUR) % 24;
    h12 = hh % 12;
    h12 = 12 if h12 == 0 else h12;
    return pad2(h12) + (" am" if hh < 12 else " pm");
}

def duration_minutes(start: int, end: int) -> int {
    return end - start;
}

"""Error message for a planned range, or "" when it is valid."""
def validate_range(start: int, end: int) -> str {
    if start < 0 or end > DAY_MINUTES {
        return "Times must fall inside the planner day (4:00 AM - 4:00 AM).";
    }
    if end <= start {
        return "End time must be after start time.";
    }
    if duration_minutes(start, end) <= 0 {
        return "Duration must be greater than zero.";
    }
    return "";
}

"""Round planner minutes down to the 10-minute slot grid."""
def snap_to_slot(planner_min: int) -> int {
    return int(planner_min / SLOT_MINUTES) * SLOT_MINUTES;
}

"""Indices of the 10-minute cells a block covers (its "timeBlocks")."""
def time_blocks(start: int, end: int) -> list[int] {
    first = int(start / SLOT_MINUTES);
    last = int((end - 1) / SLOT_MINUTES);
    return [i for i in range(first, last + 1)];
}

def pad2(n: int) -> str {
    return ("0" + str(n)) if n < 10 else str(n);
}
