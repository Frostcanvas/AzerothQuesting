from pathlib import Path

root = Path('.')
toc = root / 'AzerothQuesting.toc'
changelog = root / 'CHANGELOG.md'

text = toc.read_text(encoding='utf-8')
if '## Interface: 120105' not in text:
    raise SystemExit('Expected Beta 10 Interface 120105 was not found')
if '## Version: 0.3.0-beta.10' not in text:
    raise SystemExit('Expected Beta 10 version was not found')
text = text.replace('## Interface: 120105', '## Interface: 120100', 1)
text = text.replace('## Version: 0.3.0-beta.10', '## Version: 0.3.0-beta.11', 1)
toc.write_text(text, encoding='utf-8')

entry = '''**VERSION 0.3.0 Beta 11 - September 11, 2026 - Available on GitHub Pre-release**\n\n* **Fixed** the Retail TOC interface metadata introduced in Beta 10. Beta 10 incorrectly changed the addon from live Retail interface `120100` to `120105`; as of September 11, 2026, live Retail Midnight 12.1.0 uses `120100`, while `120105` belongs to the 12.1.5 PTR/test client. That future interface value could cause the live Retail client to skip loading Azeroth Questing, making the addon and its Settings page disappear.\n\n* **Restored** `AzerothQuesting.toc` to live Retail interface `120100` and advanced the addon version to `0.3.0-beta.11` because Beta 10 had already been published and consumed before the compatibility mistake was identified.\n\n* **Kept** the Beta 10 Azeroth Questing Network fix unchanged: PARTY, RAID, INSTANCE_CHAT, GUILD, and custom-channel addon messages are still allowed to reach `C_ChatInfo.SendAddonMessage()` unless the real chat-messaging lockdown is active.\n\n* **Kept** the `AZQUEST` protocol, privacy model, Companion handoff, Website behavior, and Azeroth Questing Server schema unchanged. No Companion, Website, or server build is required for this addon compatibility correction.\n\n*Beta 11 has not yet been tested inside World of Warcraft. After updating, use `/reload` or relog and verify Azeroth Questing appears again in the addon list and under **Settings > AddOns**, reports `0.3.0-beta.11`, and then repeat the same-realm PARTY peer test. No successful Beta 11 in-game test is claimed yet.*\n\n---\n\n'''

old = changelog.read_text(encoding='utf-8')
if '**VERSION 0.3.0 Beta 11 -' in old:
    raise SystemExit('Beta 11 changelog entry already exists')
header = '# Azeroth Questing Changelog\n\n'
if not old.startswith(header):
    raise SystemExit('Unexpected changelog header')
changelog.write_text(header + entry + old[len(header):], encoding='utf-8')
