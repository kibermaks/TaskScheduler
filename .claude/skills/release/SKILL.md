---
name: release
description: Full SessionFlow release — bump version, update changelog, build, DMG, commit, tag, push, GitHub release
user_invocable: true
disable-model-invocation: true
---

# Release Workflow

Usage: `/release [minor|major]` — defaults to `minor` (bumps marketing version, e.g. 2.5 → 2.6).
Use `major` for breaking changes (e.g. 2.x → 3.0). `patch` only bumps build number, not marketing version — never use patch for releases.

## Steps

### 1. Check prerequisites

```bash
git status --porcelain
```

If dirty (uncommitted changes), stop and tell the user to commit or stash first.

```bash
git log --oneline $(git describe --tags --abbrev=0)..HEAD
```

Collect all commits since the last tag — used to write the changelog.

### 2. Update CHANGELOG.md

- Read existing `CHANGELOG.md` to see the format
- Add a new `## [X.Y] - YYYY-MM-DD` section at the top (below the header, above the previous version)
- Summarize changes from the git log since last tag:
  - Group into `### Added`, `### Changed`, `### Fixed` — only include sections that have entries
  - Order bullets by importance (most significant first)
  - Keep entries concise — no implementation details, no sub-features when parent is listed
  - PLAIN TEXT ONLY — no bold (`**`), no italic (`_`), no other markdown inside bullet text
  - Do not list internal refactors or build-only changes unless they directly affect users

### 3. Build

```bash
./build_app.sh [minor|major]
```

Note: `patch` only bumps the build number, NOT the marketing version. Use `minor` to go from X.Y to X.(Y+1), `major` for (X+1).0.

Confirm the output says the correct new version (e.g. `version 2.6 (build 720) is ready`).

### 4. Create DMG and ZIP

```bash
./create_dmg.sh
```

The DMG is created in the project root as `SessionFlow-{VERSION}.dmg`.

Then create the ZIP:

```bash
zip SessionFlow-{VERSION}.zip SessionFlow-{VERSION}.dmg
```

### 5. Commit, tag, push

Stage only CHANGELOG and the project file (version bump):
```bash
git add CHANGELOG.md SessionFlow.xcodeproj/project.pbxproj
git commit -m "chore: release version {VERSION}

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git tag v{VERSION}
git push origin main --tags
```

### 6. Create GitHub release

```bash
gh release create v{VERSION} \
  "SessionFlow-{VERSION}.dmg" \
  "SessionFlow-{VERSION}.zip" \
  --title "SessionFlow {VERSION}" \
  --notes "RELEASE_NOTES"
```

Release notes = the new CHANGELOG section content, plain text, no markdown formatting.

### 7. Report

Tell the user the release URL returned by `gh release create`.

## Common mistakes to avoid

- Do NOT use `patch` for a user-facing release — it only bumps build number
- Do NOT use bold/italic in changelog bullets or release notes — it is not parsed
- Do NOT `git add -A` — only stage CHANGELOG.md and project.pbxproj
- Do NOT create the GitHub release before pushing the tag
- DMG and ZIP are in the project root, not a subdirectory
