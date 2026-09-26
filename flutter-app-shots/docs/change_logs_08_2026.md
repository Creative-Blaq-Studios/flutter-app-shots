# Changelog — August 2026

All notable changes to the Flutter App Shots package during August 2026 are
documented here. This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Added `INSTALLATION.md`, a local-machine Codex installation guide covering
  user-wide symlinks, package setup, verification, invocation, updates,
  repository-scoped alternatives, remote-agent boundaries, and uninstall.
- Added `WALKTHROUGH.md`, an implementation-backed explanation of skill
  activation, agent/tool responsibilities, golden and live capture paths,
  composition, validation, regeneration, artifacts, and current limitations.
- Added `references/intake.md`, a mandatory staged question flow covering store
  destinations, exact iPhone/iPad/Android phone/tablet targets, creative
  direction, asset sourcing, capture mode, final-brief confirmation, and raw and
  composed preview approvals.
- Added exact per-shot `deviceClasses` support so a user can select one iPhone
  or Android tablet size without implicitly generating every size in that form
  factor.

### Changed

- Hardened the skill workflow so read-only discovery is the only work allowed
  before the user approves a complete generation brief. Store, target, screen,
  copy, background, asset, capture-mode, and code-patch changes require explicit
  confirmation; silence is not approval.
- Updated golden scaffolding and plan validation to honor exact capture targets
  while retaining broad `formFactors` expansion for older plans.
