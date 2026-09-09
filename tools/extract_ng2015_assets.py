#!/usr/bin/env python3
"""
Извлекает UI-ассеты темы Newgrounds 2015 из локального архива проекта ng2015
в assets/ng2015/ этого Flutter-проекта.

Источник: F:/vapecoding/ng2015/ng2015_archive/_home_local/cssimg/
(путь можно переопределить первым аргументом)

Спрайты режутся на отдельные PNG, потому что Flutter не умеет
background-position, а рисовать оффсеты руками в каждом виджете — шум.

Запуск:  python tools/extract_ng2015_assets.py
Нужен:   pillow
"""

import os
import sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else \
    "F:/vapecoding/ng2015/ng2015_archive/_home_local/cssimg"
DST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "ng2015")

# ── спрайт h2-all.png: 31x1519, 49 плиток 31x31 (иконки заголовков подов) ──────
H2 = {
    1: "info",     2: "user",    3: "users",    4: "gear",     5: "link",
    8: "gamepad",  9: "film",   10: "audio",   11: "palette", 12: "quill",
    14: "flag",   15: "star",   16: "heart",   18: "dollar",  19: "question",
    24: "folder",  25: "grid",  27: "list",    28: "frame",   29: "doc",
    30: "mail",   31: "trophy", 32: "puzzle",  35: "badge",   36: "pico",
    37: "skull",  38: "speech", 39: "rss",     40: "download",
    41: "upload", 42: "search", 43: "power",   44: "check",
}

# ── спрайт a-15yellows.png: 615x30, 41 плитка 15x15; ряд 0 — жёлтый, ряд 1 — тёмный
A15 = {
    2: "arrow-left",  3: "arrow-right", 4: "add",        5: "trash",
    11: "save",      14: "expand",     15: "collapse",  16: "fav-on",
    17: "fav-add",   19: "link",       20: "flag",      23: "close",
    25: "download",  26: "pencil",     27: "refresh",   32: "power",
    33: "user-add",  34: "gear",       36: "star",      37: "playlist",
    39: "key",       40: "menu",
}

# ── простое копирование/конвертация текстур: (источник, приёмник) ──────────────
TEX = [
    ("bg-skins/podtops/podtop-gold.jpg",  "tex/podtop-gold.jpg"),
    ("bg-skins/podtops/podtop-green.jpg", "tex/podtop-green.jpg"),
    ("bg-skins/podtops/podtop-blue.jpg",  "tex/podtop-blue.jpg"),
    ("bg-skins/podtops/podtop-red.jpg",   "tex/podtop-red.jpg"),
    ("bg-skins/podtops/podtop-pink.jpg",  "tex/podtop-pink.jpg"),
    ("bg-main/podbreaker-33.jpg",         "tex/podbreaker.jpg"),
    ("bg-main/pod-33.jpg",                "tex/pod-body.jpg"),
    ("bg-skins/inputs/input-gold.jpg",    "tex/input-gold.jpg"),
    ("bg-header/navbar2014.jpg",          "tex/navbar.jpg"),
    ("bg-header/logo.png",                "logo.png"),
    ("bg-footer/logo-tiny.png",           "logo-tiny.png"),
    ("defaults/icon-audio-smallest.png",  "icon-audio-default.png"),
]

# gif/индексированные → png (Flutter корректнее ест png)
TEX_PNG = [
    ("bg-skins/gold2-body.gif",  "tex/body-gold.png"),
    ("bg-skins/green2-body.gif", "tex/body-green.png"),
    ("bg-main/podstripe.gif",    "tex/podstripe.png"),
    ("bg-footer/a-stripes.png",  "tex/footer-stripes.png"),
    ("bg-header/navigationTop.png", "tex/nav-top.png"),
]


def out(rel):
    p = os.path.join(DST, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def src(rel):
    return os.path.join(SRC, rel.replace("/", os.sep))


def cut(img, box, dest):
    img.crop(box).save(out(dest))


def main():
    if not os.path.isdir(SRC):
        sys.exit(f"нет каталога с ассетами: {SRC}")

    n = 0

    for a, b in TEX:
        p = src(a)
        if not os.path.exists(p):
            print("  skip", a)
            continue
        Image.open(p).save(out(b))
        n += 1

    for a, b in TEX_PNG:
        p = src(a)
        if not os.path.exists(p):
            print("  skip", a)
            continue
        Image.open(p).convert("RGBA").save(out(b))
        n += 1

    # иконки заголовков подов
    sprite = Image.open(src("icons/h2-all.png")).convert("RGBA")
    for idx, name in H2.items():
        cut(sprite, (0, idx * 31, 31, idx * 31 + 31), f"h2/{name}.png")
        n += 1

    # мелкие иконки действий, два состояния
    sprite = Image.open(src("icons/a-15yellows.png")).convert("RGBA")
    for idx, name in A15.items():
        cut(sprite, (idx * 15, 0, idx * 15 + 15, 15), f"a15/{name}.png")
        cut(sprite, (idx * 15, 15, idx * 15 + 15, 30), f"a15/{name}-dark.png")
        n += 2

    # полоски-плашки для ссылок в шапке пода (More Audio »)
    sprite = Image.open(src("misc/link_stripes2.png")).convert("RGBA")
    cut(sprite, (0, 0, 300, 27), "tex/link-plate.png")
    cut(sprite, (300, 0, 600, 27), "tex/link-plate-hover.png")
    n += 2

    # кнопки: 2 колонки x 3 ряда по 66x25 (обычная / наведение / выключенная)
    sprite = Image.open(src("bg-skins/buttons/button-gold.gif")).convert("RGBA")
    for row, name in enumerate(["normal", "hover", "disabled"]):
        cut(sprite, (0, row * 25, 66, row * 25 + 25), f"tex/button-{name}.png")
        n += 1

    # звёзды рейтинга: 5 штук в полосе 87x15, пустая и заполненная
    sprite = Image.open(src("misc/vp-Stars.png")).convert("RGBA")
    cut(sprite, (0, 0, 87, 15), "stars-empty.png")
    cut(sprite, (0, 15, 87, 30), "stars-full.png")
    n += 2

    # лупа поиска: 4 скина по 25px, берём золотой
    sprite = Image.open(src("bg-header/search.png")).convert("RGBA")
    cut(sprite, (0, 0, 25, 25), "a15/magnifier.png")
    n += 1

    print(f"готово: {n} файлов в {DST}")


if __name__ == "__main__":
    main()
