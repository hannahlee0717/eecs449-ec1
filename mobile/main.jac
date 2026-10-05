"""Stunny on the phone: today's plan, the study timer, and quick add.

Same backend as the web app: every call below bridges to the `planner`
service, and the timer is derived from the same server timestamps.
"""

import from "react" { useEffect }
import from "@jac/mobui" { View, Text, Pressable, TextInput, ScrollView }
import from .theme { C, styles }
import from ..core.planner {
    PlannerDay,
    TaskView,
    ActionResult,
    get_day,
    add_task_at_times,
    start_timer,
    pause_timer,
    stop_timer,
    set_completed
}
import from ..core.utils.clock_format { format_clock, format_hours, remaining_seconds }
import from .timer_math {
    task_elapsed,
    planned_seconds_of,
    live_study_seconds,
    find_task_view
}
import from ..core.utils.palette { swatch }

glob POLL_MS: int = 4000;

def pick_focus(day: PlannerDay | None, chosen: str) -> TaskView | None {
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
    return None;
}

def:pub TaskRow(
    task: TaskView,
    focused: bool,
    onFocus: Callable[[str], None],
    onToggle: Callable[[TaskView], None]
) -> JsxElement {
    sw = swatch(task.color);
    return
        <Pressable
            style={[styles.taskRow, {"backgroundColor": sw.planned if focused else "transparent"}]}
            onPress={lambda { onFocus(task.id); }}
        >
            <Pressable
                style={[styles.check, {"backgroundColor": sw.worked, "borderColor": sw.worked} if task.completed else {}]}
                onPress={lambda { onToggle(task); }}
            >
                <Text>{"✓" if task.completed else ""}</Text>
            </Pressable>
            <View style={{"flex": 1}}>
                <Text style={styles.taskDone if task.completed else styles.taskTitle}>
                    {("⏱ " if task.timer_status == "running" else "") + task.title}
                </Text>
                <Text style={styles.small}>
                    {task.time_label + " · " + task.category_name}
                </Text>
            </View>
        </Pressable>;
}

