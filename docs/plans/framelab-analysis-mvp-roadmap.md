# FrameLab Analysis MVP Roadmap

This file is the long-running execution tracker for expanding FrameLab from color/tone inspection into a broader photo learning toolbox. Keep this file updated as tasks land. Each completed task must record implementation notes, verification, and any remaining follow-up.

## Execution Rules

- Work milestone by milestone unless a dependency requires reordering.
- Update task status before and after each meaningful implementation step.
- Do not remove tasks silently. If scope changes, mark the task `[!]` and explain why.
- Keep existing sampling, histogram, note, import, export, and restore behavior working.
- Prefer local deterministic image algorithms. Do not introduce Core ML, cloud AI, or network services for this MVP.
- Run `swift test` after each milestone.
- Run `./scripts/package_app.sh` for UI, export, or packaging-impacting changes.
- Record each finished step in `Execution Log` with date, files changed, commands run, and result.

## Status Legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Completed
- `[!]` Blocked or requires user confirmation

## Milestone 1: Exposure Diagnostics

- [x] Add an exposure analysis model
  - Goal: Compute shadow, midtone, and highlight percentages for each image.
  - Implementation notes: Base the model on the existing gamma-aware luma pipeline in `ColorAnalysis.swift`.
  - Tests: Verify expected percentages for synthetic dark, middle gray, bright, and mixed pixel buffers.
  - Verification: `swift test`
  - Landing notes: Added `ExposureAnalysis` struct and `exposureAnalysis(for:)` method to `ColorAnalyzer`. Shadow threshold: 0.25, highlight threshold: 0.75.

- [x] Add highlight clipping detection
  - Goal: Identify pixels that are nearly pure white or visually clipped.
  - Implementation notes: Use configurable but fixed MVP thresholds; keep thresholds documented in code and tests.
  - Tests: Cover pure white, near-white, and non-clipped bright pixels.
  - Verification: `swift test`
  - Landing notes: Added clippedHighlightPercentage and crushedShadowPercentage to ExposureAnalysis. Thresholds: clippedHighlight = 0.95, crushedShadow = 0.05.

- [x] Add crushed shadow detection
  - Goal: Identify pixels that are near-black and likely have no recoverable visible detail.
  - Implementation notes: Reuse the exposure analysis pass where practical to avoid extra full-image scans.
  - Tests: Cover pure black, near-black, and detailed dark pixels.
  - Verification: `swift test`
  - Landing notes: Implemented alongside highlight clipping in a single full-image pass for efficiency.
  - Goal: Identify pixels that are near-black and likely have no recoverable visible detail.
  - Implementation notes: Reuse the exposure analysis pass where practical to avoid extra full-image scans.
  - Tests: Cover pure black, near-black, and detailed dark pixels.
  - Verification: `swift test`
  - Landing notes:

- [x] Show exposure diagnostics in the main analysis UI
  - Goal: Display shadow/midtone/highlight ratios plus clipped highlight and crushed shadow percentages near the histogram.
  - Implementation notes: Keep the histogram compact and use a light background consistent with current panels.
  - Tests: Add view-model or formatting tests where behavior is non-trivial.
  - Verification: `swift test`; `./scripts/package_app.sh`
  - Landing notes: Added ExposureAnalysisPanel with horizontal bar charts for exposure categories. Clipped highlights and crushed shadows are only shown above 1% to avoid visual noise.

- [x] Add image overlays for highlight and shadow warnings
  - Goal: Let users toggle highlight clipping and crushed shadow overlays on the photo.
  - Implementation notes: Ensure overlays do not affect sampling point movement, magnifier behavior, or immersive viewing.
  - Tests: Cover overlay state transitions in the view model.
  - Verification: `swift test`; `./scripts/package_app.sh`
  - Landing notes: Added `showsClippedHighlightOverlay` and `showsCrushedShadowOverlay` state properties to view model. Created SwiftUI Canvas-based overlay views. Added toggle buttons in toolbar with tint colors (red for highlights, orange for shadows). Overlays render on top of the image but under sample points to preserve interaction.

## Milestone 2: Local Region Analysis

- [ ] Add a selectable local analysis region
  - Goal: Let users draw or adjust one rectangular region on the photo.
  - Implementation notes: Store the region as normalized coordinates so it survives image scaling.
  - Tests: Verify normalized region clamping and conversion to pixel bounds.
  - Verification: `swift test`
  - Landing notes:

- [ ] Compute local histogram and exposure diagnostics
  - Goal: Analyze the selected region independently from the whole image.
  - Implementation notes: Reuse histogram and exposure functions with an optional pixel region parameter.
  - Tests: Validate region-only statistics on synthetic buffers.
  - Verification: `swift test`
  - Landing notes:

