# Media Controls for Omarchy

Media Controls turns Omarchy's media widget into a small now-playing rail with
album artwork, track information, and direct previous/play-pause/next controls.
Click the artwork or track name to open a focused player window with larger art,
playback progress, and lyrics.

It uses Omarchy's MPRIS service, so it works with Spotify and any other player
that exposes the standard Linux MPRIS interface—including local-file players.
The widget adapts automatically to top, bottom, left, and right bars. On a side
bar the title rotates into the rail while the artwork and controls stack
vertically.

## Lyrics

Lyrics are resolved only when the player window is opened, in this order:

1. Text already exposed by the player through MPRIS.
2. A same-name `.lrc`/`.txt` sidecar or lyrics embedded in a local audio file.
3. [LRCLIB](https://lrclib.net/docs), matched using title, artist, album, and
   duration.

Local FLAC/Vorbis `LYRICS`, `UNSYNCEDLYRICS`, and `SYNCEDLYRICS` tags are read
with `ffprobe`. LRCLIB results are cached under
`~/.cache/omarchy/media-controls/lyrics`, so revisiting a track does not repeat
the request. No streaming-service account or API key is required.

The online fallback sends the current track's title, artist, album, and duration
to LRCLIB. To keep lyrics strictly local, launch Omarchy with
`MEDIA_CONTROLS_ONLINE_LYRICS=0` in its environment.

Artwork comes from MPRIS first. For local tracks without exported artwork, the
plugin looks for `cover`, `folder`, or `front` images beside the file and then
tries the file's embedded cover.

## Install

```bash
omarchy plugin add https://github.com/ssupt/omarchy-media-controls.git --enable
```

Enabling the plugin replaces Omarchy's built-in `omarchy.media` bar widget while
continuing to use its first-party player-selection service.

## Controls

- Click the artwork or track information to open the lyrics window.
- Use the three buttons for previous, play/pause, and next.
- Scroll over the track information to move through the queue.
- In the lyrics window, use Space to play/pause, `N` for next, `P` for previous,
  and Escape to close.
- Click the progress track to seek when the player supports it.

## Requirements

- Omarchy Quattro
- Python 3
- `ffmpeg`/`ffprobe` for local embedded lyrics and artwork
- Network access for the optional LRCLIB fallback

These runtime commands are included in a standard Omarchy installation.

## Updating

```bash
omarchy plugin update ssupt.media-controls
```

## Removing

```bash
omarchy plugin remove ssupt.media-controls
```

Removing the plugin restores Omarchy's built-in media widget.

## Development

```bash
./test/all
omarchy-plugin-validate .
```

## License

MIT