def:pub app -> JsxElement {
    has day: PlannerDay | None = None,
        offset: float = 0.0,
        now: float = 0.0,
        focusId: str = "",
        error: str = "",
        busy: bool = False,
        newTitle: str = "",
        newCat: str = "",
        newStart: str = "09:00",
        newEnd: str = "10:00",
        addMsg: str = "";

    async def refresh {
        try {
            fresh = await get_day("");
            offset = fresh.server_now - Date.now();
            now = Date.now() + offset;
            day = fresh;
            if not newCat and len(fresh.categories) > 0 {
                newCat = fresh.categories[0].id;
            }
            error = "";
        } except Exception {
            error = "Can't reach the Stunny server. Start it with `jac run`.";
        }
    }

    async def settle(res: ActionResult) {
        if not res.ok {
            error = res.error;
        }
        await refresh();
    }

    async can with entry {
        await refresh();
    }

    useEffect(
        lambda {
            tick = setInterval(lambda { now = Date.now() + offset; }, 1000);
            poll = setInterval(lambda { refresh(); }, POLL_MS);
            return lambda {
                clearInterval(tick);
                clearInterval(poll);
            };
        },
        []
    );

    focus = pick_focus(day, focusId);
    elapsed = task_elapsed(focus, now) if focus else 0.0;
    remaining = remaining_seconds(elapsed, planned_seconds_of(focus)) if focus else 0.0;
    running = focus and focus.timer_status == "running";
    tasks: list[TaskView] = day.tasks if day else [];
    studied = live_study_seconds(day, now) if day else 0.0;

    # Auto-finish is decided by the server (settle on every read), so the
    # phone only needs to refresh once its local countdown reaches zero.
    async can with [now] entry {
        f = pick_focus(day, focusId);
        if f and f.timer_status == "running" {
            if task_elapsed(f, now) >= planned_seconds_of(f) {
                await refresh();
            }
        }
    }

    async def timer_action(action: str) {
        if not focus or busy {
            return;
        }
        busy = True;
        try {
            if action == "start" {
                await settle(await start_timer(focus.id));
            } elif action == "pause" {
                await settle(await pause_timer(focus.id));
            } else {
                await settle(await stop_timer(focus.id));
            }
        } except Exception {
            error = "Can't reach the Stunny server.";
        }
        busy = False;
    }

    async def toggle_done(t: TaskView) {
        try {
            await settle(await set_completed(t.id, not t.completed));
        } except Exception {
            error = "Can't reach the Stunny server.";
        }
    }

    async def quick_add {
        if not newTitle.strip() {
            addMsg = "Title cannot be empty.";
            return;
        }
        try {
            res = await add_task_at_times(newCat, newTitle, newStart, newEnd, "");
            if res.ok {
                addMsg = "Added ✓";
                newTitle = "";
            } else {
                addMsg = res.error;
            }
            await refresh();
        } except Exception {
            addMsg = "Can't reach the Stunny server.";
        }
    }

    return
        <ScrollView style={styles.screen} contentContainerStyle={styles.body}>
            <Text style={styles.brand}>Stunny</Text>
            <View style={styles.header}>
                <View style={styles.avatar}><Text style={styles.avatarText}>🐰</Text></View>
                <View style={{"flex": 1}}>
                    <Text style={styles.name}>Hannah</Text>
                    <Text style={styles.sub}>{"let’s lock in · " + (day.date if day else "")}</Text>
                </View>
                <View style={{"alignItems": "flex-end"}}>
                    <Text style={styles.small}>Study hours</Text>
                    <Text style={styles.sectionTitle}>{format_hours(studied)}</Text>
                </View>
            </View>

            {(<View style={styles.banner}><Text style={styles.bannerText}>{error}</Text></View>) if error else <View/>}

            <View style={styles.timerCard}>
                <Text style={{"fontSize": 34}}>{"🐇" if running else "🐰"}</Text>
                <Text style={styles.clock}>{format_clock(remaining) if focus else "00:00"}</Text>
                <Text style={styles.sectionTitle}>{(("✓ " if focus.completed else "") + focus.title) if focus else "Nothing planned yet"}</Text>
                <Text style={styles.small}>
                    {("worked " + format_clock(elapsed) + " of " + str(focus.duration) + "m") if focus else "Add a task below or on the web planner."}
                </Text>
                {(
                    <View style={{"alignItems": "center", "gap": 10, "marginTop": 6}}>
                        <Pressable style={styles.pill} onPress={lambda { timer_action("pause" if running else "start"); }}>
                            <Text style={styles.pillText}>{"PAUSE" if running else ("RESUME" if elapsed > 0 else "START")}</Text>
                        </Pressable>
                        <View style={styles.row}>
                            <Pressable style={styles.ghost} onPress={lambda { timer_action("stop"); }}>
                                <Text style={styles.ghostText}>■ Stop early</Text>
                            </Pressable>
                            <Pressable style={styles.ghost} onPress={lambda { if focus { toggle_done(focus); } }}>
                                <Text style={styles.ghostText}>✓ Mark done</Text>
                            </Pressable>
                        </View>
                    </View>
                ) if focus and not focus.completed else <View/>}
            </View>

            <View style={styles.card}>
                <Text style={styles.sectionTitle}>Today</Text>
                {(<Text style={styles.small}>No tasks planned for today.</Text>) if len(tasks) == 0 else <View/>}
                {[
                    <TaskRow
                        key={t.id}
                        task={t}
                        focused={focus is not None and focus.id == t.id}
                        onFocus={lambda (id: str) { focusId = id; }}
                        onToggle={toggle_done}
                    />
                    for t in tasks
                ]}
            </View>

            <View style={styles.card}>
                <Text style={styles.sectionTitle}>Quick add</Text>
                <TextInput
                    style={styles.input}
                    value={newTitle}
                    placeholder="Task title"
                    placeholderTextColor={C.muted}
                    onChangeText={lambda (t: str) { newTitle = t; addMsg = ""; }}
                />
                <View style={[styles.row, {"flexWrap": "wrap"}]}>
                    {[
                        <Pressable
                            key={c.id}
                            style={[styles.chip, {"backgroundColor": swatch(c.color).chip, "borderWidth": 2, "borderColor": "#f472b6" if c.id == newCat else "transparent"}]}
                            onPress={lambda { newCat = c.id; }}
                        >
                            <Text style={[styles.chipText, {"color": swatch(c.color).ink}]}>{c.name}</Text>
                        </Pressable>
                        for c in (day.categories if day else [])
                    ]}
                </View>
                <View style={styles.row}>
                    <TextInput
                        style={styles.timeInput}
                        value={newStart}
                        placeholder="09:00"
                        onChangeText={lambda (t: str) { newStart = t; addMsg = ""; }}
                    />
                    <Text style={styles.small}>to</Text>
                    <TextInput
                        style={styles.timeInput}
                        value={newEnd}
                        placeholder="10:00"
                        onChangeText={lambda (t: str) { newEnd = t; addMsg = ""; }}
                    />
                </View>
                <View style={styles.between}>
                    <Text style={styles.small}>{addMsg}</Text>
                    <Pressable style={[styles.pill, {"paddingHorizontal": 24, "paddingVertical": 8}]} onPress={quick_add}>
                        <Text style={styles.pillText}>ADD</Text>
                    </Pressable>
                </View>
            </View>
        </ScrollView>;
}
