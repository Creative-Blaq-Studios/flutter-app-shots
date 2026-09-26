# Install Flutter App Shots for Codex

This guide installs the `flutter-app-shots` skill for local Codex agents by
creating a symbolic link from Codex's user skill directory to this repository.
The repository remains the single source of truth: when files here change, new
agent runs use the updated skill without copying or reinstalling it.

This installation method is intended for Codex sessions running on the same
machine, as the same operating-system user, with access to the source folder.

## Why use a symbolic link?

Copying the skill into an agent directory creates two versions that can drift.
A symbolic link keeps only one working copy:

```text
$HOME/.agents/skills/flutter-app-shots
    → /absolute/path/to/flutter-app-shots
```

Codex officially supports symlinked skill folders and follows the target while
scanning user and repository skill locations. Codex can invoke a discovered
skill explicitly with `$flutter-app-shots`, or implicitly when a request
matches the description in `SKILL.md`. See the
[official OpenAI Build Skills guide](https://learn.chatgpt.com/docs/build-skills).

## How each teammate chooses the correct source

Each teammate may clone the repository anywhere on their own machine. The
source path is not shared or hard-coded; it is always the `flutter-app-shots`
directory inside that teammate's checkout:

```text
<teammate's fappshots checkout>/flutter-app-shots
```

For example, if a teammate clones the repository to:

```text
/Users/alex/code/fappshots
```

their skill source is:

```text
/Users/alex/code/fappshots/flutter-app-shots
```

and their user-wide link is:

```text
/Users/alex/.agents/skills/flutter-app-shots
```

They must not reuse another teammate's absolute source path.
`$HOME` resolves the user-wide destination correctly for whoever runs the
installation commands.

The link points to the whole `flutter-app-shots` directory, not the repository
root, `tool/`, or `SKILL.md` directly. The correct source directory contains all
of these entries:

```text
flutter-app-shots/
├── SKILL.md
├── tool/
├── renderer/
├── flows/
└── fixture_app/
```

## Prerequisites

Install or make available:

- Codex CLI, the Codex IDE extension, or the ChatGPT desktop app with Codex;
- Flutter 3.27 or later;
- Dart 3.5 or later; and
- a local checkout containing the complete `flutter-app-shots/` directory.

Flutter normally supplies a compatible Dart SDK. Confirm the active tools:

```bash
flutter --version
dart --version
```

If the source lives on an external disk, mount that disk before starting
Codex. A symbolic link cannot resolve while its target volume is unavailable.

## Step 1: choose the source and link paths

From the root of the teammate's local `fappshots` checkout, set the paths from
the current directory:

```bash
cd /absolute/path/to/your/fappshots-checkout

REPOSITORY_ROOT="$PWD"
SKILL_SOURCE="$REPOSITORY_ROOT/flutter-app-shots"
SKILL_LINK="$HOME/.agents/skills/flutter-app-shots"
```

If the repository has not been cloned yet, clone it to any writable local
location first, then run the commands above from that checkout:

```bash
git clone https://github.com/Creative-Blaq-Studios/flutter-app-shots.git /absolute/path/to/your/fappshots-checkout
cd /absolute/path/to/your/fappshots-checkout
```

Confirm that the selected directory is the root of the skill pack:

```bash
test -f "$SKILL_SOURCE/SKILL.md" && echo "SKILL.md found"
test -f "$SKILL_SOURCE/tool/pubspec.yaml" && echo "Dart tool found"
test -f "$SKILL_SOURCE/renderer/pubspec.yaml" && echo "Flutter renderer found"
```

Do not continue until all three checks print successfully.

## Step 2: create the user-wide Codex link

Create the user skill directory if needed:

```bash
mkdir -p "$HOME/.agents/skills"
```

Inspect the destination before creating anything:

```bash
ls -ld "$SKILL_LINK" 2>/dev/null || echo "Destination is available"
```

If the destination is available, create the symbolic link:

```bash
ln -s "$SKILL_SOURCE" "$SKILL_LINK"
```

Do not add `-f` and do not delete an existing destination automatically. If a
file, directory, or link already exists there, inspect it and decide whether it
is another installation that must be preserved.

Why this location:

- `$HOME/.agents/skills` is the Codex user scope;
- skills there are available across repositories for that local user; and
- one link is enough for local Codex agents that share the same user and
  filesystem.

## Step 3: resolve the bundled packages

The skill contains a Dart CLI and a Flutter renderer. Resolve each package from
the source checkout:

```bash
cd "$SKILL_SOURCE/tool"
dart pub get

cd "$SKILL_SOURCE/renderer"
flutter pub get
```

Run these commands again whenever either `pubspec.yaml` changes. Package update
notices are informational unless dependency resolution fails.

## Step 4: verify the symbolic link

Confirm that the destination is a link and print its target:

```bash
test -L "$SKILL_LINK" && echo "Skill link exists"
readlink "$SKILL_LINK"
```

The printed target should equal `SKILL_SOURCE`. Confirm that files are readable
through the link:

```bash
sed -n '1,7p' "$SKILL_LINK/SKILL.md"
```

The output should begin with frontmatter containing:

```yaml
---
name: flutter-app-shots
description: Use when a Flutter developer wants App Store / Play Store marketing screenshots generated from their app.
---
```

The real description is longer; only the `name` must exactly match
`flutter-app-shots` for the explicit invocation shown below.

## Step 5: run a smoke test through the link

Point the doctor at any Flutter application. This example uses the bundled
fixture app:

```bash
cd "$SKILL_LINK/tool"
dart run app_shots doctor \
  --app-dir "$SKILL_LINK/fixture_app" \
  --image-gen false
```

A healthy local installation reports:

```json
{
  "flutter": true,
  "tool": {"resolved": true},
  "renderer": {"resolved": true},
  "targetApp": {"pubspec": true},
  "readyForGolden": true
}
```

The actual response includes additional paths and notes. With
`--image-gen false`, a note explaining that CSS backgrounds will be used is
expected and is not a failure.

## Step 6: make Codex discover the skill

Codex detects skill changes automatically. If the skill does not appear in an
already-running session, restart Codex or begin a new session.

In Codex CLI or the IDE extension:

1. Run `/skills` and confirm that `flutter-app-shots` appears.
2. Type `$flutter-app-shots` to invoke it explicitly.

Start Codex from the Flutter project that should receive the screenshots:

```bash
cd /absolute/path/to/your_flutter_app
codex
```

Then give it a prompt such as:

```text
$flutter-app-shots Generate App Store and Play Store marketing screenshots for
this Flutter app. Use golden capture unless a screen requires live mode.
```

Codex may also activate the skill implicitly for a matching request:

```text
Create polished App Store screenshots for this Flutter app.
```

Explicit invocation is preferable when testing an installation because it
removes ambiguity about which workflow should run.

## What happens on the first run

The skill is an agent-orchestrated workflow, not a single installer command.
After invocation, the agent will:

1. run the doctor and capture-mode preflight;
2. inspect the target Flutter application;
3. propose three to five screens, copy, tone, device form factors, and asset
   sources;
4. stop for the mandatory scope and asset-source confirmation;
5. scaffold and fill deterministic Flutter capture harnesses;
6. capture and visually inspect the real screen widgets;
7. compose exact-size store images; and
8. validate and report the output set.

See [`WALKTHROUGH.md`](WALKTHROUGH.md) for the complete implementation and data
flow.

## Manual CLI verification against a target app

The agent normally runs these commands, but they are useful when diagnosing an
installation:

```bash
cd "$SKILL_LINK/tool"

dart run app_shots doctor \
  --app-dir /absolute/path/to/your_flutter_app \
  --image-gen true

dart run app_shots preflight \
  --mode golden \
  --app-dir /absolute/path/to/your_flutter_app

dart run app_shots --help
```

Use `--image-gen false` when the current agent cannot generate background
images. Golden capture itself does not require an image generator.

## Keeping the installed skill updated

The symbolic link needs no update when skill files change. Edit or pull changes
in the source checkout:

```bash
cd "$SKILL_SOURCE"
git status --short
git pull --ff-only
```

Review any local changes before pulling. Use the repository's normal update
workflow when a fast-forward pull is not appropriate.

New Codex runs will read the updated `SKILL.md`, scripts, tool sources, renderer,
templates, and documentation through the same link.

After dependency-file changes, refresh packages:

```bash
cd "$SKILL_SOURCE/tool"
dart pub get

cd "$SKILL_SOURCE/renderer"
flutter pub get
```

If an updated skill name or description is not visible, restart Codex. A
session that has already loaded the full skill may continue using the version
that was in its context, so start a fresh session when verifying critical skill
changes.

## Repository-scoped alternative

The user-wide link is recommended when this skill should be available in every
local repository. For one repository only, link it under that repository's
`.agents/skills` directory:

```bash
TARGET_REPOSITORY="/absolute/path/to/one/repository"

mkdir -p "$TARGET_REPOSITORY/.agents/skills"
ln -s "$SKILL_SOURCE" \
  "$TARGET_REPOSITORY/.agents/skills/flutter-app-shots"
```

Do not commit an absolute local symlink for a team unless every machine uses
the same path. For portable team distribution, put the skill directory in the
repository or package it as a plugin.

Codex scans `.agents/skills` from the current working directory up through the
repository root. If user- and repository-scoped installations share the same
skill `name`, Codex may show both rather than merging them.

## Moving the source checkout

Moving or renaming the source directory breaks the existing link. Verify that
the destination is still a symbolic link, remove the link only, then recreate
it with the new source path:

```bash
test -L "$SKILL_LINK" && readlink "$SKILL_LINK"
unlink "$SKILL_LINK"

SKILL_SOURCE="/new/absolute/path/to/flutter-app-shots"
ln -s "$SKILL_SOURCE" "$SKILL_LINK"
```

`unlink` removes only the symbolic link. It does not delete the source
directory or any skill files.

## Uninstalling the local skill

First verify the target:

```bash
test -L "$SKILL_LINK" && readlink "$SKILL_LINK"
```

Then remove only the link:

```bash
unlink "$SKILL_LINK"
```

The repository remains unchanged and can be linked again later.

## Local versus remote agents

This symbolic-link installation works only where the source path is reachable.

| Agent environment | Can use this link? | Requirement |
| --- | --- | --- |
| Local Codex CLI/IDE/Desktop session under the same user | Yes | Source disk is mounted |
| Local Codex subagent sharing the same filesystem | Yes | Parent environment exposes user skills |
| Another macOS user | No | Create a link in that user's skill directory |
| Another computer | No | Clone/copy the source and create a link there |
| Container or virtual machine | Usually no | Mount the source and create a link inside the environment |
| Codex cloud or another remote agent | No | Check in/install the skill remotely or distribute it as a plugin |

This guide documents Codex discovery. Other agent hosts may use different skill
directories even when they support the same `SKILL.md` format; follow that
host's installation rules rather than assuming it scans `$HOME/.agents/skills`.

## Troubleshooting

### The skill does not appear in `/skills`

Verify each layer:

```bash
test -L "$SKILL_LINK" && echo "link: OK"
test -f "$SKILL_LINK/SKILL.md" && echo "SKILL.md: OK"
readlink "$SKILL_LINK"
```

Then restart Codex. Also search the current repository for another
`.agents/skills/flutter-app-shots` installation that could create a duplicate.

### The link exists but files cannot be read

The source directory was moved, renamed, deleted, or its external volume is not
mounted. Run `readlink "$SKILL_LINK"`, restore that path, or follow “Moving the
source checkout” above.

### Doctor reports `tool.resolved: false`

Run:

```bash
cd "$SKILL_SOURCE/tool"
dart pub get
```

### Doctor reports `renderer.resolved: false`

Run:

```bash
cd "$SKILL_SOURCE/renderer"
flutter pub get
```

### Doctor reports `targetApp.pubspec: false`

Pass the Flutter application root—the directory containing its
`pubspec.yaml`—to `--app-dir`.

### `flutter` or `dart` is not found

Install Flutter and add its `bin` directory to the shell `PATH`, then open a new
terminal and rerun `flutter --version` and `dart --version`.

### An update is not visible to an active agent

Restart Codex or start a fresh session. The link exposes the updated files
immediately, but an active run may already have loaded older instructions into
its context.