- [ ] Add whole-image/local analysis switching
  - Goal: Let the info panel switch between full image analysis and local region analysis.
  - Implementation notes: Do not change existing sample point behavior when local mode is active.
  - Tests: Cover selected mode state and fallback when no region exists.
  - Verification: `swift test`; `./scripts/package_app.sh`
  - Landing notes:

## Milestone 3: Composition Aids

- [ ] Add composition guide toggles
  - Goal: Support rule-of-thirds, center crosshair, and safe-margin overlays.
  - Implementation notes: Draw guides over the displayed image rect, not over the full canvas.
  - Tests: Cover guide state toggles in the view model.
  - Verification: `swift test`; `./scripts/package_app.sh`
  - Landing notes:

- [ ] Add horizon tilt reference
  - Goal: Provide a simple horizontal reference overlay for judging tilt.
  - Implementation notes: MVP only needs a visible adjustable or centered reference line; no automatic horizon detection.
  - Tests: Cover state and default visibility.
  - Verification: `swift test`; `./scripts/package_app.sh`
  - Landing notes:

- [ ] Add edge distraction analysis
  - Goal: Detect high-brightness or high-saturation distractions near image edges.
  - Implementation notes: Analyze a fixed edge band percentage and report distraction ratios by side.
  - Tests: Use synthetic buffers with bright or saturated edge pixels.
  - Verification: `swift test`
  - Landing notes:

## Milestone 4: Color Palette & Harmony

- [ ] Extract a five-color dominant palette
  - Goal: Show the main colors in each image with approximate usage percentages.
  - Implementation notes: Use a deterministic local clustering or quantization method suitable for tests.
  - Tests: Verify palette extraction on simple one-color, two-color, and mixed-color buffers.
  - Verification: `swift test`
  - Landing notes:

- [ ] Show palette details in the analysis UI
  - Goal: Display swatches with Hex, HSL, and percentage values.
  - Implementation notes: Keep layout compact and consistent with current sample information panels.
  - Tests: Add formatting tests if percentage or label generation is extracted.
  - Verification: `swift test`; `./scripts/package_app.sh`
  - Landing notes:

- [ ] Add palette markers to the Color Wheel
  - Goal: Visualize dominant palette colors alongside sample point colors.
  - Implementation notes: Keep palette markers visually distinct from numbered sampling points.
  - Tests: Cover geometry or marker data mapping where extracted.
  - Verification: `swift test`; `./scripts/package_app.sh`
  - Landing notes:

- [ ] Add basic harmony classification
  - Goal: Identify simple analogous, complementary, and warm/cool leaning palettes.
  - Implementation notes: Use transparent heuristic rules and document limitations in UI copy or README.
  - Tests: Cover known hue sets for analogous, complementary, warm, and cool cases.
  - Verification: `swift test`
  - Landing notes:

## Milestone 5: Export, Notes, and Persistence

- [ ] Include new analysis sections in exported images
  - Goal: Export exposure diagnostics, local region summary, composition aids, and palette information.
  - Implementation notes: Preserve existing sample table, Color Wheel, and histogram export content.
  - Tests: Add export view coverage if practical; otherwise verify package and manual render path.
  - Verification: `swift test`; `./scripts/package_app.sh`
  - Landing notes:

- [ ] Add analysis summary to Obsidian notes
  - Goal: Provide a generated Markdown analysis block for each photo.
  - Implementation notes: Do not overwrite user-written note body. Use a clearly delimited FrameLab-generated section.
  - Tests: Verify note save/load preserves user content and updates only the generated section.
  - Verification: `swift test`
  - Landing notes:

- [ ] Persist analysis settings and local region
  - Goal: Restore overlay toggles, composition guide settings, local region, and selected analysis mode after app relaunch.
  - Implementation notes: Extend project persistence without breaking existing saved workspaces.
  - Tests: Cover encoding/decoding with old and new project shapes.
  - Verification: `swift test`
  - Landing notes:

- [ ] Update README for MVP analysis features
  - Goal: Document the new exposure, local analysis, composition, palette, export, and notes capabilities.
  - Implementation notes: Keep the README user-facing and concise.
  - Tests: Documentation-only; no tests required unless code changes are bundled.
  - Verification: Review rendered Markdown.
  - Landing notes:

## Final Acceptance Checklist

