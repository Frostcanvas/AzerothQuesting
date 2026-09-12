**VERSION 0.3.0 Beta 12 - September 11, 2026 - Available on GitHub Pre-release**

* **Fixed** overlapping Azeroth Questing Network copies not being deduplicated reliably across multiple WoW transports. During the Beta 11 in-game overlap test, one peer's **Messages** count increased from **9 to 12** after the same logical AZQUEST hello was sent through **PARTY**, **GUILD**, and the custom **CHANNEL**, showing that all three copies were processed instead of one.

* **Improved** inbound duplicate matching by canonicalizing the sender identity before building the deduplication key. Short same-realm names and full `Name-Realm` forms now resolve to a consistent lowercase `name@realm` identity, with realm spaces, hyphens, and apostrophes normalized so transport-specific sender formatting cannot split one peer into separate deduplication keys.

* **Increased** the inbound overlap window from **10 seconds to 20 seconds** so delayed copies from separate WoW transports can still collapse into one logical message. This remains below the addon's normal 30-second hello cadence, so the next scheduled hello can still refresh peer activity normally.

* **Kept** the AZQUEST wire payload, privacy model, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only fix.

*Beta 12 still requires in-game validation. Repeat the controlled overlap test with one sender reachable through PARTY or RAID plus GUILD and CHANNEL: the raw watcher should show multiple transport copies of the same payload while the receiving peer's Messages count increases by exactly one. No successful Beta 12 in-game deduplication test is claimed yet.*

