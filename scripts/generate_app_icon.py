#!/usr/bin/env python3
"""Generate Grünbuch app icon — light Arca-style liquid glass aesthetic."""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(__file__),
    "..",
    "AfterLesson",
    "Assets.xcassets",
    "AppIcon.appiconset",
    "icon_1024.png",
)


def lerp(a, b, t):
    return a + (b - a) * t


def lerp_color(c1, c2, t):
    return tuple(int(lerp(c1[i], c2[i], t)) for i in range(3))


def gradient_at(t):
    stops = [
        (0.0, (68, 208, 198)),
        (0.40, (92, 168, 248)),
        (0.70, (110, 200, 155)),
        (1.0, (175, 168, 238)),
    ]
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        if t <= t1:
            local = (t - t0) / (t1 - t0) if t1 > t0 else 0
            return lerp_color(c0, c1, local)
    return stops[-1][1]


def make_background(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx, cy = size / 2, size / 2
    max_r = size * 0.75
    for y in range(size):
        for x in range(size):
            d = min(math.hypot(x - cx, y - cy) / max_r, 1.0)
            c = lerp_color((246, 248, 251), (232, 237, 243), d ** 1.3)
            px[x, y] = c
    return img


def sample_bezier(p0, p1, p2, p3, t):
    u = 1 - t
    x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
    y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
    return x, y


def bezier_points(p0, p1, p2, p3, n=60):
    return [sample_bezier(p0, p1, p2, p3, i / n) for i in range(n + 1)]


def draw_thick_path(size, points, width, t_fn):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.line(points, fill=255, width=width, joint="curve")

    colored = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cp = colored.load()
    mp = mask.load()

    # approximate arc length for gradient
    lengths = [0.0]
    for i in range(1, len(points)):
        lengths.append(lengths[-1] + math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1]))
    total = lengths[-1] or 1

    for y in range(size):
        for x in range(size):
            a = mp[x, y]
            if a == 0:
                continue
            # nearest point on polyline
            best_d = 1e9
            best_t = 0.0
            for i in range(len(points) - 1):
                x0, y0 = points[i]
                x1, y1 = points[i + 1]
                dx, dy = x1 - x0, y1 - y0
                seg = dx * dx + dy * dy
                if seg == 0:
                    continue
                proj = max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / seg))
                px, py = x0 + proj * dx, y0 + proj * dy
                d = (x - px) ** 2 + (y - py) ** 2
                if d < best_d:
                    best_d = d
                    best_t = (lengths[i] + proj * math.sqrt(seg)) / total
            r, g, b = gradient_at(t_fn(best_t))
            cp[x, y] = (r, g, b, int(a * 0.94))

    return colored, mask


def draw_glass_sphere(size, center, radius, t_center=0.2):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    cx, cy = center
    md.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=255)

    colored = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cp = colored.load()
    mp = mask.load()
    for y in range(size):
        for x in range(size):
            a = mp[x, y]
            if a == 0:
                continue
            nx = (x - cx) / radius
            ny = (y - cy) / radius
            dist = math.hypot(nx, ny)
            if dist > 1:
                continue
            # faux-3D sphere shading
            nz = math.sqrt(max(0, 1 - dist * dist))
            shade = 0.55 + 0.45 * (nx * -0.35 + ny * -0.55 + nz * 0.85)
            r, g, b = gradient_at(t_center + shade * 0.18)
            cp[x, y] = (r, g, b, int(a * 0.90))

    # specular
    spec = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spec)
    hx, hy = cx - radius * 0.32, cy - radius * 0.38
    sd.ellipse([hx - radius * 0.2, hy - radius * 0.14, hx + radius * 0.2, hy + radius * 0.14],
               fill=(255, 255, 255, 110))
    colored = Image.alpha_composite(
        colored,
        Image.composite(spec, Image.new("RGBA", (size, size), (0, 0, 0, 0)), mask),
    )
    return colored, mask


def add_soft_sheen(rgba, mask):
    sheen = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    w, h = rgba.size
    sd.ellipse([w * 0.18, h * 0.10, w * 0.62, h * 0.55], fill=(255, 255, 255, 28))
    sheen = sheen.filter(ImageFilter.GaussianBlur(radius=28))
    return Image.alpha_composite(rgba, Image.composite(sheen, Image.new("RGBA", rgba.size, (0, 0, 0, 0)), mask))


def build_icon():
    s = SIZE
    cx = s * 0.5
    bg = make_background(s).convert("RGBA")

    pole = [(cx, s * 0.74), (cx, s * 0.24)]
    pole_layer, pole_mask = draw_thick_path(s, pole, int(s * 0.052), lambda t: t * 0.35)

    # Smooth glass flag ribbon
    p0 = (cx, s * 0.24)
    p1 = (cx + s * 0.14, s * 0.18)
    p2 = (cx + s * 0.34, s * 0.28)
    p3 = (cx + s * 0.36, s * 0.40)
    top = bezier_points(p0, p1, p2, p3)

    p0b = (cx + s * 0.36, s * 0.40)
    p1b = (cx + s * 0.20, s * 0.46)
    p2b = (cx + s * 0.06, s * 0.42)
    p3b = (cx, s * 0.34)
    bottom = bezier_points(p0b, p1b, p2b, p3b)
    flag_path = top + bottom + [top[0]]

    flag_layer, flag_mask = draw_thick_path(s, flag_path, int(s * 0.040), lambda t: 0.35 + t * 0.55)

    ball_layer, ball_mask = draw_glass_sphere(s, (cx, s * 0.80), int(s * 0.072))

    glass = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    for layer in (pole_layer, flag_layer, ball_layer):
        glass = Image.alpha_composite(glass, layer)

    combined_mask = Image.new("L", (s, s), 0)
    for m in (pole_mask, flag_mask, ball_mask):
        combined_mask = Image.composite(m, combined_mask, m)
    glass = add_soft_sheen(glass, combined_mask)

    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([cx - s * 0.16, s * 0.83, cx + s * 0.16, s * 0.88], fill=(130, 148, 168, 38))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=12))

    result = Image.alpha_composite(bg, shadow)
    result = Image.alpha_composite(result, glass)
    return result.convert("RGB")


def main():
    icon = build_icon()
    out_path = os.path.abspath(OUT)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    icon.save(out_path, "PNG", optimize=True)
    print(f"Saved {out_path} ({icon.size[0]}x{icon.size[1]})")


if __name__ == "__main__":
    main()
