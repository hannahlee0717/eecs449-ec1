"""4 AM - 4 AM timetable: 24 hour rows x six 10-minute cells.

Cells hold no state of their own. The only drag state is two cell indices
(where the drag began and where the pointer is now); every highlighted cell is
derived from them. Releasing the mouse hands the selected range to the parent,
which opens the Add Task modal pre-filled with those times.
"""

import from .TaskBlock { TaskBlock }
import from ...core.planner { TaskView }
import from ...core.utils.time_utils {
    HOURS_PER_DAY,
    SLOTS_PER_HOUR,
    SLOT_MINUTES,
    hour_row_label
}

glob ROW_HEIGHT: int = 24,
     SLOT_LABELS: list[str] = ["0", "10", "20", "30", "40", "50"];

def:pub Timetable(
    tasks: list[TaskView],
    now: float,
    onSelectRange: Callable[[int, int], None],
    onOpenTask: Callable[[TaskView], None]
) -> JsxElement {
    has dragFrom: int = -1,
        dragTo: int = -1;

    dragging = dragFrom >= 0;
    lo = min(dragFrom, dragTo);
    hi = max(dragFrom, dragTo);
    cells = [i for i in range(HOURS_PER_DAY * SLOTS_PER_HOUR)];
    rows = [r for r in range(HOURS_PER_DAY)];

    def begin(cell: int, e: MouseEvent) {
        if e.button != 0 {
            return;
        }
        e.preventDefault();
        dragFrom = cell;
        dragTo = cell;
    }

    def extend(cell: int) {
        if dragFrom >= 0 {
            dragTo = cell;
        }
    }

    def finish(e: MouseEvent) {
        if dragFrom < 0 {
            return;
        }
        start = lo * SLOT_MINUTES;
        end = (hi + 1) * SLOT_MINUTES;
        dragFrom = -1;
        dragTo = -1;
        onSelectRange(start, end);
    }

    return
        <div className="select-none">
            <div className="flex text-[10px] text-gray-300 mb-1">
                <div className="w-12 text-left text-gray-400">Time</div>
                <div className="flex-1 grid grid-cols-6">
                    {for s in SLOT_LABELS {
                        <div key={s} className="text-center">{s}</div>
                    }}
                </div>
            </div>
            <div className="flex">
                <div className="w-12">
                    {for r in rows {
                        <div
                            key={r}
                            className="text-[11px] text-gray-400 font-mono flex items-center"
                            style={{"height": str(ROW_HEIGHT) + "px"}}
                        >
                            {hour_row_label(r)}
                        </div>
                    }}
                </div>
                <div
                    data-testid="timetable-grid"
                    className="relative flex-1 cursor-crosshair"
                    onMouseUp={finish}
                    onMouseLeave={finish}
                >
                    <div className="grid grid-cols-6 border-t border-l border-gray-100">
                        {for i in cells {
                            selected = dragging and lo <= i and i <= hi;
                            <div
                                key={i}
                                data-cell={i}
                                className={"border-r border-b border-gray-100 "
                                    + ("bg-pink-200/70" if selected else "bg-gray-50 hover:bg-pink-50")}
                                style={{"height": str(ROW_HEIGHT) + "px"}}
                                onMouseDown={lambda (e: MouseEvent) { begin(i, e); }}
                                onMouseEnter={lambda (_e: MouseEvent) { extend(i); }}
                            />
                        }}
                    </div>
                    {for t in tasks {
                        <TaskBlock
                            key={t.id}
                            task={t}
                            now={now}
                            rowHeight={ROW_HEIGHT}
                            dragging={dragging}
                            onOpen={onOpenTask}
                        />
                    }}
                </div>
            </div>
        </div>;
}
