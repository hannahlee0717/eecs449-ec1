"""PlannerContext: the one place the web UI keeps planner state.

The server owns the data. This provider only holds the latest server snapshot
(`day`), the date being viewed, a clock that ticks once a second for the UI,
and the action functions every component calls. Each action is
write-then-refetch: call the server, then reload the day, so there is never a
second, locally edited copy of a task to drift out of sync.
"""

import from "react" { createContext, useContext, useEffect }
import from ...core.planner {
    PlannerDay,
    TaskView,
    ActionResult,
    get_day,
    save_day_info,
    add_category,
    update_category,
    delete_category,
    add_task,
    update_task,
    delete_task,
    set_completed,
    start_timer,
    pause_timer,
    stop_timer,
    finish_timer
}
import from ...core.utils.task_math { task_elapsed, planned_seconds_of, find_task_view }

glob PlannerCtx: any = createContext(None),
     POLL_MS: int = 4000,
     TICK_MS: int = 1000;

def:pub usePlanner -> any {
    return useContext(PlannerCtx);
}

"""Shift a YYYY-MM-DD string by whole days (noon avoids DST edges)."""
def:pub shift_date(date: str, days: int) -> str {
    d = new(Date, date + "T12:00:00");
    d.setDate(d.getDate() + days);
    iso: str = d.toISOString();
    return iso[:10];
}

"""Which task the timer panel shows: chosen > running > next unfinished."""
def pick_timer_task(day: PlannerDay | None, chosen: str) -> TaskView | None {
    if not day {
        return None;
    }
    picked = find_task_view(day, chosen) or find_task_view(day, day.active_task_id);
    if picked {
        return picked;
    }
    for t in day.tasks {
        if not t.completed {
            return t;
        }
    }
    return day.tasks[0] if len(day.tasks) > 0 else None;
}

def:pub PlannerProvider(children: any = None) -> JsxElement {
    has day: PlannerDay | None = None,
        dateKey: str = "",
        clockOffset: float = 0.0,
        now: float = 0.0,
        selectedTaskId: str = "",
        finishingId: str = "",
        error: str = "";

    async def refresh {
        try {
            fresh = await get_day(dateKey);
            # Server and browser clocks can disagree; timestamps come from the
            # server, so measure the offset once per fetch and apply it locally.
            clockOffset = fresh.server_now - Date.now();
            now = Date.now() + clockOffset;
            day = fresh;
            if not dateKey {
                dateKey = fresh.date;
            }
            error = "";
        } except Exception {
            error = "Can't reach the planner server. Is `jac run` still going?";
        }
    }

    # Every action is write-then-refetch: await the server call, reload the
    # day, and hand back "" (success) or a message the modal can show.
    async def settled(res: ActionResult) -> str {
        await refresh();
        return "" if res.ok else res.error;
    }

    def offline -> str {
        error = "Can't reach the planner server.";
        return error;
    }

    async def saveDayInfo(goal: str, note: str) -> str {
        try { return await settled(await save_day_info(dateKey, goal, note)); }
        except Exception { return offline(); }
    }

    async def addCategory(name: str, color: str) -> str {
        try { return await settled(await add_category(name, color)); }
        except Exception { return offline(); }
    }

    async def updateCategory(id: str, name: str, color: str) -> str {
        try { return await settled(await update_category(id, name, color)); }
        except Exception { return offline(); }
    }

    async def deleteCategory(id: str) -> str {
        try { return await settled(await delete_category(id)); }
        except Exception { return offline(); }
    }

    async def addTask(catId: str, title: str, start: int, end: int) -> str {
        try { return await settled(await add_task(catId, title, start, end, dateKey)); }
        except Exception { return offline(); }
    }

    async def updateTask(id: str, title: str, start: int, end: int) -> str {
        try { return await settled(await update_task(id, title, start, end)); }
        except Exception { return offline(); }
    }

    async def deleteTask(id: str) -> str {
        try { return await settled(await delete_task(id)); }
        except Exception { return offline(); }
    }

    async def setCompleted(id: str, done: bool) -> str {
        try { return await settled(await set_completed(id, done)); }
        except Exception { return offline(); }
    }

    async def startTimer(id: str) -> str {
        selectedTaskId = id;
        try { return await settled(await start_timer(id)); }
        except Exception { return offline(); }
    }

    async def pauseTimer(id: str) -> str {
        try { return await settled(await pause_timer(id)); }
        except Exception { return offline(); }
    }

    async def stopTimer(id: str) -> str {
        try { return await settled(await stop_timer(id)); }
        except Exception { return offline(); }
    }

    async def finishTimer(id: str) -> str {
        try { return await settled(await finish_timer(id)); }
        except Exception { return offline(); }
    }

    async can with [dateKey] entry {
        await refresh();
    }

    # One interval re-renders the clock; the other pulls in changes made from
    # the CLI or phone. Both are released when the provider unmounts.
    useEffect(
        lambda {
            tick = setInterval(lambda { now = Date.now() + clockOffset; }, TICK_MS);
            poll = setInterval(lambda { refresh(); }, POLL_MS);
            onVisible = lambda {
                if document.visibilityState == "visible" {  # jac:ignore[E1030]
                    refresh();
                }
            };
            document.addEventListener("visibilitychange", onVisible);
            return lambda {
                clearInterval(tick);
                clearInterval(poll);
                document.removeEventListener("visibilitychange", onVisible);
            };
        },
        []
    );

    # When the running task reaches its planned length, ask the server to
    # finish it. The server re-checks with its own clock and marks it done.
    async can with [now] entry {
        running = find_task_view(day, day.active_task_id) if day else None;
        if running and running.id != finishingId {
            if task_elapsed(running, now) >= planned_seconds_of(running) {
                finishingId = running.id;
                await finishTimer(running.id);
            }
        }
    }

    value = {
        "day": day,
        "dateKey": dateKey,
        "now": now,
        "error": error,
        "timerTask": pick_timer_task(day, selectedTaskId),
        "selectTask": lambda (id: str) { selectedTaskId = id; },
        "goToDate": lambda (d: str) { dateKey = d; },
        "shiftDate": lambda (n: int) { dateKey = shift_date(dateKey, n); },
        "saveDayInfo": saveDayInfo,
        "addCategory": addCategory,
        "updateCategory": updateCategory,
        "deleteCategory": deleteCategory,
        "addTask": addTask,
        "updateTask": updateTask,
        "deleteTask": deleteTask,
        "setCompleted": setCompleted,
        "startTimer": startTimer,
        "pauseTimer": pauseTimer,
        "stopTimer": stopTimer
    };

    return <PlannerCtx.Provider value={value}>{children}</PlannerCtx.Provider>;
}
