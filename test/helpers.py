"""Regression checks for filesystem boundaries and real local-media helpers."""

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent


def load(name):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / "scripts" / name))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


launcher = load("media-launch")
lyrics = load("media-lyrics")
cover = load("media-cover")

with tempfile.TemporaryDirectory(prefix="media-controls-regressions-") as temporary:
    sandbox = Path(temporary)
    music = sandbox / "Music"
    album = music / "Album"
    album.mkdir(parents=True)
    original = music / "Original.mp3"
    original.touch()
    second = album / "Track 2.mp3"
    second.touch()
    tenth = album / "Track 10.mp3"
    tenth.symlink_to(original)
    outside = sandbox / "Outside.mp3"
    outside.touch()
    (album / "Track 1.mp3").symlink_to(outside)
    _, _, tracks, index = launcher.validate_target(str(music), str(album), "folder")
    assert tracks == [second, original] and index == 0

    runtime = sandbox / "runtime"
    target = sandbox / "unrelated"
    target.mkdir(mode=0o755)
    runtime.mkdir(mode=0o700)
    (runtime / "omarchy-media-controls").symlink_to(target, target_is_directory=True)
    with patch.dict(os.environ, {"XDG_RUNTIME_DIR": str(runtime)}):
        try:
            launcher.runtime_directory()
        except OSError:
            pass
        else:
            raise AssertionError("Runtime symlinks must be rejected")
    assert stat.S_IMODE(target.stat().st_mode) == 0o755

    cache = sandbox / "cache"
    with patch.dict(os.environ, {"XDG_CACHE_HOME": str(cache)}):
        records = [
            {"trackName": "Song", "artistName": "Artist", "duration": "unknown", "plainLyrics": "Words"}
        ]
        with patch.object(lyrics, "request_json", return_value=records) as request:
            result = lyrics.online_lyrics("Song", "Artist", "", 120)
            assert result["status"] == "ok" and result["lyrics"] == "Words"
            assert lyrics.online_lyrics("Song", "Artist", "", 120)["source"] == "lrclib-cache"
            assert request.call_count == 1
            request.return_value = []
            assert lyrics.online_lyrics("Song", "Artist", "", 120, refresh=True)["status"] == "not-found"
            request.return_value = records
            assert lyrics.online_lyrics("Song", "Artist", "", 120)["status"] == "not-found"
            assert lyrics.online_lyrics("Song", "Artist", "", 120, refresh=True)["status"] == "ok"
            assert request.call_count == 3

        audio = sandbox / "embedded.flac"
        generated = subprocess.run([
            "ffmpeg", "-v", "error", "-nostdin", "-f", "lavfi", "-i", "anullsrc=r=8000:cl=mono",
            "-f", "lavfi", "-i", "color=c=red:s=16x16", "-t", "0.1",
            "-map", "0:a", "-map", "1:v", "-c:a", "flac", "-c:v", "mjpeg",
            "-frames:v", "1", "-disposition:v", "attached_pic",
            "-metadata", "LYRICS=Embedded words", str(audio),
        ], capture_output=True, text=True, timeout=10)
        assert generated.returncode == 0, generated.stderr
        resolved = lyrics.local_lyrics(audio.as_uri())
        assert resolved["source"] == "embedded" and resolved["lyrics"] == "Embedded words"
        image = cover.resolve_cover(audio.as_uri())
        assert image and image.is_file() and image.stat().st_size > 0
        assert cover.resolve_cover(audio.as_uri()) == image

        offline = os.environ.copy()
        offline["MEDIA_CONTROLS_ONLINE_LYRICS"] = "0"
        result = subprocess.run([
            str(ROOT / "scripts/media-lyrics"), "--url", audio.as_uri(), "--duration", "inf",
        ], env=offline, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stderr
        assert json.loads(result.stdout)["source"] == "embedded"

print("PASS: symlink boundaries, lyrics caching, and embedded media extraction")
