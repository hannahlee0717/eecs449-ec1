"""One task drawn over the timetable grid.

The grid is one row per hour and six 10-minute columns, so a task that crosses
an hour boundary is drawn as one segment per row it touches. Each segment is
tinted with the category's light "planned" color, and the worked part (from
the timer, not the schedule) is filled with the stronger "worked" color, so a
task worked 8:00-8:45 of 8:00-10:00 shows exactly that much filled.
"""

import from ...core.planner { TaskView }
import from ...core.utils.time_utils { minutes_to_label }
import from ...core.utils.task_math { task_progress }
import from ...core.utils.palette { swatch }

obj Segment {
    has row: int,
        start: int,
        end: int;
}

"""Split [start, end) into per-hour-row pieces."""
def row_segments(start: int, end: int) -> list[Segment] {
    out: list[Segment] = [];
    row = int(start / 60);
    while row * 60 < end {
        a = max(start, row * 60);
        b = min(end, (row + 1) * 60);
        if b > a {
            out.append(Segment(row=row, start=a, end=b));
        }
        row += 1;
    }
    return out;
}

def pct(x: float) -> str {
    return str(round(x * 1000) / 10) + "%";
}

def:pub TaskBlock(
    task: TaskView,
    now: float,
    rowHeight: int,
    dragging: bool,
    onOpen: Callable[[TaskView], None]
) -> JsxElement {
    colors = swatch(task.color);
    segments = row_segments(task.planned_start, task.planned_end);
    worked_end = task.planned_start + task_progress(task, now) * task.duration;
    running = task.timer_status == "running";
    label = minutes_to_label(task.planned_start) + " - " + minutes_to_label(task.planned_end);

    def handle_click(e: MouseEvent) {
        e.stopPropagation();
        onOpen(task);
    }

    return
        <>
            {for (i, seg) in enumerate(segments) {
                filled = min(1.0, max(0.0, (worked_end - seg.start) / (seg.end - seg.start)));
                <div
                    key={task.id + "-" + str(i)}
                    role="button"
                    title={task.title + " · " + label}
                    onMouseDown={lambda (e: MouseEvent) { e.stopPropagation(); }}
                    onClick={handle_click}
                    className={"absolute rounded-sm overflow-hidden cursor-pointer border hover:brightness-95 "
                        + ("pointer-events-none " if dragging else "")
                        + ("ring-2 ring-pink-300 animate-pulse " if running else "")}
                    style={{
                        "top": str(seg.row * rowHeight + 1) + "px",
                        "height": str(rowHeight - 2) + "px",
                        "left": pct((seg.start - seg.row * 60) / 60),
                        "width": pct((seg.end - seg.start) / 60),
                        "backgroundColor": colors.planned,
                        "borderColor": colors.worked
                    }}
                >
                    <div
                        className="absolute inset-y-0 left-0"
                        style={{"width": pct(filled), "backgroundColor": colors.worked}}
                    />
                    {if i == 0 {
                        <div className="relative px-1 flex items-center gap-1 h-full text-[10px] leading-none text-gray-800 whitespace-nowrap">
                            <span className="font-semibold truncate">
                                {("✓ " if task.completed else "") + task.title}
                            </span>
                            {if seg.end - seg.start >= 40 {
                                <span className="text-gray-500 truncate">{label}</span>
                            }}
                        </div>
                    }}
                </div>
            }}
        </>;
}
