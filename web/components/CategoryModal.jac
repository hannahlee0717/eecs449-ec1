"""Add Category / Edit Category. Edit mode can also delete (with confirmation)."""

import from .Modal { Modal, ErrorText }
import from .DeleteConfirmation { DeleteConfirmation }
import from ..context.PlannerContext { usePlanner }
import from ...core.planner { CategoryView }
import from ...core.utils.palette { COLOR_NAMES, swatch }

def:pub CategoryModal(
    onClose: Callable[[], None], category: CategoryView | None = None
) -> JsxElement {
    ctx: any = usePlanner();
    has name: str = category.name if category else "",
        color: str = category.color if category else "pink",
        error: str = "",
        saving: bool = False,
        confirmDelete: bool = False;

    async def handle_save(e: FormEvent) {
        e.preventDefault();
        if not name.strip() {
            error = "Category name cannot be empty.";
            return;
        }
        saving = True;
        msg = "";
        if category {
            msg = await ctx.updateCategory(category.id, name, color);
        } else {
            msg = await ctx.addCategory(name, color);
        }
        saving = False;
        if msg {
            error = msg;
        } else {
            onClose();
        }
    }

    async def handle_delete {
        if category {
            await ctx.deleteCategory(category.id);
        }
        onClose();
    }

    if confirmDelete and category {
        return
            <DeleteConfirmation
                title="Delete this category?"
                message={"All tasks in \"" + category.name + "\" will be deleted.\nStudy hours already logged remain counted."}
                onConfirm={handle_delete}
                onCancel={lambda { confirmDelete = False; }}
            />;
    }

    return
        <Modal title={"Edit Category" if category else "Add Category"} onClose={onClose}>
            <form onSubmit={handle_save}>
                <div className="mb-4">
                    <label className="block text-xs text-gray-400 mb-1">Category Name</label>
                    <input
                        className="w-full px-2 py-1 rounded border border-gray-200 bg-gray-50 text-sm"
                        placeholder="e.g. EECS 449"
                        value={name}
                        autoFocus={True}
                        onChange={lambda (e: ChangeEvent) { name = e.target.value; error = ""; }}
                    />
                </div>
                <div className="mb-4">
                    <label className="block text-xs text-gray-400 mb-2">Pick a color</label>
                    <div className="flex flex-row gap-2">
                        {for c in COLOR_NAMES {
                            <button
                                key={c}
                                type="button"
                                aria-label={"Pick color " + c}
                                aria-pressed={c == color}
                                className={"w-7 h-7 rounded-full border-2 flex items-center justify-center transition-all duration-150 " + ("ring-2 ring-pink-400 border-pink-400 scale-110" if c == color else "border-gray-300")}
                                style={{"backgroundColor": swatch(c).worked}}
                                onClick={lambda (_e: MouseEvent) { color = c; }}
                            >
                                {if c == color {
                                    <svg className="w-3 h-3 text-pink-700" fill="none" stroke="currentColor" strokeWidth="3" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7"/>
                                    </svg>
                                }}
                            </button>
                        }}
                    </div>
                </div>
                <ErrorText message={error}/>
                <div className="flex justify-between gap-2">
                    {if category {
                        <button
                            type="button"
                            className="flex-1 px-3 py-1 text-sm rounded bg-red-100 hover:bg-red-200 text-red-700 font-semibold"
                            onClick={lambda (_e: MouseEvent) { confirmDelete = True; }}
                        >
                            Delete
                        </button>
                    }}
                    <button
                        type="button"
                        className="flex-1 px-3 py-1 text-sm rounded bg-gray-200 hover:bg-gray-300"
                        onClick={lambda (_e: MouseEvent) { onClose(); }}
                    >
                        Cancel
                    </button>
                    <button
                        type="submit"
                        disabled={saving or not name.strip()}
                        className="flex-1 px-3 py-1 text-sm rounded bg-pink-100 hover:bg-pink-200 text-pink-700 font-semibold disabled:opacity-50"
                    >
                        {"Save" if category else "Add"}
                    </button>
                </div>
            </form>
        </Modal>;
}
