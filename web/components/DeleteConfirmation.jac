import from .Modal { Modal }

def:pub DeleteConfirmation(
    title: str,
    message: str,
    onConfirm: Callable[[], None],
    onCancel: Callable[[], None]
) -> JsxElement {
    return
        <Modal title={title} onClose={onCancel} width="w-72">
            <p className="text-xs text-gray-500 mb-5 whitespace-pre-line">{message}</p>
            <div className="flex justify-end gap-2">
                <button
                    type="button"
                    className="px-4 py-1 text-sm rounded bg-gray-200 hover:bg-gray-300"
                    onClick={lambda (_e: MouseEvent) { onCancel(); }}
                >
                    Cancel
                </button>
                <button
                    type="button"
                    className="px-4 py-1 text-sm rounded bg-red-100 hover:bg-red-200 text-red-700 font-semibold"
                    onClick={lambda (_e: MouseEvent) { onConfirm(); }}
                >
                    Delete
                </button>
            </div>
        </Modal>;
}
