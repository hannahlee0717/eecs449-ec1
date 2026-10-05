"""stunny: the terminal face of the Stunny study planner.

Every command calls the shared `planner` service app. The imports below are
compiled into async bridge stubs, so the CLI never touches the database
directly: it sees exactly the data the web and mobile apps see.
"""

import argparse;
import asyncio;
import os;
import sys;
import from jaclang.server { sv_client }
import from jaclang.server.bridge { BridgeError, BridgeUnavailable }
import from core.planner {
    PlannerDay,
    TaskView,
    CategoryView,
    ActionResult,
    get_day,
    add_category,
    add_task_at_times,
    start_timer,
    pause_timer,
    stop_timer,
    toggle_timer,
    set_completed
}
import from cli.render { render_day, render_categories, render_task_line }

glob DEFAULT_SERVER: str = "http://localhost:8000",
     PLANNER_ROUTE: str = "/api/planner";

glob PROG: str = "stunny",
     EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3;

def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="Stunny study planner from the terminal. Needs the server: `jac run`."
    );
    sub = parser.add_subparsers(dest="command", metavar="<command>", required=True);

    today = sub.add_parser("today", help="show today's time blocks and study hours");
    today.add_argument("--date", `default="", help="YYYY-MM-DD (default: today)");

    add = sub.add_parser("add", help="add a time-blocked task");
    add.add_argument("title");
    add.add_argument("--category", "-c", required=True, help="category name");
    add.add_argument("--start", "-s", required=True, help="HH:MM (24h)");
    add.add_argument("--end", "-e", required=True, help="HH:MM (24h)");
    add.add_argument("--date", `default="");

    timer = sub.add_parser("timer", help="control the study timer for a task");
    timer.add_argument("action", choices=["start", "pause", "stop", "toggle"]);
    timer.add_argument("task", help="task number from `today`, or part of its title");

    done = sub.add_parser("done", help="mark a task completed");
    done.add_argument("task");
    undo = sub.add_parser("undo", help="mark a task not completed");
    undo.add_argument("task");

    cats = sub.add_parser("category", help="list or add categories");
    cats.add_argument("action", choices=["list", "add"], nargs="?", `default="list");
    cats.add_argument("name", nargs="?", `default="");
    cats.add_argument(
        "--color",
        `default="pink",
        choices=["yellow", "pink", "green", "blue", "purple", "orange"]
    );
    return parser;
}

def warn(text: str) {
    print(text, file=sys.stderr);
}

"""Find a task by its 1-based number in `today`, its id, or a title fragment."""
def pick_task(day: PlannerDay, ref: str) -> TaskView | None {
    if ref.isdigit() {
        n = int(ref);
        return day.tasks[n - 1] if 1 <= n <= len(day.tasks) else None;
    }
    for t in day.tasks {
        if t.id == ref {
            return t;
        }
    }
    matches = [t for t in day.tasks if ref.lower() in t.title.lower()];
    return matches[0] if len(matches) == 1 else None;
}

def show_result(res: ActionResult, success: str) -> int {
    if res.ok {
        print(success);
        return EXIT_OK;
    }
    warn("stunny: " + res.error);
    return EXIT_FAILURE;
}

async def cmd_add(ns: argparse.Namespace) -> int {
    day = await get_day(ns.date);
    wanted = ns.category.strip().lower();
    cats = [c for c in day.categories if c.name.lower() == wanted];
    if not cats {
        names = ", ".join([c.name for c in day.categories]) or "none yet";
        warn(f"stunny: no category named '{ns.category}' (have: {names})");
        return EXIT_USAGE;
    }
    res = await add_task_at_times(cats[0].id, ns.title, ns.start, ns.end, ns.date);
    return show_result(res, f"Added '{ns.title}' {ns.start}-{ns.end} to {cats[0].name}.");
}

async def cmd_task(ns: argparse.Namespace) -> int {
    day = await get_day("");
    t = pick_task(day, ns.task);
    if not t {
        warn(f"stunny: no single task matches '{ns.task}'. Try `stunny today`.");
        return EXIT_USAGE;
    }
    if ns.command == "done" {
        return show_result(await set_completed(t.id, True), f"✅ Completed '{t.title}'.");
    }
    if ns.command == "undo" {
        return show_result(await set_completed(t.id, False), f"Reopened '{t.title}'.");
    }
    action = ns.action;
    if action == "start" {
        res = await start_timer(t.id);
    } elif action == "pause" {
        res = await pause_timer(t.id);
    } elif action == "stop" {
        res = await stop_timer(t.id);
    } else {
        res = await toggle_timer(t.id);
    }
    if not res.ok {
        return show_result(res, "");
    }
    fresh = await get_day("");
    for (i, ft) in enumerate(fresh.tasks) {
        if ft.id == t.id {
            print(render_task_line(i + 1, ft));
        }
    }
    return EXIT_OK;
}

async def cmd_category(ns: argparse.Namespace) -> int {
    if ns.action == "add" {
        if not ns.name {
            warn("stunny: category add needs a name");
            return EXIT_USAGE;
        }
        res = await add_category(ns.name, ns.color);
        return show_result(res, f"Added category '{ns.name}' ({ns.color}).");
    }
    day = await get_day("");
    print(render_categories(day.categories));
    return EXIT_OK;
}

async def dispatch(ns: argparse.Namespace) -> int {
    try {
        if ns.command == "today" {
            print(render_day(await get_day(ns.date)));
            return EXIT_OK;
        }
        if ns.command == "add" {
            return await cmd_add(ns);
        }
        if ns.command in ["timer", "done", "undo"] {
            return await cmd_task(ns);
        }
        if ns.command == "category" {
            return await cmd_category(ns);
        }
    } except BridgeUnavailable {
        warn("stunny: the planner server is not reachable.");
        warn("hint: start it with `jac run` in the project root,");
        warn("      or point at it with STUNNY_SERVER=http://host:8000");
        return EXIT_UNAVAILABLE;
    } except BridgeError as e {
        warn("stunny: server error: " + str(e));
        return EXIT_FAILURE;
    }
    return EXIT_USAGE;
}

"""Point the bridge at the planner service unless JAC_APP_PLANNER_URL already does.

STUNNY_SERVER overrides the default, e.g. a laptop on the LAN.
"""
def connect_to_server {
    if os.environ.get("JAC_APP_PLANNER_URL") {
        return;
    }
    url = os.environ.get("STUNNY_SERVER", DEFAULT_SERVER).rstrip("/");
    sv_client.register("planner", url, route=PLANNER_ROUTE);
}

async def main(argv: list[str]) -> int {
    connect_to_server();
    return await dispatch(build_parser().parse_args(argv));
}

with entry:__main__ {
    sys.`exit(asyncio.run(main(sys.argv[1:])));
}
