# TD-27 USB test (experimental)

This build adds a separate panel in **Log**. It does not connect the offline
Studio sliders to the hardware and does not enable the general TD-17 writer
for TD-27. `hasVerifiedMap` remains false.

## First hardware test

1. Keep a full SD-card kit backup. Select your test kit copy **76** on the module.
2. Choose **TD-27** for both MIDI input and output.
3. In Log choose **1. Snare lesen** and check the displayed kit name and values.
4. Select Head, Pitch, 25 and press **2. Sichern & senden**.
5. Check the module display and sound. The app reads back both zones and their
   instrument assignments; any unexpected difference is a failed verification.
6. Use **Letzten Test zurücksetzen** and verify the original value at the module.
7. Copy the log for assessment. A successful computer test is not hardware validation.

## Deliberately narrow scope

Only kit 76, snare head/rim main user samples, device ID 16, Pitch 0/25/30,
and Decay 81/100 are enabled. These are the values observed in controlled
hardware read captures. No negative pitch, other pads, sample uploads,
Program Change, or complete kit writing is enabled. Select zones explicitly;
no head/rim link status is inferred from matching sample IDs or values.

Before each write (including restore), the app requires a fresh TD-27 identity,
reads kit name, both sample assignments and both five-byte V-Edit headers,
then saves and rereads a new JSON parameter backup. If saving, connection,
identity, supported-value validation or fresh-state comparison fails, no write
is sent. Only a two-byte allowlisted parameter payload can be sent. Following
it, both zones and assignments must match the expected snapshot exactly.
No automatic retry or automatic rollback is performed on a mismatch/timeout.
The user can request restore of the last test's one parameter during the same
app session. The saved JSON remains after restart, but there is no JSON import
restore UI yet. A second successful test replaces the session's undo target.

Backups: `~/Library/Application Support/TD27StudioV3/USB-ParameterBackups/`.
The **Sicherung im Finder** button reveals the latest backup. These are
parameter snapshots, **not complete kit/sample backups**.

## Validation

Unit tests cover observed nibble values, exact outgoing address/data/checksum,
rejection of unverified values/kit numbers, malformed snapshots, non-user-sample
banks and preservation of the nonselected zone in expected readback.
Native compilation/tests run on macOS CI. Live writes and audible behavior
require testing on the connected TD-27; they are not claimed as validated here.
No user logs or sample files are included in this repository change.
