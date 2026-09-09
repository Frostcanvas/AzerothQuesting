# Azeroth Questing P2P Diagnostics

The `0.3.0-beta.1` development build includes a temporary in-game peer panel for testing the Azeroth Questing Network.

Open it with:

- `/aq peers`
- `/aq p2p`
- `/aq network peers`

The panel shows Azeroth Questing characters that have sent valid `AZQUEST` addon traffic during the current WoW UI session. It displays the sender name, addon version when learned from a hello message, last-seen state, and the number of network messages observed from that peer.

New beta clients announce their presence about every 30 seconds. A peer is shown as **Active** when it has been heard from within the last 90 seconds; older session entries remain visible as **Idle** so temporary disconnect/reconnect behavior is easier to test.

This panel is diagnostic-only. Peer character names exist only in memory for the current WoW session. They are not written to `ZoneQuestGuideDB`, are not added to Companion `AQO1` records, and are not uploaded to the Azeroth Questing Server. Quest evidence received from peers continues to enter the existing anonymous `source = "peer"` research path without the sender identity.

## Test checklist

Use two Retail clients that can see the same `AzerothQuesting` custom-channel scope:

1. Load `0.3.0-beta.1` on both clients and run `/aq network` to confirm the `AZQUEST` prefix is registered and the custom channel is joined.
2. Open `/aq peers` on both clients. Allow up to 30 seconds for the periodic hello announcement, or click **Announce / Refresh**.
3. Confirm each client sees the other character, the addon version is populated, and **Last Seen** refreshes as hello/evidence traffic arrives.
4. Generate quest evidence on one client and confirm the other client's message count increases.
5. Close or disconnect one client and confirm it changes from **Active** to **Idle** after roughly 90 seconds.
6. Reload the receiving UI and confirm the old peer-name list is gone, demonstrating that peer identity is not persisted.
7. Separately verify peer quest observations still synchronize through the Companion with `source = "peer"` and without sender identity.

No successful World of Warcraft test is claimed until these checks are actually performed in-game.
