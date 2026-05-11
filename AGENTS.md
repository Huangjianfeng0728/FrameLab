# Repository Guidelines

## Project Structure & Module Organization

FrameLab is a Swift Package Manager macOS app. Main application code lives in `Sources/PicAnalysisApp/`, including SwiftUI views, `AnalysisViewModel`, image analysis logic, export, persistence, and Obsidian note handling. Tests live in `Tests/PicAnalysisAppTests/` and mirror the app modules by behavior. App icon assets are under `assets/icon/`. Helper scripts are in `scripts/`, including packaging and icon generation. `dist/` contains generated app bundles and should not be treated as primary source.

## Build, Test, and Development Commands

- `swift run FrameLab`: builds and runs the app executable locally.
- `swift build`: compiles the package without launching the app.
- `swift test`: runs the Swift Testing test suite.
- `./scripts/package_app.sh`: creates `dist/FrameLab.app` for manual GUI testing.
- `open dist/FrameLab.app`: opens the packaged app after building.

## Coding Style & Naming Conventions

Use Swift 5.9 targeting macOS 13. Prefer 4-space indentation and standard Swift naming: `PascalCase` for types, `camelCase` for properties, functions, and local values. Keep SwiftUI views focused on layout and interaction. Put reusable photo analysis math, persistence, and file handling in dedicated helper/model types. Prefer small, deterministic functions for color, histogram, and sampling logic so they can be tested directly.

## Testing Guidelines

Tests use Swift Testing in `Tests/PicAnalysisAppTests/`. Name tests by expected behavior, for example `histogramUsesGammaAwarePerceptualLumaForMiddleGray`. Add or update tests when changing color math, sampling, histogram behavior, note persistence, project restore, or view-model state transitions. Run `swift test` before handing off code changes.

## Commit & Pull Request Guidelines

Existing commit messages are short and direct, such as `add README.md`, `v1提交`, and `V2版本：新增笔记功能`. Keep commits concise and descriptive. Pull requests should explain the user-facing change, list verification performed, mention any persistence or file-format impact, and include screenshots or screen recordings for UI changes.

## Long-Running Plan & Todo Source

For extended Codex execution, use `docs/plans/framelab-analysis-mvp-roadmap.md` as the source of truth for the active plan, TODO list, milestone order, and acceptance checklist. Use `docs/plans/framelab-analysis-mvp-execution-log.md` for detailed landing history. Before starting work, read the roadmap and pick the next incomplete task. While working, update task status (`[ ]`, `[~]`, `[x]`, `[!]`) and fill in `Landing notes` in the roadmap. After each completed step, append an execution log entry to the separate log file with files changed, commands run, results, and follow-up.

## Agent-Specific Instructions

Do not revert unrelated local changes. Use `rg` for repository search. Keep edits scoped to the requested behavior. Avoid changing generated bundles in `dist/` unless packaging is explicitly part of the task. For GUI-impacting changes, run `swift test` and package the app when appropriate.
