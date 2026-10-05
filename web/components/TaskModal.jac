"""Add Task and Edit Task share this one modal (mode="add" | "edit").

Both show the same title / start / end / duration form so there is only one
interface to learn; edit mode adds Delete (with confirmation).
"""

import from .Modal { Modal, ErrorText }
import from .DeleteConfirmation { DeleteConfirmation }
import from ..context.PlannerContext { usePlanner }
import from ...core.planner { TaskView, CategoryView }
import from ...core.utils.time_utils {
    minutes_to_time,
    time_to_minutes,
    end_time_to_minutes,
    validate_range
}
import from ...core.utils.palette { swatch }

def:pub TaskModal(
    mode: str,
    categories: list[CategoryView],
    onClose: Callable[[], None],
    task: TaskView | None = None,
    categoryId: str = "",
    initialStart: int = 240,
    initialEnd: int = 300
) -> JsxElement {
    ctx: any = usePlanner();
    has title: str = task.title if task else "",
        startTime: str = minutes_to_time(task.planned_start if task else initialStart),
        endTime: str = minutes_to_time(task.planned_end if task else initialEnd),
        catId: str = categoryId or (categories[0].id if len(categories) > 0 else ""),
        error: str = "",
        saving: bool = False,
        confirmDelete: bool = False;

    start = time_to_minutes(startTime);
    end = end_time_to_minutes(endTime);
    duration = end - start;
    rangeError = validate_range(start, end);
    canSave = bool(title.strip()) and not rangeError and bool(catId) and not saving;

    async def handle_save(e: FormEvent) {
        e.preventDefault();
        if not title.strip() {
            error = "Title cannot be empty.";
            return;
        }
        if rangeError {
            error = rangeError;
            return;
        }
        saving = True;
        msg = "";
        if task {
            msg = await ctx.updateTask(task.id, title, start, end);
        } else {
            msg = await ctx.addTask(catId, title, start, end);
        }
        saving = False;
        if msg {
            error = msg;
        } else {
            onClose();
        }
    }

    async def handle_delete {
        if task {
            await ctx.deleteTask(task.id);
        }
        confirmDelete = False;
        onClose();
    }

    if confirmDelete and task {
        return
            <DeleteConfirmation
                title="Delete task?"
                message={"\"" + task.title + "\" will be removed from the timetable.\nStudy time already logged stays counted."}
                onConfirm={handle_delete}
                onCancel={lambda { confirmDelete = False; }}
            />;
    }

    return
        <Modal title={"Edit Task" if mode == "edit" else "Add Task"} onClose={onClose}>
            <form onSubmit={handle_save}>
                <div className="mb-4">
                    <label className="block text-xs text-gray-400 mb-1">Task Title</label>
                    <input
                        className="w-full px-2 py-1 rounded border border-gray-200 bg-gray-50 text-sm"
                        placeholder="Enter task title"
                        value={title}
                        autoFocus={True}
                        onChange={lambda (e: ChangeEvent) { title = e.target.value; error = ""; }}
                    />
                </div>
                {if task {
                    <div className="mb-4 flex items-center gap-2 text-xs text-gray-400">
                        Category
                        <span
                            className="rounded px-2 py-0.5 font-semibold"
                            style={{"backgroundColor": swatch(task.color).chip, "color": swatch(task.color).ink}}
                        >
                            {task.category_name}
                        </span>
                    </div>
                } else {
                    <div className="mb-4">
                        <label className="block text-xs text-gray-400 mb-1">Category</label>
                        <div className="flex flex-wrap gap-1">
                            {for c in categories {
                                <button
                                    key={c.id}
                                    type="button"
                                    className={"text-xs rounded px-2 py-0.5 font-semibold border " + ("border-pink-400 ring-2 ring-pink-200" if c.id == catId else "border-transparent opacity-70")}
                                    style={{"backgroundColor": swatch(c.color).chip, "color": swatch(c.color).ink}}
                                    onClick={lambda (_e: MouseEvent) { catId = c.id; }}
                                >
                                    {c.name}
                                </button>
                            }}
                        </div>
                    </div>
                }}
                <div className="mb-4">
                    <label className="block text-xs text-gray-400 mb-1">Work Time</label>
                    <div className="flex gap-2 items-center">
                        <input
                            type="time"
                            aria-label="Start time"
                            step="600"
                            value={startTime}
                            className="px-2 py-1 rounded border text-sm"
                            onChange={lambda (e: ChangeEvent) { startTime = e.target.value; error = ""; }}
                        />
                        <span className="text-gray-400">to</span>
                        <input
                            type="time"
                            aria-label="End time"
                            step="600"
                            value={endTime}
                            className="px-2 py-1 rounded border text-sm"
                            onChange={lambda (e: ChangeEvent) { endTime = e.target.value; error = ""; }}
                        />
                    </div>
                    <div className={"text-xs mt-1 " + ("text-red-400" if rangeError else "text-gray-500")}>
                        {rangeError if rangeError else "Duration: " + str(duration) + " minutes"}
                    </div>
                </div>
                <ErrorText message={error}/>
                {if mode == "edit" {
                    <div className="flex justify-between gap-2">
                        <button
                            type="button"
                            className="flex-1 px-3 py-1 text-sm rounded bg-red-100 hover:bg-red-200 text-red-700 font-semibold"
                            onClick={lambda (_e: MouseEvent) { confirmDelete = True; }}
                        >
                            Delete
                        </button>
                        <button
                            type="button"
                            className="flex-1 px-3 py-1 text-sm rounded bg-gray-200 hover:bg-gray-300"
                            onClick={lambda (_e: MouseEvent) { onClose(); }}
                        >
                            Cancel
                        </button>
                        <button
                            type="submit"
                            disabled={not canSave}
                            className="flex-1 px-3 py-1 text-sm rounded bg-pink-100 hover:bg-pink-200 text-pink-700 font-semibold disabled:opacity-50"
                        >
                            Save
                        </button>
                    </div>
                } else {
                    <button
                        type="submit"
                        disabled={not canSave}
                        className="w-full bg-pink-100 text-pink-700 py-1.5 rounded font-semibold mt-2 hover:bg-pink-200 disabled:opacity-50"
                    >
                        DONE
                    </button>
                }}
            </form>
        </Modal>;
}
