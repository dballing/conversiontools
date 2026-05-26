# conversiontools

A Perl script for transcoding video files into Apple TV–compatible `.m4v` files using HandBrakeCLI, with optional cloud staging and automatic import into the macOS TV app.

## Prerequisites

Install via Homebrew:

```
brew install handbrake
brew install mediainfo
```

Install via CPAN:

```
cpan DateTime
```

The `trash` utility is required if you use `--trashworkproduct`, `--trashoriginal`, or `--trashall`. Install with:

```
brew install trash
```

## Directory Structure

The script expects these directories to exist before running:

| Path | Purpose |
|------|---------|
| `~/Desktop/Transcoding/Actual Programming/` | Drop source video files here |
| `~/Desktop/Transcoding/AppleTVReady/` | Transcoded output lands here |
| `~/Movies/TV/Media.localized/Automatically Add To TV.localized/` | Apple TV app auto-import folder |
| `~/MEGASelectiveSync/Staging/` | Cloud staging area (was Dropbox, now MEGA — any directory works) |

The cloud staging directory also receives `conversion_log.txt`.

## Usage

```
perl convert.pl [options]
```

Place source files (or subdirectories) in `~/Desktop/Transcoding/Actual Programming/`. Supported formats: `.mkv`, `.mp4`, `.m4v`, `.avi`, `.flv`.

### Options

| Flag | Description |
|------|-------------|
| `--notv` | Do not import the converted file into the TV app |
| `--noconvert` | Skip transcoding; only archive the original |
| `--nocloudconverted` / `--nodropbox` | Do not copy the converted file to cloud staging |
| `--nocloudoriginal` / `--tossorig` | Do not copy the original file to cloud staging |
| `--tvonly` | Skip all cloud archiving; deliver only to the TV app |
| `--overwrite` | Re-transcode even if the output file already exists |
| `--dryrun` | Print what would happen without doing anything |
| `--trashworkproduct` | Delete the converted file after delivery (do not combine with `--notv` + `--nocloudconverted`) |
| `--trashoriginal` | Delete the source file after processing |
| `--trashall` | Both `--trashworkproduct` and `--trashoriginal` |
| `--help` | Print option summary |

## Resolution / Codec Selection

The HandBrake preset is chosen based on the presence of a resolution string in the **output filename**:

| Filename contains | Preset used |
|-------------------|-------------|
| `720` | Apple 720p30 Surround |
| `1080` | Apple 1080p30 Surround |
| `2160` | Apple 2160p60 4K HEVC Surround |
| *(none of the above)* | Apple 720p30 Surround (default) |

Example: a file named `My.Show.1080p.mkv` will be encoded with the 1080p preset.

## Subtitle Handling

The script calls `mediainfo` on each source file to enumerate subtitle tracks and filters out graphical subtitle formats (`S_DVBSUB`, `S_HDMV/PGS`) that HandBrake cannot pass through and would otherwise burn into the picture. Only text-based tracks (e.g. `S_TEXT/UTF8`) are passed to HandBrake.

If a source **directory** contains a `Subs/` subdirectory with `.srt` files, those external subtitle files are used instead.

## Subdirectory Support

If a source item in `Actual Programming/` is a directory rather than a file, the script processes all video files found in it. If the directory also contains a `Subs/` subdirectory, `.srt` files there are matched to the videos.
