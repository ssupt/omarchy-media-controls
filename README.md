# Media Controls for Omarchy

An Omarchy Quattro plugin for MPRIS playback controls, local music browsing,
artwork, and lyrics. It replaces the built-in `omarchy.media` widget and supplies
its own player service.

The bar shows the current track and transport buttons. When no track is
available, **ARCHIVE** opens the music browser. The widget supports all four bar
positions; side bars use a rotated track label and stacked controls. The popup
uses the Monumental style, with separate **Transmission** and **Archive** views.

## Install

```bash
omarchy plugin add https://github.com/ssupt/omarchy-media-controls.git --enable
```

Omarchy installs the plugin as `ssupt.media-controls`. Enabling it replaces the
built-in media widget; removing it while enabled restores that widget.

### Requirements

| Dependency | Used for |
| --- | --- |
| Omarchy Quattro with its Quickshell shell | Plugin hosting and UI |
| Python 3.10 or later | Music, artwork, and lyrics helpers |
| An MPRIS player | Transport controls and track metadata |
| `ffmpeg` and `ffprobe` (optional) | Embedded artwork and lyrics |
| Toccata (optional) | Local playback, queueing, and session details |
| mpv (optional) | Reusable local playback fallback |
| `xdg-open` (optional) | Desktop fallback when playback backends fail |
| Network access (optional) | LRCLIB lyrics lookup |

Players such as Spotify, browsers, and local music players work when they expose
MPRIS. Each player determines whether previous, next, play/pause, and seeking are
available.

## Controls

Click the bar's artwork or track label to open or close the popup. Click
**ARCHIVE** when idle, or the Archive button in Transmission, to browse music.
Scroll over the track label for previous or next.

In Archive, click a row to select it. Double-click a folder to enter it or a file
to play it. Each row's **Play** button plays the file or the folder recursively;
the toolbar's **Folder** button plays the current folder recursively.

| View | Key | Action |
| --- | --- | --- |
| Archive | Up / Down | Select an entry |
| Archive | Home / End | Select the first / last entry |
| Archive | Enter | Enter a folder or play a file |
| Archive | Ctrl+Enter | Play the selection, including a folder recursively |
| Archive | Backspace | Go to the parent folder |
| Archive | Escape | Go up; at the root, return to Transmission or close when idle |
| Archive | T | Open Transmission |
| Transmission | Space | Play / pause |
| Transmission | N / P | Next / previous track |
| Transmission | B | Open Archive |
| Transmission | Escape | Close the popup |

Click the progress track to seek when the player supports seeking. Lyrics are
selectable, scrollable text; timestamped lyrics are displayed as a plain
transcript.

## Music folder and playback

The archive root is the first configured location in this order:

1. `MEDIA_CONTROLS_MUSIC_DIR`.
2. The result of `xdg-user-dir MUSIC`.
3. `$HOME/Music`, when neither of the above supplies a location.

The chosen folder must exist and be readable. The plugin does not create it or
silently replace an invalid configured location with another folder. Directory
contents update as files change, with folders first and names sorted naturally.

Supported extensions, regardless of case:

```text
.flac .mp3 .ogg .oga .opus .m4a .mp4 .aac .alac .wav .wave
```

A file selection queues supported sibling files and starts at the selected
track. A folder selection queues supported files recursively. The fallback
playlist skips hidden entries and directory symlinks. File symlinks must resolve
inside the music root; the launcher rejects selections outside that root.

Playback routing depends on `toccataIntegration`:

| Mode | Behavior |
| --- | --- |
| `auto` (default) | Use Toccata when it is connected through MPRIS. Otherwise use the fallback chain. |
| `prefer` | Try Toccata even when it is not connected, allowing a selection to start it. |
| `off` | Skip Toccata's CLI and use the fallback chain. |

If Toccata is unavailable or rejects the request, the launcher tries mpv, then
`xdg-open`. mpv runs without a video window and reuses one idle session through a
private Unix socket. A new selection replaces its playlist and resumes playback.
Bar controls require an mpv MPRIS plugin; mpv alone does not guarantee them.

For a file, `xdg-open` invokes the desktop's default application. For a folder,
it opens the file manager and restores the previously paused player. Opening a
folder this way does not start recursive playback. The archive reports the
backend and any launch error.

The service pauses the current player when it can before launching a selection.
If launching fails, or Toccata does not expose playing media within eight seconds
of accepting the request, it attempts to resume that player. Transport controls
always use MPRIS, including when `toccataIntegration` is `off`.

## Settings

Edit the existing `ssupt.media-controls` entry under `bar.layout.left`,
`bar.layout.center`, or `bar.layout.right` in `~/.config/omarchy/shell.json`:

```json
{
  "id": "ssupt.media-controls",
  "toccataIntegration": "auto",
  "showToccataDetails": true,
  "showWhenIdle": true
}
```

