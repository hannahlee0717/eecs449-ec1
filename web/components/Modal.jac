"""Shared modal frame so Add/Edit Task, Category and Delete dialogs look alike."""

def:pub Modal(
    title: str,
    onClose: Callable[[], None],
    width: str = "w-80",
    children: any = None
) -> JsxElement {
    def handle_backdrop(e: MouseEvent) {
        if e.target == e.currentTarget {
            onClose();
        }
    }
    def handle_key(e: KeyboardEvent) {
        if e.key == "Escape" {
            onClose();
        }
    }
    return
        <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/20"
            onMouseDown={handle_backdrop}
            onKeyDown={handle_key}
        >
            <div
                role="dialog"
                aria-label={title}
                className={"bg-white rounded-xl shadow-lg p-6 border border-gray-200 " + width}
            >
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-semibold text-gray-700 text-base">{title}</h3>
                    <button
                        type="button"
                        aria-label="Close"
                        className="text-gray-400 hover:text-pink-400 text-lg leading-none"
                        onClick={lambda (_e: MouseEvent) { onClose(); }}
                    >
                        ×
                    </button>
                </div>
                {children}
            </div>
        </div>;
}

def:pub ErrorText(message: str) -> JsxElement {
    return
        <div className={"text-xs text-red-500 mb-2 " + ("" if message else "hidden")}>
            {message}
        </div>;
}
