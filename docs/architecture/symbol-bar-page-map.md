# Notch- Symbol Bar Page Map

Date: March 11, 2026
Status: Active

## Purpose

This document defines the open-shell top-bar page routing for `Notch-`.

The goal is a clean and stable symbol order so the notch behaves like a single control and monitoring center.

## Page Order

The page order is fixed:

1. home
2. notifications
3. calendar
4. media control
5. habits
6. agents
7. openclaw
8. HUD
9. localhost
10. financial board

## Side Grouping

Pages are split across both sides of the notch:

- Left side: home, notifications, calendar, media control, habits, agents, openclaw
- Right side: HUD, localhost, financial board

## SF Symbol Mapping

- home: `house.fill`
- notifications: `bell.fill`
- calendar: `calendar`
- media control: `playpause.fill`
- habits: `checkmark.circle.fill`
- agents: `bolt.badge.clock`
- openclaw: `pawprint.fill`
- HUD: `microphone.circle`
- localhost: `server.rack`
- financial board: `dollarsign.circle`

## Implementation References

- `/Notch-/Shell/UI/ShellHeaderView.swift`
- `/Notch-/Shell/UI/Open/ShellOpenContentView.swift`
- `/Notch-/Shell/Core/ShellViewModel.swift`
