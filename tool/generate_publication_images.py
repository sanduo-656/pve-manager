"""Compose publication artwork from real Flutter screenshots and local fonts.

Run the publication_capture_test.dart fixture first. Every displayed metric is
synthetic; the generator never reads connections, accounts or credentials.
"""

from functools import lru_cache
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
VERSION = re.search(r"(?m)^version:\s*(\S+)", (ROOT / "pubspec.yaml").read_text(encoding="utf-8")).group(1)
DISPLAY_VERSION = VERSION.split("+")[0]
OUT = ROOT / "docs" / "images"
SHOTS = ROOT / "docs" / "screenshots"
NAVY = "#172239"
BLUE = "#3448C8"
MUTED = "#68758C"
BG = "#F5F7FC"


@lru_cache(maxsize=80)
def font(size, weight=400):
    result = ImageFont.truetype(str(ROOT / "assets/fonts/NotoSansSC.ttf"), size)
    result.set_variation_by_axes([weight])
    return result


def text(canvas, xy, value, size=28, color=NAVY, weight=400):
    ImageDraw.Draw(canvas).text(xy, value, font=font(size, weight), fill=color)


def surface(canvas, box, radius=24, fill="white", stroke="#E2E7F0", shadow=0):
    if shadow:
        layer = Image.new("RGBA", canvas.size)
        d = ImageDraw.Draw(layer)
        offset = (box[0], box[1] + 10, box[2], box[3] + 10)
        d.rounded_rectangle(offset, radius, fill=(42, 62, 108, shadow))
        canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(18)))
    ImageDraw.Draw(canvas).rounded_rectangle(box, radius, fill=fill, outline=stroke, width=2)


def raster(canvas, image, position, width, radius=22, shadow=24):
    height = round(image.height * width / image.width)
    image = image.convert("RGBA").resize((width, height), Image.Resampling.LANCZOS)
    mask = Image.new("L", image.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width, height), radius, fill=255)
    background = Image.new("RGBA", image.size, "white")
    background.alpha_composite(image)
    background.putalpha(mask)
    x, y = position
    surface(canvas, (x, y, x + width, y + height), radius, shadow=shadow)
    canvas.alpha_composite(background, position)
    ImageDraw.Draw(canvas).rounded_rectangle((x, y, x + width, y + height), radius, outline="#DCE3EF", width=2)
    return height


def phone(canvas, name, position, width):
    shot = Image.open(SHOTS / name)
    x, y = position
    height = round(shot.height * width / shot.width)
    surface(canvas, (x - 9, y - 9, x + width + 9, y + height + 9), 34, fill="#DDE4F2", stroke="#DDE4F2", shadow=35)
    raster(canvas, shot, position, width, radius=27, shadow=0)


def feature(canvas, box, index, title, detail):
    surface(canvas, box, 22, shadow=12)
    x, y, _, _ = box
    ImageDraw.Draw(canvas).rounded_rectangle((x + 25, y + 27, x + 73, y + 75), 14, fill="#E9EDFF")
    text(canvas, (x + 37, y + 30), index, 23, BLUE, 700)
    text(canvas, (x + 92, y + 25), title, 31, NAVY, 600)
    text(canvas, (x + 25, y + 96), detail, 23, MUTED)


def overview():
    result = Image.new("RGBA", (1920, 1080), BG)
    d = ImageDraw.Draw(result)
    d.ellipse((1260, -260, 2300, 780), fill="#E8EDFF")
    d.ellipse((980, 540, 2050, 1610), fill="#EDF5F8")
    surface(result, (82, 78, 485, 132), 27, fill="#E8EDFF", stroke="#E8EDFF")
    text(result, (106, 83), "ANDROID · PROXMOX VE", 23, BLUE, 600)
    text(result, (78, 154), "PVE 管家", 91, NAVY, 700)
    surface(result, (572, 190, 790, 248), 18, fill=BLUE, stroke=BLUE)
    text(result, (601, 189), f"v{DISPLAY_VERSION}", 37, "white", 600)
    text(result, (83, 292), "把你的 PVE 带进口袋", 44, NAVY, 600)
    text(result, (85, 371), "虚拟机、容器与宿主节点", 29, MUTED)
    text(result, (85, 418), "在 Android 手机上统一查看与管理。", 29, MUTED)
    feature(result, (83, 526, 497, 700), "01", "资源一览", "虚拟机 / LXC 状态、CPU、内存")
    feature(result, (520, 526, 934, 700), "02", "主机监控", "CPU、内存、根分区与网络历史")
    feature(result, (83, 728, 497, 902), "03", "日常管理", "启停、重启、控制台与任务反馈")
    feature(result, (520, 728, 934, 902), "04", "安全连接", "HTTPS、证书验证、TOTP 认证")
    phone(result, "resource_home_demo.png", (1060, 164), 350)
    phone(result, "node_monitoring_demo.png", (1480, 214), 350)
    text(result, (1140, 1001), "资源总览", 26, MUTED, 500)
    text(result, (1561, 1001), "宿主节点", 26, MUTED, 500)
    text(result, (86, 968), f"Android 7.0+  ·  版本 {VERSION}", 23, MUTED, 500)
    text(result, (86, 1008), "所有截图均为固定演示数据", 21, MUTED)
    result.convert("RGB").save(OUT / "pve-manager-overview.png", optimize=True)


def monitoring():
    result = Image.new("RGBA", (1920, 1080), BG)
    d = ImageDraw.Draw(result)
    d.ellipse((1230, -560, 2380, 590), fill="#E9EDFF")
    text(result, (76, 49), f"PVE 管家 v{DISPLAY_VERSION} · 主机监控", 59, NAVY, 700)
    text(result, (80, 143), "节点资源与历史趋势，在手机上一起看清", 29, MUTED)
    source = Image.open(SHOTS / "node_monitoring_full_demo.png")
    text(result, (80, 216), "节点状态与存储用量", 28, BLUE, 600)
    raster(result, source.crop((0, 0, 576, 581)), (80, 270), 456, radius=20)
    raster(result, source.crop((0, 1655, 576, 1994)), (80, 744), 456, radius=20)
    text(result, (613, 216), "CPU / 内存历史", 28, BLUE, 600)
    raster(result, source.crop((0, 599, 576, 1201)), (613, 270), 576, radius=20)
    text(result, (1236, 216), "网络 / 根分区历史", 28, BLUE, 600)
    raster(result, source.crop((0, 1201, 576, 1637)), (1236, 270), 576, radius=20)
    surface(result, (1236, 742, 1812, 952), 22, fill="#E9EDFF", stroke="#DDE4FF")
    text(result, (1264, 763), "从 1 小时到 1 年", 32, BLUE, 600)
    text(result, (1264, 821), "CPU 使用率与 I/O 等待", 25, NAVY, 500)
    text(result, (1264, 864), "内存、网络与根分区历史趋势", 25, NAVY, 500)
    text(result, (1264, 907), "负载、Swap 与节点存储容量", 25, NAVY, 500)
    text(result, (614, 907), "基于 PVE 原生 RRD 汇总采样", 27, NAVY, 600)
    text(result, (614, 953), "缺失采样以断线显示，未知值保留为空。", 23, MUTED)
    text(result, (80, 1026), "演示数据 · 网络展示节点汇总采样，非逐网卡秒级速率 · 磁盘展示根分区与存储容量", 23, MUTED)
    result.convert("RGB").save(OUT / "pve-manager-monitoring.png", optimize=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    overview()
    monitoring()
    print("Generated docs/images/pve-manager-{overview,monitoring}.png")
