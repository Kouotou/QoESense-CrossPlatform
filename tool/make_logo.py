"""QoESense logo: Cameroon green / red / yellow stripes, a yellow star in the centre, "QoE" on the star.

Usage: python make_logo.py <repo root> [preview-dir]
Writes the Android launcher icons (legacy + adaptive + monochrome), the Play icon and the
feature graphic. With a preview dir, writes only previews there.
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFont

GREEN, RED, YELLOW = (0, 122, 94), (206, 17, 38), (252, 209, 22)
TEXT = (0, 84, 64)          # deep green, readable on the yellow star
OUTLINE = (255, 255, 255)   # thin white edge keeps the star distinct over the yellow stripe
FONT = "C:/Windows/Fonts/seguibl.ttf"  # Segoe UI Black
SS = 8  # supersampling


def star_points(cx, cy, r_out, r_in, rot=-90):
    pts = []
    for i in range(10):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 36)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def stripes(d, x0, y0, w, h):
    t = w / 3
    d.rectangle([x0, y0, x0 + t, y0 + h], fill=GREEN)
    d.rectangle([x0 + t, y0, x0 + 2 * t, y0 + h], fill=RED)
    d.rectangle([x0 + 2 * t, y0, x0 + w, y0 + h], fill=YELLOW)


def star_with_text(img, cx, cy, r, text_cut=False, color=YELLOW):
    """Star of outer radius r with "QoE" centred; text_cut makes the text transparent (monochrome)."""
    d = ImageDraw.Draw(img)
    rin = r * 0.5
    if not text_cut:
        d.polygon(star_points(cx, cy + r * 0.04, r * 1.06, rin * 1.06), fill=OUTLINE)
    d.polygon(star_points(cx, cy + r * 0.04, r, rin), fill=color)
    size = int(r * 0.46)
    font = ImageFont.truetype(FONT, size)
    bbox = d.textbbox((0, 0), "QoE", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pos = (cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1] + r * 0.07)
    if text_cut:
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).text(pos, "QoE", font=font, fill=255)
        img.paste((0, 0, 0, 0), (0, 0), mask)
    else:
        d.text(pos, "QoE", font=font, fill=TEXT)


def legacy(px):
    S = px * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    stripes(ImageDraw.Draw(base), 0, 0, S, S)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=S * 0.22, fill=255)
    im.paste(base, (0, 0), mask)
    star_with_text(im, S / 2, S / 2, S * 0.40)
    return im.resize((px, px), Image.LANCZOS)


def adaptive_background(px):
    S = px * SS
    im = Image.new("RGBA", (S, S))
    stripes(ImageDraw.Draw(im), 0, 0, S, S)
    return im.resize((px, px), Image.LANCZOS)


def adaptive_foreground(px, monochrome=False):
    # 108 dp canvas; launchers show at least the central 72 dp, the safe zone is 66 dp.
    S = px * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    star_with_text(im, S / 2, S / 2, S * 0.28, text_cut=monochrome, color=(255, 255, 255) if monochrome else YELLOW)
    return im.resize((px, px), Image.LANCZOS)


def play_icon():
    S = 512 * SS
    im = Image.new("RGBA", (S, S))
    stripes(ImageDraw.Draw(im), 0, 0, S, S)  # full bleed: Play applies its own rounding
    star_with_text(im, S / 2, S / 2, S * 0.40)
    return im.resize((512, 512), Image.LANCZOS).convert("RGB")


def feature_graphic():
    W, H = 1024 * SS // 2, 500 * SS // 2
    im = Image.new("RGBA", (W, H))
    stripes(ImageDraw.Draw(im), 0, 0, W, H)
    star_with_text(im, W / 2, H / 2, H * 0.40)
    return im.resize((1024, 500), Image.LANCZOS).convert("RGB")


def main():
    root = sys.argv[1]
    preview = sys.argv[2] if len(sys.argv) > 2 else None
    if preview:
        os.makedirs(preview, exist_ok=True)
        legacy(192).save(f"{preview}/legacy-192.png")
        # adaptive as a circle launcher would crop it
        bg, fg = adaptive_background(432), adaptive_foreground(432)
        comp = Image.alpha_composite(bg, fg)
        m = Image.new("L", comp.size, 0)
        ImageDraw.Draw(m).ellipse([432 * 18 / 108, 432 * 18 / 108, 432 * 90 / 108, 432 * 90 / 108], fill=255)
        circ = Image.new("RGBA", comp.size, (255, 255, 255, 0)); circ.paste(comp, (0, 0), m)
        circ.crop((72, 72, 360, 360)).save(f"{preview}/adaptive-circle.png")
        small = legacy(48).resize((144, 144), Image.NEAREST); small.save(f"{preview}/legacy-48-zoomed.png")
        play_icon().save(f"{preview}/play-512.png")
        return
    res = os.path.join(root, "android/app/src/main/res")
    for q, m in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        d = os.path.join(res, "mipmap-" + q)
        os.makedirs(d, exist_ok=True)
        legacy(int(48 * m)).save(os.path.join(d, "ic_launcher.png"))
        adaptive_foreground(int(108 * m)).save(os.path.join(d, "ic_launcher_foreground.png"))
        adaptive_background(int(108 * m)).save(os.path.join(d, "ic_launcher_background.png"))
        adaptive_foreground(int(108 * m), monochrome=True).save(os.path.join(d, "ic_launcher_monochrome.png"))
    with open(os.path.join(res, "mipmap-anydpi-v26/ic_launcher.xml"), "w", newline="\n") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
                '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
                '</adaptive-icon>\n')
    old_color = os.path.join(res, "values/ic_launcher_background.xml")
    if os.path.exists(old_color):
        os.remove(old_color)  # background is now the striped image
    play = os.path.join(root, "docs/play")
    play_icon().save(os.path.join(play, "icon-512.png"))
    feature_graphic().save(os.path.join(play, "feature-graphic-1024x500.png"))
    print("written")


main()
