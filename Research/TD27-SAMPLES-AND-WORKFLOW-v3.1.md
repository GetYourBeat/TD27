# TD-27 samples and kit workflow — research, 2026-10-28

## What is established

Roland describes the TD-27 as combining sampled source material and behavioral
modeling. Its factory sound engine is not documented as a user-loadable multisample
container. No verified number of stored velocity layers per factory instrument,
round-robin count, or factory waveform compression/packing specification was found.
These quantities remain **unknown**, not zero and not an assumed layer count.

Ari Rosenschein's interview with Roland engineers Shun Takai and Ryo Takasaki
(2021-08-05) discusses separating drum components and more than fifty recorded hits
across dynamics for analysis. It does not establish fifty playback layers in TD-27.
The interview is about the broader modeling engine and also discusses TD-50X;
it cannot establish a TD-27 binary format.
https://articles.roland.com/roland-engineering-understanding-prismatic-sound-modeling/

Roland's TD-27 product page (undated, retrieved 2026-10-28) documents Prismatic
Sound Modeling, 100 kits, up to 500 user samples and 24 minutes mono / 12 stereo.
https://www.roland.com/global/products/td-27/

Roland Corporation, TD-27 Data List eng02, ©2020, pp. 7–8: User Sample pitch
-100…100, decay 1…100; Main and Sub per trigger zone; MIX, FADE1, FADE2, FADE3,
SWITCH and fade point 1…159 for the documented legacy modes. Internal modeled
instruments can be combined with imported user audio. This gives two selectable
sounds per zone, not an arbitrary stack of velocity WAV layers.
https://static.roland.com/assets/media/pdf/TD-27_Data_List_eng02_W.pdf

Roland Support, updated 2025-01-07: WAV import uses the SD IMPORT directory,
44.1 kHz and 16/24 bits. No supported bulk WAV upload/download command over USB
was found. USB audio streaming is distinct from copying a sample into user memory.
https://support.roland.com/hc/en-us/articles/360042928711-TD-27-Notes-Regarding-Importing-Samples-wav-files

## Complete kit transfer and destinations

Roland Corporation, TD-27 Reference Manual eng02, ©2020, pp. 49–50: 1 KIT SAVE
with User Sample includes assigned audio. 1 KIT LOAD selects the SD file and User
destination independently. Included samples are allocated on import and assigned
to the loaded kit. Therefore a KIT-050.TD0 filename does not force module slot 50.
The app exports an explicit destination instruction, not a fictional embedded
bank-selection command. The destination kit must be backed up before import.
https://static.roland.com/assets/media/pdf/TD-27_Reference_eng02_W.pdf

## Implementation and evidence boundaries

- USB kit names: 100 separate requests; selected kit: all 24 zone Main/Sub
  assignments, common parameter blocks and V-Edit blocks. Every selected-kit block
  is read twice and compared. This is NOT a complete backup: no sample audio,
  complete global effects or opaque TD0 container are reconstructed from MIDI.
- Address arithmetic: public Jon Skeet V-Drum Explorer TD27 Root/Kit schemas,
  corroborated by prior hardware captures at kit 1 and kit 76. New whole-kit browser
  reads still require hardware acceptance. No whole-kit write or copy is enabled.
- User-sample names require TD0 metadata. USB-only rows show U001…U500 references;
  they do not invent names or silently associate an unrelated library file.
- Complete editable input is a TD0 file from SD. All embedded samples, including
  Sub-only samples, are extracted into the library. Files remain untouched.
- Original sample packing remains the observed 16-bit PCM planar format documented
  in EXPORT-V2.md. This is user-sample storage, not factory sound-engine packing.
- Legacy TD0 layer record: common +5 enabled, +6 mode, +8 little-endian fade point.
  Independent source files contain MIX=0, FADE3=3 and SWITCH=4; observed fade points
  include 50 and 87. +7 padding is retained. The ordering agrees with the public
  KitPadCommon schema. FADE1/FADE2 values are schema-derived, not separately
  hardware-tested. Layer changes are file edits only and need import acceptance.
- Main and Sub instrument records have the same 28-byte stride; Sub V-Edit starts
  at 0xD1C, following the Main 24 x 24-byte region. Untouched bytes are retained.
- Existing 2.21 files remain inspect/copy-only. Neither a guessed container nor a
  silent conversion to 1.02 is performed.

Sources for read-only addresses and record semantics (Jon Skeet and contributors,
commit 99cce6de79c9bf946b370374e889fbeb7e7c697e):
https://github.com/jskeet/DemoCode/tree/99cce6de79c9bf946b370374e889fbeb7e7c697e/Drums/VDrumExplorer.Model/SchemaResources/TD27/Physical

## How to build responsive custom sounds

For a soft/hard pair, assign soft Main and hard Sub with SWITCH and a chosen fade
point. For smooth reinforcement, retain a modeled factory Main and add a WAV Sub
with a fade mode. MIX layers both. These are the module's available arrangements;
this release does not claim to reproduce Roland's factory modeling, positional
response, arbitrary round robins, or a separate sample for every velocity.
