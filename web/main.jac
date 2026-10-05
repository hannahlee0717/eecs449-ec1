"""Stunny web app entry. The planner service (core/planner.jac) runs colocated
with this app under `jac run`; components reach it through PlannerContext."""

import "./styles/global.css";
import from .context.PlannerContext { PlannerProvider, usePlanner }
import from .components.Sidebar { Sidebar }
import from .components.Timer { Timer }

def:pub Header -> JsxElement {
    return
        <header className="max-w-6xl mx-auto w-full px-8 pt-6">
            <div className="text-green-600 font-bold italic text-lg" style={{"fontFamily": "cursive"}}>Stunny</div>
            <div className="flex items-center gap-3 mt-2">
                <div className="w-14 h-14 rounded-full bg-gray-200 flex items-center justify-center text-3xl">🐰</div>
                <div>
                    <div className="font-bold">Hannah</div>
                    <div className="text-sm text-gray-500">let’s lock in</div>
                </div>
            </div>
        </header>;
}

def:pub ConnectionBanner -> JsxElement {
    ctx: any = usePlanner();
    return
        <div className={"max-w-6xl mx-auto w-full px-8 " + ("" if ctx.error else "hidden")}>
            <div className="mt-3 rounded bg-red-50 text-red-600 text-xs px-3 py-2 border border-red-100">
                {ctx.error}
            </div>
        </div>;
}

def:pub app -> JsxElement {
    return
        <PlannerProvider>
            <div className="min-h-screen bg-white flex flex-col">
                <Header/>
                <ConnectionBanner/>
                <main className="flex-1 grid grid-cols-1 lg:grid-cols-2 gap-8 p-8 max-w-6xl mx-auto w-full items-start">
                    <Sidebar/>
                    <Timer/>
                </main>
            </div>
        </PlannerProvider>;
}
