"""The Study Planner card: date + goal, timetable, study hours + note, and the
category / task list. It owns only UI state (which modal is open); all
planner data comes from PlannerContext."""

import from .Timetable { Timetable }
import from .TaskModal { TaskModal }
import from .CategoryModal { CategoryModal }
import from ..context.PlannerContext { usePlanner }
import from ...core.planner { PlannerDay, TaskView, CategoryView }
import from ...core.utils.time_utils { minutes_to_label }
import from ...core.utils.clock_format { format_hours }
import from ...core.utils.task_math { live_study_seconds }
import from ...core.utils.palette { swatch }

def display_date(key: str) -> str {
    if not key {
        return "";
    }
    d = new(Date, key + "T12:00:00");
    return d.toLocaleDateString(
        "en-US", {"weekday": "short", "year": "numeric", "month": "short", "day": "numeric"}
    );
}

def task_icon(t: TaskView) -> str {
    if t.completed {
        return "🥕";
    }
    if t.timer_status == "running" {
        return "⏱️";
    }
    return "🐰";
}

def:pub Sidebar -> JsxElement {
    ctx: any = usePlanner();
    day: PlannerDay | None = ctx.day;
    now: float = ctx.now;
    has goal: str = "",
        note: str = "",
        taskModal: str = "",
        modalTask: TaskView | None = None,
        modalCategoryId: str = "",
        modalStart: int = 240,
        modalEnd: int = 300,
        categoryModal: str = "",
        modalCategory: CategoryView | None = None,
        hint: str = "";

    # Load the goal/note drafts whenever a different day arrives, but never
    # overwrite them while the user is typing on the same day.
    dayKey = day.date if day else "";
    can with [dayKey] entry {
        if day {
            goal = day.goal;
            note = day.note;
        }
    }

    categories: list[CategoryView] = day.categories if day else [];
    tasks: list[TaskView] = day.tasks if day else [];
    studied = live_study_seconds(day, now) if day else 0.0;

    def save_info {
        if day and (goal != day.goal or note != day.note) {
            ctx.saveDayInfo(goal, note);
        }
    }

    def open_add(catId: str, start: int, end: int) {
        if len(categories) == 0 {
            hint = "Create a category first, then add tasks to it.";
            categoryModal = "add";
            return;
        }
        hint = "";
        modalTask = None;
        modalCategoryId = catId;
        modalStart = start;
        modalEnd = end;
        taskModal = "add";
    }

    def open_edit(t: TaskView) {
        modalTask = t;
        taskModal = "edit";
    }

    def open_category(c: CategoryView | None) {
        modalCategory = c;
        categoryModal = "edit" if c else "add";
    }

    return
        <aside className="bg-white rounded-2xl shadow p-6 flex flex-col border-[6px] border-pink-100 w-full">
            <h2 className="text-lg font-semibold text-center mb-4">Study Planner</h2>
            <div className="flex gap-2 mb-4">
                <div className="flex items-center w-1/2 bg-gray-100 rounded border border-gray-200">
                    <button
                        type="button"
                        aria-label="Previous day"
                        className="px-2 text-gray-400 hover:text-pink-500"
                        onClick={lambda (_e: MouseEvent) { ctx.shiftDate(-1); }}
                    >
                        ‹
                    </button>
                    <span data-testid="planner-date" className="flex-1 text-center text-sm font-medium py-1">
                        {display_date(ctx.dateKey)}
                    </span>
                    <button
                        type="button"
                        aria-label="Next day"
                        className="px-2 text-gray-400 hover:text-pink-500"
                        onClick={lambda (_e: MouseEvent) { ctx.shiftDate(1); }}
                    >
                        ›
                    </button>
                </div>
                <input
                    type="text"
                    aria-label="Goal"
                    className="bg-white rounded px-3 py-1 w-1/2 text-sm border-2 border-gray-200 focus:border-pink-300 outline-none"
                    placeholder="Goal"
                    value={goal}
                    onChange={lambda (e: ChangeEvent) { goal = e.target.value; }}
                    onBlur={lambda (_e: FocusEvent) { save_info(); }}
                />
            </div>

            <Timetable
                tasks={tasks}
                now={now}
                onSelectRange={lambda (s: int, e: int) { open_add("", s, e); }}
                onOpenTask={open_edit}
            />
            <p className="text-[10px] text-gray-300 mt-1 mb-4">
                Drag across empty cells to plan a block · click a block to edit it
            </p>

            <div className="flex gap-3 mb-4 border-t border-b border-gray-100 py-3">
                <div className="w-1/3">
                    <div className="text-xs text-gray-400">Study Hours</div>
                    <div data-testid="study-hours" className="font-mono text-xl">{format_hours(studied)}</div>
                    <div className="text-[10px] text-gray-300">hr : min actually studied</div>
                </div>
                <div className="flex-1">
                    <div className="text-xs text-gray-400">Note</div>
                    <textarea
                        aria-label="Note"
                        className="w-full bg-gray-100 rounded px-2 py-1 text-xs border border-gray-200 resize-none"
                        rows={3}
                        value={note}
                        onChange={lambda (e: ChangeEvent) { note = e.target.value; }}
                        onBlur={lambda (_e: FocusEvent) { save_info(); }}
                    />
                </div>
            </div>

            <div className="mb-2 flex items-center justify-between">
                <span className="text-xs text-gray-400">{hint}</span>
                <button
                    type="button"
                    className="text-xs bg-pink-100 text-pink-700 px-3 py-1 rounded font-semibold shadow hover:bg-pink-200"
                    onClick={lambda (_e: MouseEvent) { open_category(None); }}
                >
                    ＋ Add Category
                </button>
            </div>

            <div className="flex-1 overflow-y-auto">
                {if len(categories) == 0 {
                    <div className="text-xs text-gray-300">No categories yet</div>
                }}
                {for c in categories {
                    catTasks = [t for t in tasks if t.category_id == c.id];
                    <div key={c.id} className="mb-3">
                        <div className="flex items-center gap-2 mb-1">
                            <button
                                type="button"
                                title="Edit or delete category"
                                className="text-xs rounded px-2 py-0.5 font-semibold hover:opacity-80"
                                style={{"backgroundColor": swatch(c.color).chip, "color": swatch(c.color).ink}}
                                onClick={lambda (_e: MouseEvent) { open_category(c); }}
                            >
                                {c.name}
                            </button>
                            <button
                                type="button"
                                aria-label={"Add task to " + c.name}
                                className="w-5 h-5 rounded-full bg-gray-100 text-gray-500 hover:text-pink-500 text-sm leading-none"
                                onClick={lambda (_e: MouseEvent) { open_add(c.id, 240, 300); }}
                            >
                                +
                            </button>
                        </div>
                        <ul className="ml-6">
                            {if len(catTasks) == 0 {
                                <li className="text-xs text-gray-300">No tasks</li>
                            }}
                            {for t in catTasks {
                                <li key={t.id} className="flex items-center gap-2 mb-1 group">
                                    <span className="text-base">{task_icon(t)}</span>
                                    <button
                                        type="button"
                                        className={"text-sm text-left hover:text-pink-600 " + ("line-through text-gray-400" if t.completed else "")}
                                        onClick={lambda (_e: MouseEvent) { open_edit(t); }}
                                    >
                                        {t.title}
                                    </button>
                                    <span className="text-[11px] text-gray-400">
                                        {minutes_to_label(t.planned_start) + " - " + minutes_to_label(t.planned_end)}
                                    </span>
                                    <button
                                        type="button"
                                        title="Focus this task in the timer"
                                        className="ml-auto text-[11px] text-pink-400 opacity-0 group-hover:opacity-100"
                                        onClick={lambda (_e: MouseEvent) { ctx.selectTask(t.id); }}
                                    >
                                        timer ›
                                    </button>
                                </li>
                            }}
                        </ul>
                    </div>
                }}
            </div>

            {if taskModal {
                <TaskModal
                    mode={taskModal}
                    categories={categories}
                    task={modalTask}
                    categoryId={modalCategoryId}
                    initialStart={modalStart}
                    initialEnd={modalEnd}
                    onClose={lambda { taskModal = ""; }}
                />
            }}
            {if categoryModal {
                <CategoryModal
                    category={modalCategory}
                    onClose={lambda { categoryModal = ""; }}
                />
            }}
        </aside>;
}
