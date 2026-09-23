# Proposal: Recover from interrupted desktop drag sessions

**Status:** Proposal for maintainer review
**Related issue:** [Command Code Desktop #108](https://github.com/CommandCodeAI/desktop/issues/108)

## Problem

The report describes the “drop to attach” overlay remaining visible after a drag source exits before the desktop window receives a terminal drag event. The renderer also appeared to remain busy until the window was reloaded. The reported observations are from one macOS incident. The cause has not been confirmed against the private application source.

## Proposal

Inspect the desktop renderer's drag lifecycle and ensure an interrupted drag cannot leave the interface in a receiving state indefinitely. Candidate measures for maintainers to evaluate:

- Keep explicit state for an active drag and route all teardown paths through one cleanup operation.
- Clear state on the terminal drag events the platform supplies, and consider focus loss and Escape where appropriate.
- Add a bounded watchdog only if the renderer cannot otherwise establish that a drag is still active. Refresh it only while events indicate an active drag.
- Stop overlay animation or repaint work when no drag is active.
- Add diagnostics for state transitions if they can be logged without exposing dragged content.

These are investigation options, not requirements. A timeout can dismiss a legitimate slow drag, so its behavior and interval need to be chosen and tested against the actual application.

## Validation to consider

Test normal file attachment and cancellation, source termination mid-drag, window focus changes, and Escape. Confirm the overlay clears without a reload and the renderer returns to idle. Verify the watchdog does not interrupt a valid drag and that diagnostics contain no file contents or sensitive paths.

## Scope

This proposal changes documentation only. The public `CommandCodeAI/desktop` repository contains installers and issue tracking. The application source is private. No implementation, runtime test, or renderer-level root cause is claimed here.
