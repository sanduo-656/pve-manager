"""Build PVE Manager's original music, cover, and 1080p promo from emulator footage.

Requires Pillow, NumPy, ffmpeg and ffprobe. Inputs are local, and all recording
segments are explicitly presented as demonstration data. No external assets
or music services are used.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import wave
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build" / "promo"
WIDTH, HEIGHT, FPS = 1920, 1080, 30
BLUE = "#3448C8"
INK = "#172239"
MUTED = "#68758C"
FONT_PATH = ROOT / "assets" / "fonts" / "NotoSansSC.ttf"
ICON_PATH = ROOT / "assets" / "branding" / "pve-manager-icon.png"
PHONE_X, PHONE_Y, PHONE_W, PHONE_H = 1332, 56, 424, 917


def execute(arguments: list[str | Path], *, cwd: Path = WORK) -> None:
    command = [str(value) for value in arguments]
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                            encoding="utf-8", errors="replace")
    if result.returncode:
        raise RuntimeError(f"Command failed: {command[0]}\n{result.stderr[-7000:]}")


def probe(path: Path) -> dict:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)],
        capture_output=True, text=True, encoding="utf-8", errors="replace", check=True,
    )
    return json.loads(result.stdout)


def font(size: int, weight: int = 500) -> ImageFont.FreeTypeFont:
    result = ImageFont.truetype(str(FONT_PATH), size)
    try:
        result.set_variation_by_axes([weight])
    except (AttributeError, OSError, ValueError):
        pass
    return result


def text_lines(text: str, typeface: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines, current = [], ""
    for paragraph in text.split("\n"):
        current = ""
        for character in paragraph:
            if current and typeface.getlength(current + character) > width:
                lines.append(current.rstrip())
                current = character.lstrip()
            else:
                current += character
        lines.append(current.rstrip())
    return lines


def wrapped(draw: ImageDraw.ImageDraw, text: str, position: tuple[int, int], *,
            size: int, width: int, fill: str = INK, weight: int = 650,
            spacing: int = 12) -> int:
    typeface = font(size, weight)
    y = position[1]
    for line in text_lines(text, typeface, width):
        draw.text((position[0], y), line, font=typeface, fill=fill,
                  anchor="lt", stroke_width=0)
        y += size + spacing
    return y


def rounded_icon(image: Image.Image, position: tuple[int, int], size: int) -> None:
    icon = Image.open(ICON_PATH).convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=size // 5, fill=255)
    image.paste(icon, position, mask)


def base_canvas() -> Image.Image:
    yy, xx = np.mgrid[0:HEIGHT, 0:WIDTH]
    glow = np.exp(-((xx - 1510) ** 2 / (620 ** 2) + (yy - 450) ** 2 / (610 ** 2)))
    colors = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    for channel, (start, delta) in enumerate(((248, 14), (250, 14), (255, 3))):
        colors[:, :, channel] = np.clip(start - delta * glow, 0, 255)
    image = Image.fromarray(colors)
    draw = ImageDraw.Draw(image)
    draw.line((120, 955, 1185, 955), fill="#DEE4F2", width=2)
    draw.text((120, 978), "PVE 管家  /  中文 Android 客户端", font=font(25), fill=MUTED)
    shadow = Image.new("RGBA", (WIDTH, HEIGHT))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((1308, 46, 1780, 1005), radius=50, fill=(40, 53, 120, 47))
    image = Image.alpha_composite(image.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(22)))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((1318, 40, 1770, 989), radius=42, fill="#FFFFFF", outline="#CED7EA", width=2)
    draw.rounded_rectangle((PHONE_X - 2, PHONE_Y - 2, PHONE_X + PHONE_W + 2, PHONE_Y + PHONE_H + 2),
                           radius=29, fill="#FFFFFF", outline="#E5E9F3", width=2)
    draw.rounded_rectangle((1692, 18, 1882, 65), radius=22, fill="#E9EDFA")
    draw.text((1787, 41), "演示数据", font=font(23, 550), fill=BLUE, anchor="mm")
    return image


SCENE_CONTENT = [
    {"heading": "无需 Google Play\n直接装 APK", "eyebrow": "PVE 管家  v0.4.2+7",
     "features": ["不依赖 Google Play 服务", "不用谷歌账号", "手机查看资源与节点监控"],
     "note": "Android 7.0+  ·  测试体验版"},
    {"heading": "资源，一眼看清", "eyebrow": "01  /  资源概览",
     "features": ["虚拟机与 LXC 容器统一列表", "状态、CPU 和内存", "多个服务器连接快速切换"],
     "note": "管理 Proxmox VE 的日常资源"},
    {"heading": "常用操作\n触手可及", "eyebrow": "02  /  资源详情",
     "features": ["开机、正常关机与重启", "跟踪 PVE 任务结果", "noVNC / xterm.js 控制台入口"],
     "note": "画面使用模拟数据；操作演示中取消确认"},
    {"heading": "宿主机\n也能掌握", "eyebrow": "03  /  节点监控",
     "features": ["CPU、内存、根分区与网络", "系统负载与 Swap", "PVE 存储容量与可用状态"],
     "note": "使用 PVE 自带接口，前台查看时更新"},
    {"heading": "趋势与容量\n一起查看", "eyebrow": "04  /  历史趋势",
     "features": ["从 1 小时到 1 年", "接收与发送趋势", "根分区与存储容量"],
     "note": "网络：节点汇总 RRD 采样\n磁盘：根分区与 PVE 存储容量"},
    {"heading": "登录\n清晰直接", "eyebrow": "05  /  登录与连接",
     "features": ["HTTPS 与证书指纹确认", "支持 TOTP 动态验证码", "默认端口 8006，认证域 pam"],
     "note": "端口与认证域放在可展开的高级设置"},
    {"heading": "欢迎下载\n测试体验", "eyebrow": "PVE 管家  v0.4.2+7",
     "features": ["Android 7.0 及以上", "直接下载安装包", "通过 GitHub Issues 提交反馈"],
     "note": "真实 PVE 环境仍需进一步验证"},
    {"heading": "下载 PVE 管家", "eyebrow": "GitHub  /  源码与 APK",
     "features": ["无需 Google Play 服务", "v0.4.2+7  ·  测试体验版", "GitHub Releases 下载 APK"],
     "note": "github.com/sanduo-656/pve-manager"},
]


def scene_background(index: int, output: Path) -> None:
    image = base_canvas()
    draw = ImageDraw.Draw(image)
    content = SCENE_CONTENT[index]
    rounded_icon(image, (120, 86), 96)
    draw.text((242, 109), content["eyebrow"], font=font(29, 600), fill=BLUE)
    title_size = 75 if index == 0 else 78
    y = wrapped(draw, content["heading"], (120, 263), size=title_size, width=1080, spacing=20)
    y += 46
    for feature in content["features"]:
        draw.ellipse((123, y + 12, 135, y + 24), fill=BLUE)
        y = wrapped(draw, feature, (158, y), size=35, width=1040, weight=450, spacing=8) + 25
    note_size = 30 if index == 7 else 24
    wrapped(draw, content["note"], (120, 848), size=note_size, width=1120,
            fill=BLUE if index == 7 else MUTED, weight=550, spacing=7)
    image.convert("RGB").save(output)


def timestamp(value: float) -> str:
    centiseconds = round(value * 100)
    return f"{centiseconds // 360000}:{centiseconds // 6000 % 60:02d}:{centiseconds // 100 % 60:02d}.{centiseconds % 100:02d}"


def parse_subtitles(path: Path) -> list[tuple[float, float, str]]:
    captions = []
    for block in path.read_text(encoding="utf-8-sig").strip().split("\n\n"):
        lines = block.strip().splitlines()
        if len(lines) < 3:
            continue
        def seconds(stamp: str) -> float:
            parts = stamp.replace(",", ".").split(":")
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
        start, end = lines[1].split(" --> ")
        captions.append((seconds(start), seconds(end), "\\N".join(lines[2:])))
    return captions


def write_ass(captions: list[tuple[float, float, str]], path: Path,
              start: float = 0, end: float = 70) -> None:
    lines = [
        "[Script Info]", "ScriptType: v4.00+", "PlayResX: 1920", "PlayResY: 1080", "WrapStyle: 2",
        "", "[V4+ Styles]",
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
        "Style: Caption,Noto Sans SC,38,&H002B2117,&H002B2117,&H00FFFFFF,&H66FFFFFF,0,0,0,0,100,100,0,0,1,3,0,2,65,65,17,1",
        "", "[Events]", "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
    ]
    for caption_start, caption_end, text in captions:
        a, b = max(start, caption_start), min(end, caption_end)
        if b > a:
            lines.append(f"Dialogue: 0,{timestamp(a-start)},{timestamp(b-start)},Caption,,0,0,0,,{{\\fad(100,100)}}{text}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8-sig")


def synthesize_music(output: Path, duration: float = 70) -> dict:
    rate = 48000
    count = round(rate * duration)
    sound = np.zeros((count, 2), dtype=np.float64)
    chords = [[48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 55, 60]]
    for index in range(math.ceil(duration / 8)):
        notes = chords[index % 4]
        start = index * 8.0
        length = min(9, duration - start)
        size = int(length * rate)
        time = np.arange(size) / rate
        envelope = np.clip(np.minimum(time / 1.5, 1) * np.minimum((length - time) / 2.3, 1), 0, 1)
        for j, note in enumerate(notes):
            frequency = 440 * 2 ** ((note - 69) / 12)
            pan = (-.55, .45, -.2, .2)[j]
            tone = (np.sin(2 * np.pi * frequency * time)
                    + .17 * np.sin(2 * np.pi * frequency * 2 * time)
                    + .04 * np.sin(2 * np.pi * frequency * 3 * time)) * .0065
            tone *= envelope * (.94 + .06 * np.sin(2 * np.pi * .08 * time + j))
            stereo = np.column_stack((tone * np.sqrt((1-pan)/2), tone * np.sqrt((1+pan)/2)))
            at = int(start * rate)
            sound[at:at + size] += stereo
        melody = [notes[2] + 12, notes[3] + 12, notes[1] + 12, notes[2] + 12]
        for step, note in enumerate(melody):
            at = start + .55 + step * 1.55
            length = min(2.7, duration - at)
            if length <= 0:
                continue
            size = int(length * rate)
            time = np.arange(size) / rate
            frequency = 440 * 2 ** ((note - 69) / 12)
            envelope = (1 - np.exp(-time * 95)) * np.exp(-time * 2)
            tone = (np.sin(2 * np.pi * frequency * time) + .2 * np.sin(2 * np.pi * 2 * frequency * time)) * envelope * .028
            pan = (-.45, .45, -.25, .3)[step]
            stereo = np.column_stack((tone * np.sqrt((1-pan)/2), tone * np.sqrt((1+pan)/2)))
            sample = int(at * rate)
            sound[sample:sample + size] += stereo
            delay = int(.3 * rate)
            available = min(size, count - sample - delay)
            if available > 0:
                sound[sample + delay:sample + delay + available] += stereo[:available, ::-1] * .16
    fade = np.minimum(np.arange(count) / (rate * 2), 1) * np.minimum((count - np.arange(count)) / (rate * 3), 1)
    sound *= fade[:, None]
    peak = np.max(np.abs(sound))
    if peak:
        sound *= .14 / peak
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes((np.clip(sound, -1, 1) * 32767).astype("<i2").tobytes())
    return {"path": str(output), "duration": duration, "sampleRate": rate, "channels": 2,
            "peak": float(np.max(np.abs(sound))), "rms": float(np.sqrt(np.mean(sound**2))),
            "source": "original synthesized pads and plucks; no third-party samples"}


def cue_ranges(cue_path: Path, duration: float, offset_override: float | None) -> tuple[list[tuple[float, float]], float]:
    metadata = json.loads(cue_path.read_text(encoding="utf-8-sig"))
    cues = {cue["id"]: cue for cue in metadata["cues"]}
    if offset_override is None:
        start = datetime.fromisoformat(metadata["recordingStartUtc"].replace("Z", "+00:00"))
        ready = datetime.fromisoformat(cues["ready"]["utc"].replace("Z", "+00:00"))
        offset = max(0, (ready - start).total_seconds())
    else:
        offset = offset_override
    def point(name: str) -> float:
        return min(duration - .1, offset + cues[name]["milliseconds"] / 1000)
    pairs = [("ready", "home"), ("home", "resource"), ("resource", "nodes"),
             ("nodes", "history"), ("history", "connections"), ("login", "end_home"),
             ("ready", "home"), ("ready", "home")]
    return [(point(a), max(point(a) + .1, point(b))) for a, b in pairs], offset


def make_cover(raw: Path | None, output: Path) -> None:
    image = base_canvas()
    draw = ImageDraw.Draw(image)
    # Cover uses the same large, readable phone panel as the video.
    still = WORK / "cover-phone.png"
    if raw is not None and raw.exists():
        execute(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "5.5", "-i", raw,
                 "-frames:v", "1", still])
    else:
        still = ROOT / "docs" / "screenshots" / "resource_home_demo.png"
    screenshot = Image.open(still).convert("RGB")
    screenshot = ImageOps.fit(screenshot, (PHONE_W, PHONE_H), method=Image.Resampling.LANCZOS)
    mask = Image.new("L", (PHONE_W, PHONE_H))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, PHONE_W-1, PHONE_H-1), radius=27, fill=255)
    image.paste(screenshot, (PHONE_X, PHONE_Y), mask)
    rounded_icon(image, (120, 74), 164)
    draw.text((318, 120), "PVE 管家", font=font(52, 700), fill=BLUE)
    wrapped(draw, "无需 Google Play", (120, 330), size=91, width=1160, weight=800)
    wrapped(draw, "手机，也能管 PVE", (120, 459), size=76, width=1160, weight=700)
    draw.rounded_rectangle((120, 622, 1108, 713), radius=24, fill=BLUE)
    draw.text((155, 644), "下载 APK 直接安装 · 不用谷歌账号", font=font(41, 600), fill="#FFFFFF")
    draw.text((122, 772), "资源管理  ·  节点监控", font=font(43, 550), fill=INK)
    draw.text((122, 849), "v0.4.2+7   /   Android 7.0+   /   测试体验版", font=font(29, 500), fill=MUTED)
    output.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(output)


def render(raw: Path, cues: Path, audio: Path, output: Path, scenes: list[dict],
           cue_offset: float | None, preset: str, start_scene: int = 0) -> None:
    raw_metadata = probe(raw)
    ranges, offset = cue_ranges(cues, float(raw_metadata["format"]["duration"]), cue_offset)
    captions = parse_subtitles(ROOT / "docs/video/pve-manager-subtitles.srt")
    segments = WORK / "segments"
    segments.mkdir(parents=True, exist_ok=True)
    mask_path = WORK / "phone-mask.png"
    mask = Image.new("L", (PHONE_W, PHONE_H))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, PHONE_W-1, PHONE_H-1), radius=27, fill=255)
    mask.save(mask_path)
    plan = []
    for index, scene in enumerate(scenes):
        duration = float(scene["end"] - scene["start"])
        source_start, source_end = ranges[index]
        source_duration = source_end - source_start
        background = WORK / f"background-{index:02}.png"
        ass_path = WORK / f"captions-{index:02}.ass"
        segment = segments / f"scene-{index:02}.mp4"
        plan.append({"scene": index, "start": scene["start"], "end": scene["end"],
                     "sourceStart": source_start, "sourceEnd": source_end, "speed": source_duration/duration})
        if index < start_scene:
            if not segment.exists():
                raise FileNotFoundError(f"Cannot resume without {segment}")
            continue
        scene_background(index, background)
        write_ass(captions, ass_path, scene["start"], scene["end"])
        factor = duration / source_duration
        # A very small background push and short edge fades add motion while
        # keeping the application text at its full readable display size.
        filter_graph = (
            f"[0:v]fps={FPS},zoompan=z='1+0.0015*on/{round(duration*FPS)}':"
            f"x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s={WIDTH}x{HEIGHT}:fps={FPS},"
            f"trim=duration={duration},setpts=PTS-STARTPTS[card];"
            f"[1:v]setpts=(PTS-STARTPTS)*{factor:.9f},fps={FPS},"
            f"scale={PHONE_W}:{PHONE_H}:force_original_aspect_ratio=decrease:flags=lanczos,"
            f"pad={PHONE_W}:{PHONE_H}:(ow-iw)/2:(oh-ih)/2:color=white,setsar=1,"
            f"tpad=stop_mode=clone:stop_duration={duration},trim=duration={duration},format=rgb24[screen];"
            "[screen][2:v]alphamerge[phone];"
            f"[card][phone]overlay={PHONE_X}:{PHONE_Y}:shortest=1:format=auto,"
            f"subtitles=filename={ass_path.name}:fontsdir=../../assets/fonts,"
            f"fade=t=in:st=0:d=0.14:color=0xF8FAFF,"
            f"fade=t=out:st={duration-.14:.3f}:d=0.14:color=0xF8FAFF,format=yuv420p[out]"
        )
        execute(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-loop", "1", "-i", background,
                 "-ss", f"{source_start:.6f}", "-t", f"{source_duration:.6f}", "-i", raw,
                 "-loop", "1", "-i", mask_path, "-filter_complex_threads", "1",
                 "-filter_complex", filter_graph, "-map", "[out]", "-an", "-t", str(duration),
                 "-c:v", "libx264", "-preset", preset, "-crf", "18", "-pix_fmt", "yuv420p",
                 "-r", str(FPS), "-video_track_timescale", "15360", "-movflags", "+faststart", segment])
        print(f"Rendered scene {index+1}/{len(scenes)}", flush=True)
    playlist = WORK / "segments.txt"
    playlist.write_text("\n".join(f"file 'segments/scene-{index:02}.mp4'" for index in range(len(scenes))) + "\n", encoding="ascii")
    output.parent.mkdir(parents=True, exist_ok=True)
    total = scenes[-1]["end"]
    execute(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0",
             "-i", playlist, "-i", audio, "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy",
             "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", "-t", str(total),
             "-movflags", "+faststart", output])
    (WORK / "render-plan.json").write_text(json.dumps({"cueOffset": offset, "scenes": plan}, ensure_ascii=False, indent=2), encoding="utf-8")
    create_contact_sheet(output, scenes)
    final_metadata = probe(output)
    (WORK / "video-metadata.json").write_text(json.dumps(final_metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Video ready: {output}", flush=True)


def create_contact_sheet(video: Path, scenes: list[dict]) -> None:
    preview_dir = WORK / "qa"
    preview_dir.mkdir(exist_ok=True)
    sheet = Image.new("RGB", (1920, math.ceil(len(scenes) / 2) * 627), "#E9EDF7")
    draw = ImageDraw.Draw(sheet)
    for index, scene in enumerate(scenes):
        at = (scene["start"] + scene["end"]) / 2
        path = preview_dir / f"frame-{index:02}.png"
        execute(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(at), "-i", video,
                 "-frames:v", "1", path])
        frame = Image.open(path).convert("RGB").resize((960, 540), Image.Resampling.LANCZOS)
        x, y = (index % 2) * 960, (index // 2) * 627
        sheet.paste(frame, (x, y))
        draw.text((x+20, y+550), f"{index+1:02}  {at:.1f}s  {SCENE_CONTENT[index]['eyebrow']}", font=font(24), fill=INK)
    sheet.save(WORK / "contact-sheet.png")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--music-only", action="store_true")
    parser.add_argument("--prepare", action="store_true", help="Create cover and scene backgrounds without rendering")
    parser.add_argument("--raw", type=Path, default=WORK / "raw" / "pve_manager_walkthrough.mp4")
    parser.add_argument("--cues", type=Path, default=WORK / "raw" / "promo_cues.json")
    parser.add_argument("--audio", type=Path, default=WORK / "audio" / "mix.wav")
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "PVE-Manager-0.4.2+7-promo-1080p.mp4")
    parser.add_argument("--cue-offset", type=float)
    parser.add_argument("--start-scene", type=int, default=0, help="Reuse earlier rendered segments after visual QA")
    parser.add_argument("--preset", default="fast", choices=("ultrafast", "veryfast", "fast", "medium", "slow"))
    args = parser.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    scenes = json.loads((ROOT / "docs/video/promo-scenes.json").read_text(encoding="utf-8-sig"))
    if args.music_only:
        print(json.dumps(synthesize_music(WORK / "audio" / "music.wav", scenes[-1]["end"]), ensure_ascii=False))
        return
    for index in range(len(scenes)):
        scene_background(index, WORK / f"background-{index:02}.png")
    make_cover(args.raw if args.raw.exists() else None, ROOT / "docs" / "video" / "pve-manager-cover.png")
    if args.prepare:
        print("Cover and backgrounds ready")
        return
    if not args.raw.exists() or not args.audio.exists():
        raise FileNotFoundError("Recording and mixed audio must exist before rendering")
    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        raise FileNotFoundError("ffmpeg and ffprobe must be available on PATH")
    if not 0 <= args.start_scene < len(scenes):
        raise ValueError("Start scene must be within the scene list")
    render(args.raw, args.cues, args.audio, args.output, scenes, args.cue_offset, args.preset, args.start_scene)


if __name__ == "__main__":
    main()
