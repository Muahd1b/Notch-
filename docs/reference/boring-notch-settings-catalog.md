# Boring Notch Settings Catalog

Date: March 10, 2026
Status: Reference

## Purpose

This document catalogs the Boring Notch settings surface at the level needed for future parity work in `Notch-`.

Use it when porting settings logic or control patterns that are not yet implemented locally. This is the reference for:

- sidebar information architecture
- grouped section structure
- specific control patterns
- badges such as `Beta`
- feature-page logic that should be copied later

## Window Shell

The settings shell should continue to mirror:

- standard macOS titled window
- `NavigationSplitView`
- sidebar width around `200`
- grouped form sections on the detail side
- top-right quit action in `General`

## Sidebar Inventory

Observed upstream categories:

- `General`
- `Appearance`
- `Media`
- `Calendar`
- `HUDs`
- `Battery`
- `Shelf`
- `Shortcuts`
- `Advanced`
- `About`

`Notch-` adapts category names for its own integrations, but the structure and pacing should stay close to this system.

## Section Patterns To Copy

### General

Observed section patterns:

- `System features`
- `Notch sizing`
- `Notch behavior`
- `Gesture control` with `Beta` badge

Observed controls:

- toggle rows
- picker rows with value on the trailing edge
- slider rows with inline current value label

Implication for `Notch-`:

- keep General as the shell-behavior control page
- keep gesture controls here even before the gesture implementation is finished

### Calendar

Observed section patterns:

- a `General` toggle group
- list-selection sections for `Calendars`
- list-selection sections for `Reminders`

Observed controls:

- show/hide toggles for calendar visibility behavior
- auto-scroll behavior
- all-day handling
- full-title handling
- colored selection rows for sources

Implication for `Notch-`:

- the local calendar page should stay close to this structure
- once EventKit is wired, replace seeded source rows with live calendars and reminders

### HUDs

Observed section patterns:

- top-level feature enable row
- `General`
- `Open Notch` with `Beta` badge
- `Closed Notch`

Observed controls:

- picker rows such as option-key behavior and progress style
- glow toggle
- tint toggle
- open-notch inclusion toggle
- closed-notch style picker

Implication for `Notch-`:

- when a future `Notch-` page needs both open-shell and closed-shell behavior, use this section split
- this is the best current reference for pages that need per-shell-state configuration

### Battery

Observed section patterns:

- top-level `General`
- feature-specific grouped detail section such as `Battery Information`

Observed controls:

- binary feature toggles only
- simple two-group structure

Implication for `Notch-`:

- this is a good model for compact module pages with low configuration density

## Control Vocabulary

These controls are worth copying exactly when relevant:

- grouped toggle rows with divider rhythm
- trailing-value picker rows
- inline-value sliders
- `Beta` capsule badges in section headers
- colored source-selection rows
- large blank detail-side breathing room below the active grouped sections

## Current `Notch-` Carryover

Already carried into local code:

- split-view shell
- grouped forms
- General gesture section with `Beta` badge
- Calendar source-selection sections

Not yet carried:

- Media page logic
- HUD-specific picker logic
- Battery page logic
- Shortcuts page logic
- Shelf page logic

## Porting Rule

When a future `Notch-` feature needs settings logic that already exists in Boring Notch:

1. copy the section shape from this catalog
2. verify the source file in [Boring Notch source map](./boring-notch-source-map.md)
3. adapt naming and fields to `Notch-` domains without changing the window shell