| Setting | Default | Effect |
| --- | --- | --- |
| `toccataIntegration` | `"auto"` | Select `auto`, `prefer`, or `off`; other values use `auto`. |
| `showToccataDetails` | `true` | Show Toccata queue position, output state, and signal information in Transmission when integration is enabled and Toccata is active. |
| `showWhenIdle` | `true` | Keep the ARCHIVE entry visible without track metadata. Set to `false` to hide it. |

Toccata integration uses its public `play`, `status --json`, and `show` commands.
It does not read Toccata databases or private application files.

### Environment variables

These variables belong in the Omarchy shell's startup environment, rather than
`shell.json`. Restart the shell after changing them. Exporting a variable in a
terminal does not change the environment of an already running shell.

| Variable | Default | Effect |
| --- | --- | --- |
| `MEDIA_CONTROLS_MUSIC_DIR` | XDG Music folder or `$HOME/Music` | Override the archive root. |
| `MEDIA_CONTROLS_ONLINE_LYRICS` | `1` | Set to `0`, `false`, `off`, or `no` to disable online lyrics. |
| `XDG_CACHE_HOME` | `~/.cache` | Base directory for artwork and lyrics caches. |
| `XDG_RUNTIME_DIR` | A private per-user directory under the system temporary directory | Base directory for mpv's socket, lock, and playlists. |

For custom installations and testing, the helpers also accept executable paths
through `MEDIA_CONTROLS_TOCCATA`, `MEDIA_CONTROLS_MPV`,
`MEDIA_CONTROLS_XDG_OPEN`, `MEDIA_CONTROLS_XDG_USER_DIR`,
`MEDIA_CONTROLS_FFMPEG`, and `MEDIA_CONTROLS_FFPROBE`.
`MEDIA_CONTROLS_LRCLIB_BASE_URL` overrides the lyrics API endpoint.

## Lyrics and artwork

Lyrics are requested when Transmission opens or its track changes. Resolution
stops at the first available source:

1. Lyrics exported by the player as MPRIS `xesam:asText` metadata.
2. A same-name `.lrc` or `.txt` file beside a local audio file.
3. Embedded lyric tags read with `ffprobe`.
4. [LRCLIB](https://lrclib.net/docs), using track metadata.

The online lookup sends the title, artist, album, and duration when available.
It needs a title and artist, and requires no account or API key. Disabling online
lyrics still allows player metadata, sidecars, and embedded tags.

Online results are cached in `$XDG_CACHE_HOME/omarchy/media-controls/lyrics`
(`~/.cache/omarchy/media-controls/lyrics` by default). Successful results are
reused; missing results expire after six hours. Service errors are not cached.
The **Retry** button bypasses the online cache while still checking local sources
first.

Artwork uses the player's MPRIS URL first. For local tracks without exported
artwork, the helper checks for `cover`, `folder`, or `front` images beside the
track, accepting JPG, JPEG, PNG, or WebP names without regard to case. It then
tries embedded artwork with `ffmpeg`. Extracted covers are cached under
`omarchy/media-controls/covers` in the cache directory and invalidated when the
audio file's size or modification time changes.

## Troubleshooting

- **Archive unavailable:** Check the resolved Music folder, its permissions, and
  `MEDIA_CONTROLS_MUSIC_DIR`. After creating a missing root, restart the shell.
- **Music plays but controls are absent:** Confirm that the chosen player exposes
  MPRIS. The mpv fallback needs an MPRIS plugin.
- **A folder opens in the file manager:** Both playback backends were unavailable
  or failed. Install mpv or configure Toccata to play folders recursively.
- **Lyrics are missing:** Check player metadata or local lyric files. For embedded
  tags, install `ffprobe`; for online lookup, check network access and the online
  lyrics setting. Use Retry to refresh a cached miss.

The service also exposes Omarchy's `media` IPC target:

```bash
omarchy-shell media status
omarchy-shell media playPause
omarchy-shell media next
omarchy-shell media previous
```

`status` returns JSON; transport calls return `ok` or `unhandled`. `play`,
`pause`, and `ping` are also available.

## Update or remove

```bash
omarchy plugin update ssupt.media-controls
omarchy plugin remove ssupt.media-controls
```

## Development

Run checks from the repository root:

```bash
./test/all
omarchy plugin validate .
```

The suite needs Bash, Python, Node.js, jq, ripgrep, FFmpeg, `qmllint`, Quickshell
QML modules, and Omarchy shell imports. It covers model logic, playback handoff,
popup state, local extraction, lyrics caching, path validation, playlist ordering,
and launcher fallbacks using temporary player stand-ins. It does not require a
live Toccata installation or make online lyrics requests.

If Omarchy is installed elsewhere, set `OMARCHY_PATH` for the tests:

```bash
OMARCHY_PATH=/path/to/omarchy ./test/all
```

CI runs the suite and manifest validator in Arch Linux against the Omarchy
revision pinned in [the workflow](.github/workflows/ci.yml).

## License

Plugin code is licensed under [MIT](LICENSE). Bundled DINish and Hakkou Mincho
fonts use the [SIL Open Font License 1.1](assets/fonts/OFL.txt).

More plugins: [omarchy-plugins](https://github.com/ssupt/omarchy-plugins).
