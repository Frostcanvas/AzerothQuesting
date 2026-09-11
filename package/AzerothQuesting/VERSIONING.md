# Azeroth Questing Addon Versioning

Azeroth Questing uses a beta-first release train.

## Canonical addon versions

The addon version in `AzerothQuesting.toc`, GitHub tags, release packages, and updater comparisons stays canonical:

- `0.3.0-beta.1`
- `0.3.0-beta.2`
- `0.3.0-beta.3`
- `0.3.0`

Beta builds may only be published as GitHub Pre-releases. The final/golden version is published as a normal GitHub Release only after explicit Stable-release approval.

Semantic ordering is authoritative:

`0.2.32` < `0.3.0-beta.1` < `0.3.0-beta.2` < `0.3.0`

## Player-facing display

Player-facing tools may present the canonical version more readably:

- `0.3.0-beta.1` -> **0.3.0 Beta 1**
- `0.3.0-beta.8` -> **0.3.0 Beta 8**
- `0.3.0-rc.1` -> **0.3.0 RC 1**
- `0.3.0` -> **0.3.0**

The Companion performs this presentation cleanup without changing the underlying addon version used for update comparison.

If Azeroth Questing is later distributed on CurseForge or another addon platform, the platform's Beta/Release file classification should match the same GitHub prerelease/stable status. Do not list a platform as available until the addon has actually been published there.

## Channels

- Stable channel must not install prerelease addon builds.
- Beta channel may install newer prereleases and later Stable/golden releases.
- An installed beta must not be replaced by an older Stable build.
- The current addon development train after Stable `0.2.32` is `0.3.0-beta.1`.

## Continuous changelog workflow

`CHANGELOG.md` is maintained continuously during addon development rather than reconstructed at release time.

- Every release-worthy addon code change must update `CHANGELOG.md` in the same development change that bumps `AzerothQuesting.toc`.
- Each Beta section describes the delta from the immediately previous Beta or Stable build. For example, `0.3.0 Beta 2` records what changed after `0.3.0 Beta 1` and does not rewrite the Beta 1 history.
- Additional fixes before Stable increment the Beta seed and create a new changelog section (`beta.1` -> `beta.2` -> `beta.3`).
- Keep all Beta sections after the golden release so the complete test history remains available.
- When Stable/golden release is explicitly approved, add a new Stable section that consolidates all player-visible changes since the previous Stable release, removes duplicate wording, and is ready to use for GitHub or distribution release notes.
- The Stable summary does not erase or replace the individual Beta sections.
- Use the actual change date on every section and keep GitHub listed as an available platform. Do not list CurseForge, Wago, WowUp, or another platform until the addon has actually been published there.
- Include outstanding in-game test instructions with Beta changes. Never describe an addon change as successfully tested in World of Warcraft unless that specific behavior was actually tested there.
- When a protocol or data-format change depends on a Companion or server/API version, record the compatibility requirement in the applicable changelog sections.
- When preparing a GitHub Release or another distribution listing, use the matching `CHANGELOG.md` section as the release-note source instead of reconstructing the changes from commit history.

Documentation-only maintenance does not force an addon version bump because no addon code changed.