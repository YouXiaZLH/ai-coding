# COPILOT.md

## Project Overview

- **Project**: 九宫军演：群雄策
- **Genre**: 三国题材单机自走棋（移动端快节奏）
- **Primary Platform**: Android (TapTap)
- **Current Stage**: Pre-production / Prototype planning

## Technology Stack

- **Engine**: Godot 4.6
- **Language**: GDScript (primary), C++ via GDExtension (performance-critical)
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Core Directories

- `design/gdd/` — game concept and system design docs
- `docs/engine-reference/` — version-aware engine guidance
- `production/` — planning, milestones, and session artifacts
- `src/` — gameplay implementation (to be created during prototype)
- `assets/` — art/audio/data assets (to be created during prototype)

## Collaboration Protocol

- Ask before major architecture or scope changes
- Prefer small, testable iterations
- Validate engine APIs against version reference docs before implementation
- Capture key technical decisions with `/architecture-decision`
