"""Fit local Chinese speech to the promo timeline and mix original background music.

Input voice-NN.wav files are synthesized with Windows Microsoft Huihui Desktop.
The soundtrack is generated locally by build_promo_video.py, without third-party audio.
"""

import json
from pathlib import Path
import subprocess
import wave


ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "build/promo/audio"


def run(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *map(str, args)], check=True)


def main():
    scenes = json.loads((ROOT / "docs/video/promo-scenes.json").read_text(encoding="utf-8"))
    fitted = []
    report = []
    for index, scene in enumerate(scenes):
        source = AUDIO / f"voice-{index:02d}.wav"
        with wave.open(str(source)) as voice:
            duration = voice.getnframes() / voice.getframerate()
        slot = scene["end"] - scene["start"]
        tempo = max(1.0, duration / (slot - 0.4))
        destination = AUDIO / f"fitted-{index:02d}.wav"
        filters = (
            f"atempo={tempo:.8f},loudnorm=I=-17:TP=-2:LRA=7,"
            "aresample=48000,asetpts=PTS-STARTPTS,adelay=150:all=1,"
            f"apad=whole_len={slot * 48000},atrim=end_sample={slot * 48000},asetpts=N/SR/TB"
        )
        run("-i", source, "-af", filters, "-ar", "48000", "-ac", "2", "-c:a", "pcm_s16le", destination)
        fitted.append(destination)
        report.append({"scene": index, "voice_seconds": duration, "slot_seconds": slot, "tempo": tempo})
    inputs = [item for source in fitted for item in ("-i", source)]
    concat = "".join(f"[{index}:a]" for index in range(len(fitted)))
    concat += f"concat=n={len(fitted)}:v=0:a=1[a]"
    narration = AUDIO / "narration.wav"
    run(*inputs, "-filter_complex", concat, "-map", "[a]", "-c:a", "pcm_s16le", narration)
    total = scenes[-1]["end"]
    mix = (
        "[1:a]volume=0.80[bg];"
        "[0:a][bg]amix=inputs=2:duration=first:normalize=0,"
        f"alimiter=limit=0.95,afade=t=in:st=0:d=0.12,afade=t=out:st={total - 0.5}:d=0.5[a]"
    )
    run("-i", narration, "-i", AUDIO / "music.wav", "-filter_complex", mix, "-map", "[a]", "-t", total, "-ar", "48000", "-ac", "2", "-c:a", "pcm_s16le", AUDIO / "mix.wav")
    (AUDIO / "audio-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"seconds": total, "narration": str(narration), "mix": str(AUDIO / "mix.wav"), "scenes": report}, ensure_ascii=False))


if __name__ == "__main__":
    main()
