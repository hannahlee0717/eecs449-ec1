"""Study timer panel.

Display only: the remaining time is recomputed from server timestamps on every
1-second tick from PlannerContext (elapsed = banked + now - started_at), so a
throttled or backgrounded tab is exact again on its very next render.
Start / pause / stop are server calls; auto-finish lives in PlannerContext.
"""

import from ..context.PlannerContext { usePlanner }
import from ...core.planner { PlannerDay, TaskView }
import from ...core.utils.time_utils { minutes_to_label }
import from ...core.utils.clock_format { format_clock, remaining_seconds }
import from ...core.utils.task_math { task_elapsed, task_progress, planned_seconds_of }
import from ...core.utils.palette { swatch }

glob RING_SIZE: int = 320,
     RING_RADIUS: int = 140;

"""Point on the ring for a 0..1 progress, starting at 12 o'clock."""
def ring_point(fraction: float) -> list[float] {
    angle = fraction * 2 * Math.PI - Math.PI / 2;
    c = RING_SIZE / 2;
    return [c + RING_RADIUS * Math.cos(angle), c + RING_RADIUS * Math.sin(angle)];
}

def:pub Timer -> JsxElement {
    ctx: any = usePlanner();
    day: PlannerDay | None = ctx.day;
    task: TaskView | None = ctx.timerTask;
    now: float = ctx.now;
    has busy: bool = False,
        message: str = "";

    tasks: list[TaskView] = day.tasks if day else [];
    elapsed = task_elapsed(task, now) if task else 0.0;
    planned = planned_seconds_of(task) if task else 0.0;
    progress = task_progress(task, now) if task else 0.0;
    remaining = remaining_seconds(elapsed, planned);
    status = task.timer_status if task else "idle";
    running = status == "running";
    circumference = 2 * Math.PI * RING_RADIUS;
    carrot = ring_point(progress);

    def cycle(step: int) {
        if len(tasks) == 0 {
            return;
        }
        idx = 0;
        for (i, t) in enumerate(tasks) {
            if task and t.id == task.id {
                idx = i;
            }
        }
        ctx.selectTask(tasks[(idx + step + len(tasks)) % len(tasks)].id);
        message = "";
    }

    async def run(action: str) {
        if not task or busy {
            return;
        }
        busy = True;
        msg = "";
        if action == "start" {
            msg = await ctx.startTimer(task.id);
        } elif action == "pause" {
            msg = await ctx.pauseTimer(task.id);
        } elif action == "stop" {
            msg = await ctx.stopTimer(task.id);
        } elif action == "done" {
            msg = await ctx.setCompleted(task.id, True);
        } else {
            msg = await ctx.setCompleted(task.id, False);
        }
        message = msg;
        busy = False;
    }

    mainLabel = "PAUSE" if running else ("RESUME" if status in ["paused", "stopped"] and elapsed > 0 else "START");

    return
        <section className="bg-pink-50 rounded-2xl shadow p-6 flex flex-col items-center border-2 border-pink-100 w-full min-h-[640px] relative">
            <div className="absolute top-5 left-6 flex gap-1 text-gray-400 text-lg">
                <button type="button" aria-label="Previous task" className="hover:text-pink-500 px-1" onClick={lambda (_e: MouseEvent) { cycle(-1); }}>‹</button>
                <button type="button" aria-label="Next task" className="hover:text-pink-500 px-1" onClick={lambda (_e: MouseEvent) { cycle(1); }}>›</button>
            </div>

            <div className="relative mt-10" style={{"width": str(RING_SIZE) + "px", "height": str(RING_SIZE) + "px"}}>
                <svg width={RING_SIZE} height={RING_SIZE} viewBox={"0 0 " + str(RING_SIZE) + " " + str(RING_SIZE)}>
                    <circle cx={RING_SIZE / 2} cy={RING_SIZE / 2} r={RING_RADIUS} fill="none" stroke="#d4d4d4" strokeWidth="4"/>
                    <circle
                        cx={RING_SIZE / 2}
                        cy={RING_SIZE / 2}
                        r={RING_RADIUS - 5}
                        fill="none"
                        stroke="#bfdbfe"
                        strokeWidth="2"
                        strokeDasharray={str(2 * Math.PI * (RING_RADIUS - 5))}
                        strokeDashoffset={str(2 * Math.PI * (RING_RADIUS - 5) * (1 - progress))}
                        transform={"rotate(-90 " + str(RING_SIZE / 2) + " " + str(RING_SIZE / 2) + ")"}
                    />
                    <circle
                        cx={RING_SIZE / 2}
                        cy={RING_SIZE / 2}
                        r={RING_RADIUS}
                        fill="none"
                        stroke="#f9a8d4"
                        strokeWidth="5"
                        strokeLinecap="round"
                        strokeDasharray={str(circumference)}
                        strokeDashoffset={str(circumference * (1 - progress))}
                        transform={"rotate(-90 " + str(RING_SIZE / 2) + " " + str(RING_SIZE / 2) + ")"}
                    />
                </svg>
                <span className="absolute text-5xl" style={{"left": "50%", "top": "-6px", "transform": "translate(-50%, -50%)"}}>
                    {"🐰" if not running else "🐇"}
                </span>
                {if progress > 0 {
                    <span
                        className="absolute text-2xl"
                        style={{"left": str(carrot[0]) + "px", "top": str(carrot[1]) + "px", "transform": "translate(-50%, -50%)"}}
                    >
                        🥕
                    </span>
                }}
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                    <span data-testid="timer-display" className="text-6xl font-light tracking-wider text-pink-300 tabular-nums" style={{"textShadow": "0 2px 6px rgba(244,114,182,.35)"}}>
                        {format_clock(remaining) if task else "00:00"}
                    </span>
                    <span className="text-xs text-gray-400 mt-2">
                        {("worked " + format_clock(elapsed) + " of " + str(task.duration) + "m") if task else ""}
                    </span>
                </div>
            </div>

            {if task {
                <div className="mt-6 text-center">
                    <div data-testid="timer-task" className="font-semibold text-gray-700">
                        {("✓ " if task.completed else "") + task.title}
                    </div>
                    <div className="mt-1 flex items-center justify-center gap-2 text-xs text-gray-400">
                        <span className="rounded px-2 py-0.5 font-semibold" style={{"backgroundColor": swatch(task.color).chip, "color": swatch(task.color).ink}}>
                            {task.category_name}
                        </span>
                        {minutes_to_label(task.planned_start) + " - " + minutes_to_label(task.planned_end)}
                    </div>
                </div>
            } else {
                <div className="mt-6 text-sm text-gray-400 text-center">
                    Plan a task on the timetable to start studying.
                </div>
            }}

            {if task and task.completed {
                <div className="mt-6 flex flex-col items-center gap-2">
                    <div className="text-pink-500 font-semibold">Completed! 🥕</div>
                    <button type="button" className="text-xs text-gray-400 underline" onClick={lambda (_e: MouseEvent) { run("reopen"); }}>
                        reopen task
                    </button>
                </div>
            } elif task {
                <div className="mt-6 flex flex-col items-center gap-3">
                    <button
                        type="button"
                        disabled={busy}
                        className={"px-12 py-2 rounded-full font-semibold shadow text-lg tracking-wide disabled:opacity-60 "
                            + ("bg-yellow-50 text-gray-800 hover:bg-yellow-100" if running else "bg-pink-200 text-pink-800 hover:bg-pink-300")}
                        onClick={lambda (_e: MouseEvent) { run("pause" if running else "start"); }}
                    >
                        {mainLabel}
                    </button>
                    <div className="flex gap-3 text-xs">
                        <button
                            type="button"
                            disabled={busy or not (running or status == "paused")}
                            className="px-3 py-1 rounded-full bg-white text-gray-500 hover:text-pink-600 disabled:opacity-40"
                            onClick={lambda (_e: MouseEvent) { run("stop"); }}
                        >
                            ■ Stop early
                        </button>
                        <button
                            type="button"
                            disabled={busy}
                            className="px-3 py-1 rounded-full bg-white text-gray-500 hover:text-pink-600 disabled:opacity-40"
                            onClick={lambda (_e: MouseEvent) { run("done"); }}
                        >
                            ✓ Mark done
                        </button>
                    </div>
                </div>
            }}
            <div className="mt-3 text-xs text-red-400 h-4">{message}</div>
        </section>;
}
