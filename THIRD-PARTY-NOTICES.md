# Third-party notices

PulsoKit retains its original MIT license (LICENSE).

The TD27InstrumentNames.swift instrument-name table is derived from Jon Skeet's
V-Drum Explorer InstrumentGroups.json at commit
99cce6de79c9bf946b370374e889fbeb7e7c697e:
https://github.com/jskeet/DemoCode/blob/99cce6de79c9bf946b370374e889fbeb7e7c697e/Drums/VDrumExplorer.Model/SchemaResources/TD27/InstrumentGroups.json

Copyright Jon Skeet and contributors. Apache License 2.0, included in
Licenses/DemoCode-Apache-2.0.txt. Modified on 2026-10-28: extracted the numerical
instrument IDs and labels into a Swift lookup table; omitted V-Edit defaults.
Unknown IDs are displayed numerically, never substituted with guessed sounds.
The schema is also cited as a source of read-only SysEx field descriptions.
