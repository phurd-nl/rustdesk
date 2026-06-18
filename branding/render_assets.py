#!/usr/bin/env python3
"""Render all NextSession raster assets from the SVG masters.

Run with the branding venv that has cairosvg + pillow:
    /tmp/brandvenv/bin/python branding/render_assets.py
(or any venv: pip install cairosvg pillow)

Sources (vector masters, committed):
    branding/assets/nextsession-icon.svg   - orange disc + white N (app icon)
    branding/assets/nextsession-glyph.svg  - white N only (tray / adaptive fg / status)

Writes drop-in replacements into res/, flutter/windows, flutter/android,
flutter/ios, and a wordmark lockup. macOS .icns is emitted as an iconset PNG
set (PIL can't write .icns) — build it on the mac with `iconutil`.
"""
import base64
import glob
import io
import os
import re

import cairosvg
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ASSETS = os.path.join(HERE, "assets")
ICON_SVG = os.path.join(ASSETS, "nextsession-icon.svg")
GLYPH_SVG = os.path.join(ASSETS, "nextsession-glyph.svg")

ORANGE = (244, 158, 27, 255)   # #F49E1B
GRAY = (138, 141, 144, 255)    # #8A8D90


def render_svg(svg_path, px):
    png = cairosvg.svg2png(url=svg_path, output_width=px, output_height=px)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def recolor(glyph_img, rgba):
    """Replace the glyph's white pixels with rgba, preserving alpha (for mono icons)."""
    out = Image.new("RGBA", glyph_img.size, (0, 0, 0, 0))
    px_in = glyph_img.load()
    px_out = out.load()
    for y in range(glyph_img.height):
        for x in range(glyph_img.width):
            a = px_in[x, y][3]
            if a:
                px_out[x, y] = (rgba[0], rgba[1], rgba[2], a)
    return out


def save(img, rel):
    path = os.path.join(REPO, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"  {rel}  ({img.width}x{img.height})")


