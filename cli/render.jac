"""Turns planner views into terminal text. Pure functions, no I/O."""

import time;
import from core.planner { PlannerDay, TaskView, CategoryView }
import from core.utils.clock_format { format_clock, format_hours }
import from core.utils.task_math { task_elapsed, live_study_seconds }

glob COLOR_DOT: dict[str, str] = {
         "yellow": "🟨",
         "pink": "🩷",
         "green": "🟩",
         "blue": "🟦",
         "purple": "🟪",
         "orange": "🟧"
     };

def now_ms -> float {
    return time.time() * 1000.0;
}

def status_mark(t: TaskView) -> str {
    if t.completed {
        return "✅";
    }
    if t.timer_status == "running" {
        return "⏱ ";
    }
    if t.timer_status == "paused" {
        return "⏸ ";
    }
    if t.timer_status == "stopped" {
        return "⏹ ";
    }
    return "⬜";
}

def render_task_line(index: int, t: TaskView, now: float = 0.0) -> str {
    now = now if now > 0 else now_ms();
    worked = task_elapsed(t, now);
    when = t.time_label;
    dot = COLOR_DOT.get(t.color, "•");
    line = (
        f"{index:>2}. {status_mark(t)} {when:<20} {dot} {t.title}"
        + f"  [{t.category_name}]"
    );
    if worked > 0 or t.timer_status != "idle" {
        line += f"  {format_clock(worked)} / {t.duration}m";
    }
    if t.timer_status == "running" {
        line += "  (running)";
    }
    return line;
}

def render_day(day: PlannerDay) -> str {
    now = now_ms();
    lines: list[str] = [f"🐰 Stunny · {day.date}"];
    if day.goal {
        lines.append(f"   Goal: {day.goal}");
    }
    lines.append(f"   Study hours: {format_hours(live_study_seconds(day, now))}");
    lines.append("");
    if not day.tasks {
        lines.append("   No tasks planned. Add one with:");
        lines.append('   stunny add "Read spec" --category "EECS 449" --start 09:00 --end 10:00');
    }
    for (i, t) in enumerate(day.tasks) {
        lines.append(render_task_line(i + 1, t, now));
    }
    if day.note {
        lines.append("");
        lines.append(f"   Note: {day.note}");
    }
    return "\n".join(lines);
}

def render_categories(cats: list[CategoryView]) -> str {
    if not cats {
        return 'No categories yet. Add one with: stunny category add "EECS 449" --color pink';
    }
    return "\n".join([f"{COLOR_DOT.get(c.color, '•')} {c.name}  ({c.color})" for c in cats]);
}
