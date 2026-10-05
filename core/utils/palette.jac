"""Soft category colors, shared by the web and mobile UIs.

Each category stores only a color *name*; every client maps it here so a
color change on the server re-tints blocks everywhere.
"""

obj Swatch {
    has name: str,
        planned: str,
        worked: str,
        chip: str,
        ink: str;
}

glob COLOR_NAMES: list[str] = [
         "yellow", "pink", "green", "blue", "purple", "orange"
     ];

glob SWATCHES: dict[str, Swatch] = {
         "yellow": Swatch(
             name="yellow", planned="#FEF9C3", worked="#FDE68A", chip="#FEF3C7", ink="#854D0E"
         ),
         "pink": Swatch(
             name="pink", planned="#FCE7F3", worked="#F9A8D4", chip="#FCE7F3", ink="#9D174D"
         ),
         "green": Swatch(
             name="green", planned="#DCFCE7", worked="#86EFAC", chip="#DCFCE7", ink="#166534"
         ),
         "blue": Swatch(
             name="blue", planned="#DBEAFE", worked="#93C5FD", chip="#DBEAFE", ink="#1E40AF"
         ),
         "purple": Swatch(
             name="purple", planned="#EDE9FE", worked="#C4B5FD", chip="#EDE9FE", ink="#5B21B6"
         ),
         "orange": Swatch(
             name="orange", planned="#FFEDD5", worked="#FDBA74", chip="#FFEDD5", ink="#9A3412"
         )
     };

def swatch(color: str) -> Swatch {
    return SWATCHES[color] if color in SWATCHES else SWATCHES["pink"];
}
