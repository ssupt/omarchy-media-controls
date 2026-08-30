# Media Controls for Omarchy

Media Controls turns Omarchy's media widget into a local archive browser and a
compact now-playing rail. Its popup follows Toccata's Monumental interface
language: square one-pixel rules, numbered sections, restrained state color,
and distinct machine/archive typography. When nothing is playing, the widget
remains visible as **ARCHIVE** so the local collection is always one click away.

It talks directly to MPRIS, so it works with Spotify and any other player that
exposes the standard Linux media interface—including local-file players.
The bar itself stays native to Omarchy and adapts automatically to top, bottom,
left, and right positions. On a side bar the title rotates into the rail while
the artwork and controls stack vertically.

## Music browser

The browser watches the Music folder for live changes, keeps folders ahead of
supported audio files, and sorts names naturally. It never creates a missing
Music folder. The root is resolved from `MEDIA_CONTROLS_MUSIC_DIR`, then
`xdg-user-dir MUSIC`, then `$HOME/Music`.

Toccata is optional. The default `auto` mode uses its public CLI only when Toccata is
already the connected MPRIS player; it never starts Toccata just because the
binary is installed. `prefer` allows a browser selection to start Toccata, while
`off` never invokes it. The popup can show Toccata's public status data—queue
position, direct-output state, and signal format—when Toccata is active. No Toccata
database or private files are read.

When a selection is not routed to Toccata, the plugin tries one reusable,
audio-only mpv session and then `xdg-open`. Later selections replace that mpv
session's playlist through a private Unix socket instead of starting another
player process; the session remains idle and reusable between selections. Those
fallbacks cannot guarantee MPRIS controls, and the browser reports that
explicitly. Once a player appears, transport control stays on the standard
MPRIS interface in every mode.

## Optional Toccata settings

Settings live beside the widget entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "ssupt.media-controls",
  "toccataIntegration": "auto",
  "showToccataDetails": true,
  "showWhenIdle": true
}
```

`toccataIntegration` accepts `off`, `auto`, or `prefer`. `showToccataDetails` controls
the Toccata-only diagnostic strip in the Transmission view whenever integration is
enabled. Set `showWhenIdle` to `false` if the ARCHIVE entry should disappear
when no player is available.

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

More plugins by `ssupt`: [omarchy-plugins](https://github.com/ssupt/omarchy-plugins).

## Install

```bash
omarchy plugin add https://github.com/ssupt/omarchy-media-controls.git --enable
```

Enabling the plugin replaces Omarchy's built-in `omarchy.media` widget. Its own
player-selection service keeps the controls available even though the built-in
media plugin is disabled as part of that replacement.

## Controls

- Click the artwork or track information to open the Transmission window.
- Click **ARCHIVE**, or the Archive button in now-playing, to browse music.
- Use Up/Down and Home/End to select; Enter opens or plays; Ctrl+Enter plays a
  selected folder recursively; Backspace goes up; Escape goes up or exits.
- Use the three buttons for previous, play/pause, and next.
- Scroll over the track information to move through the queue.
- In the Transmission popup, use Space to play/pause, `N` for next, `P` for
  previous, `B` for the archive, and Escape to close.
- Click the progress track to seek when the player supports it.

## Requirements

- Omarchy Quattro
- Python 3
- `ffmpeg`/`ffprobe` for local embedded lyrics and artwork
- Network access for the optional LRCLIB fallback
- Optional: Toccata for deterministic queueing, public playback diagnostics, and
  MPRIS handoff; or mpv as the first playback fallback

Python and FFmpeg are included in a standard Omarchy installation; Toccata and
mpv remain optional.

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
omarchy plugin validate .
```

## License

The plugin code is MIT licensed. Bundled DINish and Hakkou Mincho fonts are
distributed under the SIL Open Font License 1.1 in `assets/fonts/OFL.txt`.
