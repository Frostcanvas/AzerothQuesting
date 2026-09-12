**VERSION 0.3.0 Beta 15 - September 11, 2026 - Available on GitHub Pre-release**

* **Redesigned** the floating navigation HUD to be much closer to the compact guide-arrow presentation shown in the in-game comparison: a large filled bright-green directional arrow, minimal translucent backing, centered objective text, and distance immediately underneath instead of a large boxed tracker dominating the screen.

* **Improved** the navigation label so accepted quests prefer the first unfinished WoW objective (for example, a collect/kill instruction) while available quests say **Pick up <quest>** and completed accepted quests say **Turn in <quest>**. The quest name remains visible beside the distance for context.

* **Improved** arrow readability with a dark shadow/outline and text shadows so the HUD stays readable against bright outdoor zones without restoring the heavy panel appearance.

* **Changed** direction rendering to use Blizzard's built-in minimap arrow texture and rotate it toward the existing Azeroth Questing target. If a safe direction cannot be calculated, the arrow hides rather than showing a stale or misleading heading.

* **Kept** movement-speed/ETA calculation out of the HUD because current Retail can expose movement speed as a protected/secret value. Distance remains map-position based, avoiding the taint issue while still providing the useful yard count.

* **Kept** Guide Mode progression, quest-frequency tabs, Azeroth Questing Network protocol, research payloads, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon-only visual/navigation change.

*Beta 15 still requires in-game validation. Verify the green arrow is visible and rotates toward a known quest destination, an active quest shows its current unfinished objective when WoW exposes one, available/turn-in wording is correct, distance remains sensible, Shift-drag positioning still works, and no Lua/taint errors occur. No successful Beta 15 in-game test is claimed yet.*

