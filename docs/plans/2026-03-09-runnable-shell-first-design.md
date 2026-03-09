# Runnable Shell First Design

Date: March 9, 2026
Status: Approved
Scope: Phase 0 shell foundation

## Decision

`Notch-` should start as a runnable macOS app, not as a package-first codebase.

The first implementation milestone should optimize for:

- launching the app locally
- seeing the notch shell on real hardware
- validating focus behavior, geometry, motion, and haptics early
- keeping dedicated unit and UI tests in place from the first slice

## Why

The shell is the product risk in Phase 0.

The main unknowns are:

- `NSPanel` behavior on real displays
- notch geometry on actual hardware
- focus safety
- fullscreen and Spaces coexistence
- haptics quality

Those are easier to validate in a runnable macOS app target than in a library-first setup.

## Recommended First Structure

- one Xcode macOS app target
- one unit test target
- one UI test target
- SwiftUI app entry
- AppKit-owned shell panel lifecycle

## Tradeoff

This may require some structural cleanup later when the shell is extracted into more reusable modules.

That tradeoff is acceptable because early product risk is in shell behavior, not reuse.

## Implementation Bias

Phase 0 should prioritize:

1. runnable shell
2. shell geometry
3. shell state model
4. shell coordinator and windowing
5. shell tests

Only after that should the repo optimize harder for reusable module boundaries.
