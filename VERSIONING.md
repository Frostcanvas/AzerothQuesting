# Azeroth Questing Addon Versioning

Azeroth Questing uses a beta-first release train.

## Canonical addon versions

The addon version in `AzerothQuesting.toc`, GitHub tags, release packages, and updater comparisons stays canonical:

- `0.2.33-beta.1`
- `0.2.33-beta.2`
- `0.2.33-beta.3`
- `0.2.33`

Beta builds may only be published as GitHub Pre-releases. The final/golden version is published as a normal GitHub Release only after explicit Stable-release approval.

Semantic ordering is authoritative:

`0.2.32` < `0.2.33-beta.1` < `0.2.33-beta.2` < `0.2.33`

## Player-facing display

Player-facing tools may present the canonical version more readably:

- `0.2.33-beta.1` -> **0.2.33 Beta 1**
- `0.2.33-beta.8` -> **0.2.33 Beta 8**
- `0.2.33-rc.1` -> **0.2.33 RC 1**
- `0.2.33` -> **0.2.33**

The Companion performs this presentation cleanup without changing the underlying addon version used for update comparison.

If Azeroth Questing is later distributed on CurseForge or another addon platform, the platform's Beta/Release file classification should match the same GitHub prerelease/stable status. Do not list a platform as available until the addon has actually been published there.

## Channels

- Stable channel must not install prerelease addon builds.
- Beta channel may install newer prereleases and later Stable/golden releases.
- An installed beta must not be replaced by an older Stable build.
- The next addon development train after Stable `0.2.32` is `0.2.33-beta.1` when addon code is next changed.
