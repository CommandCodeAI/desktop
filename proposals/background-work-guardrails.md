# Proposal: Protect the desktop app from excessive background work

**Status:** Proposal for maintainer review
**Related issue:** [Command Code Desktop #109](https://github.com/CommandCodeAI/desktop/issues/109)

## Problem

The report describes an agent task launching more than 20 concurrent CPU-heavy subprocesses through the desktop app. The machine became difficult to use, and the app offered no clear indication or limit for the active work. The measurements are from one macOS incident. The application process and task lifecycle have not been inspected, so the responsible layer is unknown.

## Goal

Keep ordinary parallel work available while helping prevent an agent task from saturating the user's machine. Make active background work understandable to the user and ensure any safeguard has clear behavior when its limit is reached.

## Questions to resolve in the private application code

1. Which component creates and tracks desktop-launched processes, and can it reliably identify background work and associate child processes with a task?
2. Is an app-level limit, a queue, or a warning the least disruptive first safeguard?
3. What should count toward a limit: launched tasks, child processes, or measured resource use? A task count is easier to enforce, but cannot predict CPU cost.
4. Where should users see active work, and how can they stop or inspect it?
5. How should limits behave across projects, sessions, app restarts, and platforms?

## Candidate direction

Start with visibility into active work and a configurable admission limit at the component that owns process creation. If the limit is reached, return an explicit explanation and let the agent or user finish or stop existing work before retrying.

A warning before the limit may help preserve workflow, but should not replace a reliable bound if testing shows the failure can still saturate a machine. A queue is another option, though it needs explicit cancellation and ordering behavior.

Do not infer a safe default from CPU core count alone. The reported machine had 10 cores and still became unusable. Validate defaults across workloads and platforms, and avoid presenting a task-count limit as a measure of actual resource usage.

## Validation to consider

Test controlled workloads that launch many CPU-bound children, confirm the UI stays responsive, verify active-work visibility and stop behavior, and confirm the limit does not break ordinary parallel operations. Include Windows, macOS, and Linux where the process manager is shared. Record which behavior was verified on a real desktop build.

## Scope

This proposal changes documentation only. The public `CommandCodeAI/desktop` repository contains installers and issue tracking. The application source is private. No implementation, runtime test, or process-ownership claim is included here.