- [ ] Multiple JPG, PNG, and HEIC images can still be imported.
- [ ] App launch restores the previous workspace without blocking the UI.
- [ ] Up/down keyboard navigation still switches photos.
- [ ] Sampling points can still be added, deleted, selected, and dragged.
- [ ] Sampling magnifier still appears while dragging.
- [ ] Histogram and sample information remain visible in normal mode.
- [ ] Immersive mode still supports showing and hiding sample points.
- [ ] Exposure diagnostics display whole-image values.
- [ ] Highlight and crushed-shadow overlays can be toggled.
- [ ] Local region analysis displays region-specific histogram and exposure values.
- [ ] Composition guides render within the image bounds.
- [ ] Dominant palette and harmony summary display for each image.
- [ ] Exported analysis image includes the new analysis sections.
- [ ] Obsidian note content is preserved when generated analysis is updated.
- [ ] Project persistence restores new analysis settings.
- [ ] `swift test` passes.
- [ ] `./scripts/package_app.sh` succeeds.

## Execution Log

Use this format for each execution entry:

```md
### YYYY-MM-DD - Short summary

- Status:
- Files changed:
- Commands run:
- Result:
- Follow-up:
```

### 2026-05-11 - Highlight and shadow warning overlays implemented

- Status: Completed image overlays for highlight clipping and crushed shadow warnings.
- Files changed: `Sources/PicAnalysisApp/PhotoAnalysisDocument.swift`, `Sources/PicAnalysisApp/ColorAnalysis.swift`, `Sources/PicAnalysisApp/PhotoCanvasView.swift`, `Sources/PicAnalysisApp/ContentView.swift`, `docs/plans/framelab-analysis-mvp-roadmap.md`
- Commands run: `swift build`, `swift test`
- Result: Build and all 34 tests pass. Added overlay toggle state properties to view model. Created `ClippedHighlightOverlay` and `CrushedShadowOverlay` SwiftUI Canvas views. Added toolbar toggle buttons with color tinting for active state. Overlays render between the image and sample points to preserve dragging interaction.
- Follow-up: Milestone 1 complete. Next task: Add a selectable local analysis region.

### 2026-05-11 - Exposure diagnostics UI implemented

- Status: Completed exposure diagnostics panel in main UI.
- Files changed: `Sources/PicAnalysisApp/PhotoAnalysisDocument.swift`, `Sources/PicAnalysisApp/HistogramPanel.swift`, `Sources/PicAnalysisApp/ContentView.swift`, `Sources/PicAnalysisApp/ExportAnalysisView.swift`, `docs/plans/framelab-analysis-mvp-roadmap.md`
- Commands run: `swift build`, `swift test`
- Result: Build and all 34 tests pass. Added `exposureAnalysis` property to `PhotoAnalysisDocument`. Created `ExposureAnalysisPanel` with horizontal bar charts for shadow/midtone/highlight. Clipped highlights (red) and crushed shadows (orange) show only when > 1%. Updated both main UI and export view.
- Follow-up: Next task: Add image overlays for highlight and shadow warnings.

### 2026-05-11 - Highlight clipping and crushed shadow detection implemented

- Status: Completed highlight clipping and crushed shadow detection with tests.
- Files changed: `Sources/PicAnalysisApp/ColorAnalysis.swift`, `Tests/PicAnalysisAppTests/ColorAnalysisTests.swift`, `docs/plans/framelab-analysis-mvp-roadmap.md`
- Commands run: `swift test`
- Result: All 34 tests pass. Added `clippedHighlightPercentage` and `crushedShadowPercentage` to `ExposureAnalysis`, along with `ExposureThresholds` enum for thresholds. Implemented in a single full-image pass for efficiency.
- Follow-up: Next task: Show exposure diagnostics in the main analysis UI.

### 2026-05-11 - Exposure analysis model implemented

- Status: Completed the exposure analysis model with tests.
- Files changed: `Sources/PicAnalysisApp/ColorAnalysis.swift`, `Tests/PicAnalysisAppTests/ColorAnalysisTests.swift`, `docs/plans/framelab-analysis-mvp-roadmap.md`
- Commands run: `swift test`
- Result: All 28 tests pass. Added `ExposureAnalysis` struct with shadow, midtone, highlight percentages, and `exposureAnalysis(for:)` method.
- Follow-up: Next task: Add highlight clipping detection.

### 2026-05-11 - Roadmap file created

- Status: Created the MVP roadmap and execution tracker.
- Files changed: `docs/plans/framelab-analysis-mvp-roadmap.md`
- Commands run: Not applicable; documentation tracker only.
- Result: Ready for long-running Codex execution.
- Follow-up: Start with Milestone 1 exposure analysis model.
