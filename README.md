# FrameLab

FrameLab is a macOS photo learning and analysis toolbox focused on precise visual inspection. It helps photographers study color, tone, and sampling details directly on top of their images instead of switching between scattered tools.

The app currently supports batch photo import, point-based color sampling, HSL analysis, Color Wheel positioning, tone histograms, immersive viewing, and exporting annotated analysis images.

## Features

- Batch import JPG, PNG, and HEIC photos.
- Automatically generate 10 default sampling points for each image.
- Add, delete, select, and drag sampling points on the photo.
- Analyze each sampling point with HSL, RGB, Hex, and Color Wheel position.
- Choose sampling radius: single pixel, 3x3, 5x5, or 9x9.
- Show a pixel magnifier while dragging a sampling point, including the exact pixels used for sampling.
- Display a tone histogram for the whole image.
- Write per-photo Markdown notes while viewing images.
- Save notes into a user-selected Obsidian folder, one `.md` file per photo.
- Use arrow keys to switch between photos.
- Enter immersive viewing mode, with optional sampling overlay and enlarged sampling details.
- Export an analysis image containing the photo, sampling markers, color data, Color Wheel, and histogram.

## Why FrameLab

FrameLab is designed for learning photography through close observation. Instead of only showing an image, it exposes how color and tone are distributed across the frame:

- Which areas share similar hue or lightness.
- How sampled colors sit on a Color Wheel.
- How local pixel sampling changes when the sampling radius changes.
- How the overall tone distribution supports the look of the photo.

The long-term goal is to grow FrameLab into an all-in-one photo study toolbox.

## Obsidian Notes

When importing a batch of photos, FrameLab asks for the Obsidian folder where notes for that batch should be saved. Each photo gets its own Markdown file based on the photo filename, such as `IMG_1234.md`.

FrameLab stores the note folder path and note filename in its local project state, so reopening the app can reconnect each photo to its existing note. Notes include lightweight frontmatter for the source image and FrameLab photo ID, while the body remains normal Markdown text that can be edited in Obsidian.

## Requirements

- macOS 13 or later
- Swift 5.9

## Run From Source

```bash
swift run FrameLab
```

Or build and package the app bundle:

```bash
./scripts/package_app.sh
open dist/FrameLab.app
```

## Tests

```bash
swift test
```

## Project Status

FrameLab is in active development. The current version focuses on photo color sampling, histogram analysis, immersive viewing, and annotated export. More photo-learning tools will be added over time.
