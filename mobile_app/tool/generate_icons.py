"""
Generates the app's icon sources and the Android notification icons.

The mark is drawn geometrically rather than stored as a hand-made binary,
so it can be re-rendered at any size (or restyled by editing the colours
here) without a design tool. Run from mobile_app/:

    python3 tool/generate_icons.py
    dart run flutter_launcher_icons      # launcher icons only

The notification icons this writes are final — flutter_launcher_icons does
not produce them.
"""

import os
from PIL import Image, ImageDraw

JADE_TOP = (0x16, 0x74, 0x5E)
JADE_BOTTOM = (0x0B, 0x46, 0x38)
S = 1024
SS = 4  # supersample factor, for clean curves at small sizes

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(HERE, "icon")
RES_DIR = os.path.join(HERE, "android", "app", "src", "main", "res")

# Android status-bar icons are 24dp; these are the px sizes per density.
NOTIFICATION_SIZES = {
    "drawable-mdpi": 24,
    "drawable-hdpi": 36,
    "drawable-xhdpi": 48,
    "drawable-xxhdpi": 72,
    "drawable-xxxhdpi": 96,
}


def gradient(size):
    """Diagonal jade gradient, matching the Home hero card."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x / size + y / size) / 2  # top-left -> bottom-right
            px[x, y] = tuple(
                round(JADE_TOP[i] + (JADE_BOTTOM[i] - JADE_TOP[i]) * t) for i in range(3)
            )
    return img


def wallet_mark(size):
    """
    White wallet on transparent, drawn to a 1024-unit grid then scaled.

    Opaque white = the mark; fully transparent = knockout. That one image
    serves both uses: composited over jade it's the launcher icon, and on
    its own it's the alpha-only silhouette Android needs for the status
    bar, where the knockout simply reads as a hole.
    """
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = n / 1024.0  # grid unit -> pixels

    white = (255, 255, 255, 255)
    clear = (0, 0, 0, 0)

    def rect(x0, y0, x1, y1, radius, fill):
        d.rounded_rectangle(
            [x0 * u, y0 * u, x1 * u, y1 * u], radius=radius * u, fill=fill
        )

    rect(212, 296, 812, 728, 92, white)          # wallet body
    rect(596, 444, 812, 580, 68, clear)          # clasp compartment
    d.ellipse([686 * u, 482 * u, 754 * u, 542 * u], fill=white)  # stud

    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(ICON_DIR, exist_ok=True)

    # Full-colour icon (legacy launcher): mark over the gradient.
    full = gradient(S).convert("RGBA")
    full.alpha_composite(wallet_mark(S))
    full.convert("RGB").save(os.path.join(ICON_DIR, "app_icon.png"))

    # Adaptive foreground. An adaptive icon is a 108dp canvas of which only
    # the middle 72dp survives the launcher's mask, so the art has to sit
    # inside that 66% — but the wallet already carries its own margin
    # within the grid, and shrinking the whole mark again on top of that
    # left it visibly marooned in the circle. This factor is chosen so the
    # wallet lands at roughly 46% of the canvas, i.e. about two thirds of
    # the visible area.
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    inner = round(S * 0.78)
    fg.alpha_composite(wallet_mark(inner), ((S - inner) // 2, (S - inner) // 2))
    fg.save(os.path.join(ICON_DIR, "app_icon_foreground.png"))

    # Adaptive background: full-bleed gradient.
    gradient(S).save(os.path.join(ICON_DIR, "app_icon_background.png"))

    # Notification icons. Android tints these itself and uses only the
    # alpha channel, so a colour icon here renders as a white blob — this
    # is why the notification needs its own asset rather than the launcher
    # one. Padded slightly so the mark doesn't touch the 24dp bounds.
    for folder, size in NOTIFICATION_SIZES.items():
        out_dir = os.path.join(RES_DIR, folder)
        os.makedirs(out_dir, exist_ok=True)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        inner = round(size * 0.86)
        canvas.alpha_composite(
            wallet_mark(inner), ((size - inner) // 2, (size - inner) // 2)
        )
        canvas.save(os.path.join(out_dir, "ic_stat_spendtrack.png"))

    print("icon sources -> icon/")
    print("notification icons -> android/app/src/main/res/drawable-*/ic_stat_spendtrack.png")


if __name__ == "__main__":
    main()
