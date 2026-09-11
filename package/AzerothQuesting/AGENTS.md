# Azeroth Questing Release Instructions

## Changelog source-of-truth

The repository changelogs are the authoritative source of truth for Azeroth Questing release history:

- `Frostcanvas/AzerothQuesting/CHANGELOG.md` — Azeroth Questing addon releases.
- `Frostcanvas/AzerothQuesting-Companion/CHANGELOG.md` — Azeroth Questing Companion releases.
- `Frostcanvas/AzerothQuestingwebsite/CHANGELOG.md` — Azeroth Questing Website releases.

Update the applicable changelog at the same time a release-worthy change is implemented. Do not reconstruct release history later from memory.

Each Beta must retain its own entry. Continue adding to a Beta only until it is handed off for testing or published, whichever happens first. The next release-worthy change after that starts the next Beta number. Preserve Beta history after Stable release.

Stable promotion always requires explicit approval. GitHub Release notes, website release notes, and other distribution/deployment notes must be prepared from the applicable changelog.

Record compatibility requirements between the addon, Companion, website, and Azeroth Questing Server when relevant. Never claim in-game, Windows, browser, deployment, server, Companion, or other testing succeeded unless that exact test was actually performed.

The addon, Companion, and website version trains are independent. Release-worthy addon and Companion changes remain Beta-first under their existing release rules. Website release-worthy changes follow the website Beta-first rules in `Frostcanvas/AzerothQuestingwebsite/AGENTS.md`.

Do not commit credentials, tokens, private keys, or other secrets.