def save_ico(rel, sizes):
    path = os.path.join(REPO, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    base = render_svg(ICON_SVG, max(sizes))
    base.save(path, format="ICO", sizes=[(s, s) for s in sizes])
    print(f"  {rel}  (ico {sizes})")


def find_font(*names, fallbacks=()):
    roots = ["/usr/share/fonts", os.path.expanduser("~/.fonts")]
    for name in list(names) + list(fallbacks):
        for root in roots:
            hits = glob.glob(os.path.join(root, "**", name), recursive=True)
            if hits:
                return hits[0]
    return None


def make_wordmark():
    """Badge + 'NEXT' (orange) + 'SESSION' (gray italic), transparent bg.
    v1 uses Liberation Sans Bold; swap in NextLink's brand font later."""
    bold = find_font("LiberationSans-Bold.ttf", fallbacks=("DejaVuSans-Bold.ttf",))
    italic = find_font("LiberationSans-BoldItalic.ttf",
                       fallbacks=("DejaVuSans-BoldOblique.ttf", "DejaVuSans-Bold.ttf"))
    H = 240
    cap = 150
    fb = ImageFont.truetype(bold, cap)
    fi = ImageFont.truetype(italic, cap)
    pad = 40
    badge = render_svg(ICON_SVG, H)
    tmp = Image.new("RGBA", (4000, H * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    x = H + pad
    ty = H // 2
    w1 = d.textbbox((0, 0), "NEXT", font=fb)[2]
    w2 = d.textbbox((0, 0), "SESSION", font=fi)[2]
    total = x + w1 + 12 + w2 + pad
    canvas = Image.new("RGBA", (total, H), (0, 0, 0, 0))
    canvas.alpha_composite(badge, (0, 0))
    d = ImageDraw.Draw(canvas)
    d.text((x, ty), "NEXT", font=fb, fill=ORANGE, anchor="lm")
    d.text((x + w1 + 12, ty), "SESSION", font=fi, fill=GRAY, anchor="lm")
    save(canvas, "branding/assets/nextsession-logo.png")
    save(canvas, "res/nextsession-logo.png")
    return canvas


def svg_embedding_png(png_img):
    buf = io.BytesIO()
    png_img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()
    w, h = png_img.size
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}"><image width="{w}" height="{h}" '
            f'xlink:href="data:image/png;base64,{b64}" '
            f'xmlns:xlink="http://www.w3.org/1999/xlink"/></svg>\n')


def main():
    print("res/ icons + pngs:")
    save_ico("res/icon.ico", [16, 24, 32, 48, 64, 128, 256])
    save_ico("res/tray-icon.ico", [16, 24, 32, 48, 64])
    save_ico("flutter/windows/runner/resources/app_icon.ico", [16, 24, 32, 48, 64, 128, 256])
    for px, rel in [(32, "res/32x32.png"), (64, "res/64x64.png"),
                    (128, "res/128x128.png"), (256, "res/128x128@2x.png"),
                    (256, "res/icon.png"), (1024, "res/mac-icon.png")]:
        save(render_svg(ICON_SVG, px), rel)

    # macOS template tray icons (mono). Match existing pixel dims if present.
    print("macOS tray (template, mono):")
    for rel, rgba in [("res/mac-tray-dark-x2.png", (0, 0, 0, 255)),
                      ("res/mac-tray-light-x2.png", (255, 255, 255, 255))]:
        dim = 44
        p = os.path.join(REPO, rel)
        if os.path.exists(p):
            dim = Image.open(p).size[0]
        save(recolor(render_svg(GLYPH_SVG, dim), rgba), rel)

    # In-app + vector logos: badge for pure-icon svgs.
    print("vector logos:")
    icon_svg_src = open(ICON_SVG).read()
    for rel in ["res/logo.svg", "res/scalable.svg", "flutter/assets/icon.svg"]:
        with open(os.path.join(REPO, rel), "w") as f:
            f.write(icon_svg_src)
        print(f"  {rel}  (badge vector)")

    # Wordmark lockup, and PNG-backed svgs for the text banners (keep filenames).
    print("wordmark:")
    wm = make_wordmark()
    for rel in ["res/logo-header.svg", "res/rustdesk-banner.svg", "res/design.svg"]:
        with open(os.path.join(REPO, rel), "w") as f:
            f.write(svg_embedding_png(wm))
        print(f"  {rel}  (wordmark)")

    # Android adaptive icon set.
    print("android mipmaps:")
    launcher = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    foreground = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    stat = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}
    for dpi, px in launcher.items():
        d = f"flutter/android/app/src/main/res/mipmap-{dpi}"
        save(render_svg(ICON_SVG, px), f"{d}/ic_launcher.png")
        save(render_svg(ICON_SVG, px), f"{d}/ic_launcher_round.png")
        # adaptive foreground: glyph centered in 108dp canvas (~66% safe zone)
        fg = Image.new("RGBA", (foreground[dpi], foreground[dpi]), (0, 0, 0, 0))
        g = render_svg(GLYPH_SVG, int(foreground[dpi] * 0.66))
        fg.alpha_composite(g, ((fg.width - g.width) // 2, (fg.height - g.height) // 2))
        save(fg, f"{d}/ic_launcher_foreground.png")
        save(recolor(render_svg(GLYPH_SVG, stat[dpi]), (255, 255, 255, 255)),
             f"{d}/ic_stat_logo.png")

    # Android adaptive background color drawable.
    bg_dir = "flutter/android/app/src/main/res/values"
    os.makedirs(os.path.join(REPO, bg_dir), exist_ok=True)
    with open(os.path.join(REPO, bg_dir, "ic_launcher_background.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">#F49E1B</color>\n</resources>\n')
    print(f"  {bg_dir}/ic_launcher_background.xml")

    # iOS app icon set (regenerate PNGs at existing declared sizes).
    print("iOS app icon:")
    ios = os.path.join(REPO, "flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset")
    if os.path.isdir(ios):
        for fn in os.listdir(ios):
            m = re.match(r"Icon-App-(\d+)x(\d+)@(\d)x\.png", fn)
            if m:
                px = int(m.group(1)) * int(m.group(3))
                save(render_svg(ICON_SVG, px),
                     os.path.relpath(os.path.join(ios, fn), REPO))

    # macOS iconset PNGs (build .icns on mac: iconutil -c icns nextsession.iconset)
    print("macOS iconset (run iconutil on mac to make .icns):")
    iconset = "branding/assets/nextsession.iconset"
    for px, name in [(16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
                     (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
                     (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
                     (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
                     (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")]:
        save(render_svg(ICON_SVG, px), f"{iconset}/{name}")

    print("\nDone. macOS .icns: `iconutil -c icns branding/assets/nextsession.iconset` "
          "then copy to flutter/macos/Runner/AppIcon.icns")


if __name__ == "__main__":
    main()
