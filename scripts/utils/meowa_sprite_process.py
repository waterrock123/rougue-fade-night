"""开发期离线拆帧与预览：不联网、不生成美术、不逐帧裁切，保持画布和透明度。"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageSequence


def save_new(image, path, **kwargs):
    path = Path(path)
    if path.exists():
        raise FileExistsError(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, **kwargs)


def sheet(images, labels, output, zoom=5, columns=5):
    width = max(image.width for image in images) * zoom
    height = max(image.height for image in images) * zoom
    preview = Image.new("RGB", (columns * (width + 12), math.ceil(len(images) / columns) * (height + 30)), "#253044")
    draw = ImageDraw.Draw(preview)
    for index, (image, label) in enumerate(zip(images, labels)):
        x = (index % columns) * (width + 12)
        y = (index // columns) * (height + 30)
        enlarged = image.convert("RGBA").resize((image.width * zoom, image.height * zoom), Image.Resampling.NEAREST)
        preview.paste(enlarged, (x + 6, y + 6), enlarged)
        draw.text((x + 6, y + height + 10), label, fill="white")
    save_new(preview, output)


def decode(source, output):
    output = Path(output)
    with Image.open(source) as animation:
        frames, durations = [], []
        for frame in ImageSequence.Iterator(animation):
            frames.append(frame.convert("RGBA").copy())
            durations.append(max(int(frame.info.get("duration", 100)), 1))
    if len(frames) < 2 or len({frame.size for frame in frames}) != 1:
        raise ValueError("Expected a real fixed-canvas animation")
    width, height = frames[0].size
    if max(width, height) > 320:
        raise ValueError("Unexpected non-pixel animation resolution")
    atlas = Image.new("RGBA", (width * len(frames), height))
    for index, frame in enumerate(frames):
        atlas.paste(frame, (width * index, 0))
    save_new(atlas, output.with_suffix(".png"))
    metadata = {"width": width, "height": height, "durations_ms": durations, "source": str(source), "alpha_extrema": [list(frame.getchannel("A").getextrema()) for frame in frames]}
    with output.with_suffix(".frames.json").open("x", encoding="utf-8") as file:
        json.dump(metadata, file, indent=2)
    save_new(frames[0], output.with_suffix(".preview.gif"), save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=2)
    indices = sorted(set([0, len(frames) // 4, len(frames) // 2, 3 * len(frames) // 4, len(frames) - 1]))
    sheet([frames[index] for index in indices], [str(index) for index in indices], output.with_suffix(".preview.jpg"), columns=5)
    print(json.dumps({"output": str(output), "size": [width, height], "frames": len(frames), "duration_ms": sum(durations), "unique_frames": len({frame.tobytes() for frame in frames})}))


def gallery(source, output):
    # 汇总仅供审阅，不参与运行时资源，原始图集保持不变。
    ids = ["frost_fang_hound", "frost_crystal_sentinel", "frost_shell_beast"]
    names = ["idle", "walk", "attack", "die"]
    clips = {}
    for enemy in ids:
        for name in names:
            with Image.open(Path(source) / enemy / (name + ".webp.source")) as image:
                clips[enemy, name] = [(frame.convert("RGBA").copy(), int(frame.info.get("duration", 100))) for frame in ImageSequence.Iterator(image)]
    previews = []
    for time_ms in range(0, 2000, 125):
        canvas = Image.new("RGB", (480, 640), "#253044")
        draw = ImageDraw.Draw(canvas)
        for column, enemy in enumerate(ids):
            for row, name in enumerate(names):
                clip = clips[enemy, name]
                duration = sum(ms for _, ms in clip)
                clock = time_ms % duration if name in ["idle", "walk"] else min(time_ms, duration - 1)
                selected = clip[-1][0]
                for frame, ms in clip:
                    if clock < ms:
                        selected = frame
                        break
                    clock -= ms
                x, y = column * 160, row * 160
                enlarged = selected.resize((128, 128), Image.Resampling.NEAREST)
                canvas.paste(enlarged, (x + 16, y + 4), enlarged)
                draw.text((x + 8, y + 134), enemy.removeprefix("frost_") + "/" + name, fill="white")
        previews.append(canvas)
    save_new(previews[0], output, save_all=True, append_images=previews[1:], duration=125, loop=0, disposal=2)


def boss_gallery(source, output, names=None, pixel_zoom=None):
    # 单个角色的动作并排预览；只拼接已生成的帧，不重绘或改变游戏素材。
    names = names or ["idle", "attack", "cast", "relocate", "die"]
    clips = {}
    for name in names:
        with Image.open(Path(source) / (name + ".webp.source")) as image:
            clips[name] = [(frame.convert("RGBA").copy(), int(frame.info.get("duration", 100))) for frame in ImageSequence.Iterator(image)]
    previews = []
    for time_ms in range(0, 2000, 125):
        canvas = Image.new("RGB", (1360, 300), "#253044")
        draw = ImageDraw.Draw(canvas)
        for column, name in enumerate(names):
            duration = sum(ms for _, ms in clips[name])
            clock = time_ms % duration if name in ["idle", "walk", "run"] else min(time_ms, duration - 1)
            selected = clips[name][-1][0]
            for frame, ms in clips[name]:
                if clock < ms:
                    selected = frame
                    break
                clock -= ms
            size = (selected.width * pixel_zoom, selected.height * pixel_zoom) if pixel_zoom else (256, 256)
            enlarged = selected.resize(size, Image.Resampling.NEAREST)
            canvas.paste(enlarged, (column * 272 + 8 + (256 - size[0]) // 2, 4 + (256 - size[1]) // 2), enlarged)
            draw.text((column * 272 + 8, 272), name, fill="white")
        previews.append(canvas)
    save_new(previews[0], output, save_all=True, append_images=previews[1:], duration=125, loop=0, disposal=2)


def pad_reference(source, output):
    # 仅为动作预留透明画布，不缩放、重绘或裁切角色像素，原图保持不变。
    with Image.open(source) as image:
        reference = image.convert("RGBA")
        padded = Image.new("RGBA", (reference.width + 64, reference.height + 64))
        padded.paste(reference, (32, 32))
        save_new(padded, output)
    print(json.dumps({"output": str(output), "size": list(padded.size)}))


def verify_animation(source, output):
    # 对照原始动画核对图集和时长；边缘使用半透明阈值，避免误报抠图的微弱杂点。
    prefix = Path(output)
    metadata = json.loads(prefix.with_suffix(".frames.json").read_text(encoding="utf-8"))
    atlas = Image.open(prefix.with_suffix(".png")).convert("RGBA")
    with Image.open(source) as image:
        frames = [frame.convert("RGBA").copy() for frame in ImageSequence.Iterator(image)]
    width, height = frames[0].size
    assert len(frames) >= 2 and len({f.tobytes() for f in frames}) >= 2
    assert metadata["width"] == width and metadata["height"] == height
    assert len(metadata["durations_ms"]) == len(frames)
    assert all(ms > 0 for ms in metadata["durations_ms"])
    assert atlas.size == (width * len(frames), height)
    clipped = []
    for index, frame in enumerate(frames):
        assert frame.size == (width, height)
        assert frame.getchannel("A").getextrema() == (0, 255)
        assert atlas.crop((index * width, 0, (index + 1) * width, height)).tobytes() == frame.tobytes()
        bbox = frame.getchannel("A").point(lambda value: 255 if value > 127 else 0).getbbox()
        assert bbox is not None
        if bbox[0] == 0 or bbox[1] == 0 or bbox[2] == width or bbox[3] == height:
            clipped.append(index)
    print(json.dumps({"source": str(source), "size": [width, height], "frames": len(frames), "duration_ms": sum(metadata["durations_ms"]), "border_touch_frames": clipped, "atlas_matches_source": True}))
    if clipped:
        raise ValueError("Opaque sprite pixels touch the canvas border")


def vfx_gallery(source, output):
    # 仅拼接生成结果供审阅，原始素材像素与时长不变。
    source = Path(source)
    clips = {}
    for name in ["frost_burst", "guard_spark"]:
        with Image.open(source / (name + ".webp.source")) as image:
            clips[name] = [(f.convert("RGBA").copy(), int(f.info.get("duration", 100))) for f in ImageSequence.Iterator(image)]
    with Image.open(source / "sigil.png") as image:
        sigil = image.convert("RGBA").copy()
    previews = []
    for step in range(40):
        time = step * 0.04
        canvas = Image.new("RGB", (960, 320), "#253044")
        draw = ImageDraw.Draw(canvas)
        for column, name, seconds in [(0, "frost_burst", 0.28), (2, "guard_spark", 0.22)]:
            clip = clips[name]
            clock = min(time / seconds, 1.0) * sum(ms for _, ms in clip)
            selected = clip[-1][0]
            for frame, ms in clip:
                if clock < ms:
                    selected = frame
                    break
                clock -= ms
            enlarged = selected.resize((288, 288), Image.Resampling.NEAREST)
            canvas.paste(enlarged, (column * 320 + 16, 0), enlarged)
            draw.text((column * 320 + 16, 295), name + " / " + str(seconds) + "s", fill="white")
        enlarged = sigil.resize((192, 192), Image.Resampling.NEAREST)
        canvas.paste(enlarged, (384, 48), enlarged)
        draw.text((336, 295), "ground sigil / static texture", fill="white")
        previews.append(canvas)
    save_new(previews[0], output, save_all=True, append_images=previews[1:], duration=40, loop=0, disposal=2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["decode", "gallery", "boss-gallery", "character-gallery", "pad-reference", "verify", "vfx-gallery"])
    parser.add_argument("source")
    parser.add_argument("output")
    arguments = parser.parse_args()
    if arguments.mode == "decode":
        decode(arguments.source, arguments.output)
    elif arguments.mode == "gallery":
        gallery(arguments.source, arguments.output)
    elif arguments.mode == "boss-gallery":
        boss_gallery(arguments.source, arguments.output)
    elif arguments.mode == "character-gallery":
        boss_gallery(arguments.source, arguments.output, ["idle", "run", "attack", "cast", "die"], 5)
    elif arguments.mode == "pad-reference":
        pad_reference(arguments.source, arguments.output)
    elif arguments.mode == "vfx-gallery":
        vfx_gallery(arguments.source, arguments.output)
    else:
        verify_animation(arguments.source, arguments.output)
