# TD-27 USB test: manual values and signed pitch

The separate panel is in **Log**, titled **USB-Schreibtest · Kit 76 · freie
Werteingabe**. It does not connect the offline Studio sliders to the module.
The general TD-17 writer remains disabled for TD-27 (`hasVerifiedMap = false`).

## Next hardware test: negative pitch

1. Keep a full SD-card kit backup. Select test kit copy **76** on the module.
2. Choose **TD-27** for both MIDI input and output.
3. Choose **1. Snare lesen** and check the kit name and values.
4. Select **Snare Head**, **Pitch**, type **-25**, then press **2. Sichern & senden**.
5. Check Head Pitch is -25 on the module and Rim Pitch is unchanged.
6. Use **Letzten Test zurücksetzen** and check the original Head Pitch returns.
7. Copy the log. A successful computer test does not validate hardware writes.

Typing and moving the slider only edit the draft. Neither sends MIDI until
**Sichern & senden** is clicked. Blank, noninteger or out-of-range text disables
sending; it never silently sends the last valid value. Reading or switching
zone/parameter replaces the draft with the last successfully read value.
A typographic minus sign (−) is accepted as well as a keyboard hyphen (-).

## Scope and evidence

Only kit 76, snare head/rim main user samples, device ID 16 are enabled.
Permitted ranges are Instrument Pitch **-100...100**, Decay **1...100**,
from Roland Corporation, *TD-27 Data List*, ©2020, page 7,
Other Instrument Groups / USER SAMPLE:
https://static.roland.com/assets/media/pdf/TD-27_Data_List_eng02_W.pdf
These are not Pad Pitch in cents or Pad Decay.

Controlled hardware tests confirmed independent head/rim Pitch 25 ↔ 30
and Decay 100 ↔ 81 writing, readback and restoration. A module-side setting
of -25 returned nibbles 0E 07: 0xE7 interpreted as signed 8-bit is -25.
The code extends this two's-complement representation over the documented
range; **negative writes and all other intermediate/boundary values are not
yet hardware-tested**. No raw user logs or sample metadata are published here.

No other pads, kit numbers, sample uploads, Program Change, or complete kit
writing are enabled. Select zones explicitly; matching sample IDs/parameter
values are not treated as evidence of a head/rim link flag.

## Backup and verification

Before each write (including restore), the app requires a fresh TD-27 identity,
reads kit name, both sample assignments and both five-byte V-Edit headers,
then saves and rereads a new JSON parameter backup. If saving, connection,
identity, range validation or fresh-state comparison fails, no write is sent.
Only a two-byte parameter payload at the allowlisted address can be sent.
Afterwards both zones and assignments must match the expected snapshot exactly.
No automatic retry or automatic rollback occurs on mismatch/timeout.

Restore returns the last test's one parameter during the same app session.
A second test replaces that session undo target. JSON backups remain after
restart, but there is no JSON import/restore UI yet.

Backups: `~/Library/Application Support/TD27StudioV3/USB-ParameterBackups/`.
**Sicherung im Finder** reveals the latest backup. These are parameter
snapshots, **not complete kit/sample backups**.

## Automated validation

Tests cover the captured -25 byte representation, signed boundaries, exact
address/data/checksum, other-kit/out-of-range rejection, malformed/non-user
sample snapshots, all documented value round trips, preservation of the
nonselected zone, JSON snapshots and invalid/manual input handling.
Native Swift tests and ARM64 app compilation run on macOS CI. They do not
replace the next negative-value write/restore test on real hardware.
