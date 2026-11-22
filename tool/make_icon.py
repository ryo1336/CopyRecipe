"""CopyRecipe のアプリアイコンを描く（Pillow が必要）。

使い方: python3 tool/make_icon.py assets/icon && dart run flutter_launcher_icons

icon.png            : iOS・Android 共通（背景込み、角丸なし）
icon_foreground.png : Android のアダプティブアイコンの前景（透明背景、図柄を 72% に縮めて中央に置く）
"""
import sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
N = 4096  # 4 倍で描いて縮小し、輪郭を滑らかにする
TOMATO = (217, 84, 30, 255)
LINE = (246, 196, 172, 255)
WHITE = (255, 255, 255, 255)


def draw_mark(d, scale, ox, oy):
    """白いレシピカードと再生ボタン。1024 基準の座標を scale 倍して描く"""
    s = lambda v: int(v * scale)
    # カード
    d.rounded_rectangle([ox + s(262), oy + s(196), ox + s(762), oy + s(828)],
                        radius=s(64), fill=WHITE)
    # 材料の行（点と線）
    for i, y in enumerate([330, 430, 530]):
        d.ellipse([ox + s(330), oy + s(y - 22), ox + s(374), oy + s(y + 22)], fill=TOMATO)
        width = [300, 250, 190][i]
        d.rounded_rectangle([ox + s(410), oy + s(y - 18), ox + s(410 + width), oy + s(y + 18)],
                            radius=s(18), fill=LINE)
    # 再生ボタン（カードの右下にかぶせる）
    cx, cy, r = 690, 730, 150
    d.ellipse([ox + s(cx - r - 28), oy + s(cy - r - 28), ox + s(cx + r + 28), oy + s(cy + r + 28)], fill=WHITE)
    d.ellipse([ox + s(cx - r), oy + s(cy - r), ox + s(cx + r), oy + s(cy + r)], fill=TOMATO)
    d.polygon([(ox + s(cx - 45), oy + s(cy - 75)), (ox + s(cx - 45), oy + s(cy + 75)),
               (ox + s(cx + 80), oy + s(cy))], fill=WHITE)


full = Image.new('RGBA', (N, N), TOMATO)
draw_mark(ImageDraw.Draw(full), N / 1024, 0, 0)
full.resize((1024, 1024), Image.LANCZOS).convert('RGB').save(f'{OUT}/icon.png')

# アダプティブアイコンは端が切り取られるので、図柄を 72% に縮めて中央に置く
fg = Image.new('RGBA', (N, N), (0, 0, 0, 0))
k = 0.72
draw_mark(ImageDraw.Draw(fg), N / 1024 * k, int(N * (1 - k) / 2), int(N * (1 - k) / 2))
fg.resize((1024, 1024), Image.LANCZOS).save(f'{OUT}/icon_foreground.png')
