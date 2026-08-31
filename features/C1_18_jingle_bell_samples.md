---
DOCUMENT TYPE: Holiday Sleigh Bells Feature
DOCUMENT TITLE: The Real Bells You Hear, and the Real Bells You See
CONFIDENTIALITY: Vertex11 Confidential
VERSION: 0.4
AUTHOR: George Ruzek
VALUE STATEMENT: Replaces the placeholder jingle with the professionally recorded bell strikes, lets the strength of a shake pick which one you hear, and puts the two instruments that were actually recorded on the screen you choose from.
LAST UPDATED: August, 31, 2026 12:52
---

# The Real Bells You Hear, and the Real Bells You See

## Summary

The Recorded Bell Samples feature (C1_18) replaces the single placeholder recording each bell carries with banks of the professionally recorded sleigh bell samples delivered into `sounds/v2/`, and brings the bell selection screen into agreement with them. Each bell holds a piano bank and a forte bank instead of one recording. A detected stop at level 1 or 2 draws at random from the piano bank, a stop at level 3, 4, or 5 draws at random from the forte bank, and no recording is ever heard twice in a row. A bell whose recordings carry no dynamic layers holds them all in one bank and sounds that bank at every level. The loudness ramp that already scales a stop from quiet to loud is unchanged and continues to apply on top of the recording chosen. On the selection screen, the green shaker is retired, the two instruments that were actually recorded take the first two slots, and the third slot becomes a new scene showing both of them together, overlapping and slightly angled, as though both are being shaken. The five placeholder recordings retire to the legacy archive alongside the green shaker.

## Background

Every bell in the application sounds one recording. `app/instrument_definition.gd` carries a single `sound` property, `shake/responses/jingle_response.gd` builds a pool of audio players all pre-loaded with that one recording, and each detected stop plays the next voice in the pool at a volume scaled by how hard the shake was. The result is that a gentle shake and a violent one are the same recording at different volumes. Real sleigh bells do not work that way: struck hard, they are not merely louder, they are brighter and busier, with more of the bells in the cluster sounding and a different attack. Volume alone cannot produce that, and the application has been asking one recording to stand in for the whole dynamic range of the instrument.

That limitation was understood when the shake instrument was built, and both files say so in their own comments. The instrument resource records that "sounding a different take per intensity level later replaces this with an array indexed by `ShakeEvent.level`", and the jingle response records the same intention and adds that doing so "changes nothing outside this file". This feature is the one that does it. The detector has been handing every responder a `level` from 1 to 5 since the Shake It Discovery feature (C1_09) established the firing rules from measured device data, and until now nothing has used it.

The recordings themselves are the delivery of the Professional Audio Recording task (`C1_T04`) on the MVP1 roadmap, which has been in progress against Julie's production schedule. Three sets arrived, named Type A, Type B, and Type C. Type A carries fourteen piano takes and fourteen forte takes. Type B carries twenty-five takes that are not split by dynamic. Type C carries three piano takes and five forte takes. A sustained loop recording was delivered with each set and has been removed from the repository as unused; nothing in this feature refers to one.

There is a second gap this feature closes, and it is on the screen rather than in the sound. The bell selection screen offers three instruments, and one of them is a green stick shaker that no longer belongs there. Only two physical instruments were recorded: Type A and Type B are the two of them, and Type C is a recording of both being shaken together. The green shaker is therefore not one of the recorded instruments at all — it is a leftover from the placeholder era, it carries a visible maker's logo in its artwork, and whatever it were assigned to play would be a lie about what the audience is looking at. Meanwhile the pairing that Type C actually represents has no artwork on the screen. Correcting both is one change: retire the shaker, and give the third slot a scene showing the two real instruments together.

One capability is deliberately deferred and detailed under Future work: reducing the size the recordings add to the application bundle.

## Value Delivered

- **The instrument finally sounds like the instrument.** Sixty-one recordings of real sleigh bells replace one placeholder, and an audience member hears the bells the orchestra actually plays rather than a stand-in.
- **Shaking harder does something musical.** The strength of a shake stops being a volume knob and starts choosing a different performance, which is what makes the moment feel like playing rather than triggering.
- **What you pick is what you hear.** The three choices on the selection screen become the two instruments that were recorded and the pair of them together, so the artwork is an honest picture of the sound rather than a set of three images loosely associated with three files.
- **No two shakes in a row sound identical.** Drawing at random from a bank, and never repeating the last recording, removes the machine-gun sameness that a single sample produces under fast shaking.
- **The professional recordings are in the product.** Julie's work has been in progress against a date; this is the feature that puts it in an audience member's hands.
- **The bells stay editable without a developer.** Which recordings a bell carries remains a list on a resource in the editor, and how the paired bells sit together is authored in a scene, so both are tuned by opening a file rather than by changing code.
- **Nothing that works is disturbed.** The detector, the flash response, the swipe that chooses a bell, and the loudness ramp are all left exactly as they are. The capture harness keeps every behaviour it has; the only thing that changes for it is which recording it clicks, because the one it used is a placeholder being retired with the rest.

## Terms

- **Stop.** One detected end of a shake stroke, the event the detector fires and the thing that sounds a bell. Defined in `shake/shake_detector.gd` and carried as a `ShakeEvent`.
- **Level.** The stop quantised to a whole number from 1 to 5, spaced perceptually rather than evenly in raw acceleration. Already computed by the detector and carried on every `ShakeEvent`.
- **Intensity.** The same stop placed on a continuous scale from 0 to 1. Also already carried on every `ShakeEvent`, and what the loudness ramp reads.
- **Piano bank.** The list of softly struck recordings a bell carries. Named for the musical dynamic and for the `Piano` in the delivered filenames.
- **Forte bank.** The list of hard struck recordings a bell carries, named on the same basis.
- **Undifferentiated bell.** A bell whose recordings are not split by dynamic, which holds all of them in its piano bank and leaves its forte bank empty. Type B is the only one delivered this way.
- **Paddle bells.** The instrument drawn by `app/sleighbells_01.tscn`: a light natural-wood blade with two rows of small bells and a turned handle. Type A.
- **Strap bells.** The instrument drawn by `app/sleighbells_03.tscn`: a red leather strap carrying two columns of large bells on a plain wooden dowel. Type B.
- **The pair.** The third choice on the selection screen: a new scene showing the paddle bells and the strap bells together, overlapping and slightly angled. Type C.
- **Voice.** One `AudioStreamPlayer` in the pool the jingle response holds, reused in round-robin order so that overlapping stops can sound at once.

## Requirements Summary

- **1. Give each bell two banks of recordings instead of one.** The single recording property on the instrument resource is replaced by a piano bank and a forte bank, each a list of any length.
- **2. Choose the bank by how hard the shake was.** Levels 1 and 2 draw from the piano bank, levels 3, 4, and 5 draw from the forte bank.
- **3. Let a bell with no dynamic layers sound one bank at every level.** An empty forte bank means every stop draws from the piano bank, whatever its level.
- **4. Never sound the same recording twice in a row.** Each draw is random within its bank, excluding whichever recording sounded last.
- **5. Keep the loudness ramp exactly as it is.** The existing scaling from quiet to loud across intensity continues to apply, on top of the recording chosen.
- **6. Size the voice pool from the longest recording a bell carries.** The existing sizing rule is preserved, measured against the longest recording rather than the only one.
- **7. Build the third choice as a scene showing both instruments together.** A new scene instancing the two bell scenes, overlapping and slightly angled, authored to occupy about the footprint of one bell.
- **8. Retire the green shaker from the selection screen.** Its image, scene, and instrument resource move to the legacy archive and the carousel no longer offers it.
- **9. Point the three choices at the delivered recordings.** Paddle bells to Type A, strap bells to Type B, the pair to Type C.
- **10. Retire the placeholder recordings to the legacy archive.** All five move under `legacy/`, and the one live reference to any of them is repointed at a delivered recording.
- **11. Say plainly when a bell cannot sound.** A bell with no usable recordings is inert and reports why, in the manner the file already establishes.

## Requirements

### 1. Give each bell two banks of recordings instead of one

`app/instrument_definition.gd` carries a single `sound` property of type `AudioStream`. Replace it with two exported lists, a piano bank and a forte bank, each holding any number of audio streams. The property being replaced is removed rather than kept alongside the banks: leaving it in place would create a second, silent way to configure a bell and a question at every reading of the file about which one wins.

Each bank is a list of any length so that the three delivered sets, which carry fourteen, twenty-five, and three or five recordings respectively, are all expressed the same way, and so that adding a recording to a bell is assigning a file rather than changing a structure.

### 2. Choose the bank by how hard the shake was

On each stop, read `ShakeEvent.level` and choose the bank from it. Levels 1 and 2 draw from the piano bank. Levels 3, 4, and 5 draw from the forte bank.

The boundary is expressed against `level` rather than against `intensity` because the level is what the detector already publishes as its quantisation of a stop, and because a boundary stated as "the bottom two levels of five" is a sentence a person can hold in their head while shaking a phone and checking whether it behaves. The boundary is a single value in one place, so moving it is changing one number.

### 3. Let a bell with no dynamic layers sound one bank at every level

Type B carries twenty-five recordings that are not split by dynamic. Such a bell holds all of its recordings in its piano bank and leaves its forte bank empty. An empty forte bank means every stop draws from the piano bank, whatever level it arrived at.

Expressing this as an empty bank, rather than by assigning the same twenty-five recordings to both banks, keeps the resource honest about what was delivered: the bell genuinely has no forte takes, and a reader of the resource sees that rather than seeing a duplicated list they must compare entry by entry to discover is identical. It also means that if dynamic layers are recorded for that instrument later, filling the forte bank is the whole of the change.

The bell still responds to how hard it is shaken, through the loudness ramp of requirement 5. What it does not do is change which recording it sounds.

### 4. Never sound the same recording twice in a row

Each draw is random within the chosen bank, excluding whichever recording sounded last on that bell. The exclusion applies across banks as well as within one, so a stop that crosses the boundary from piano to forte is not treated as a fresh start.

Pure random selection produces audible immediate repeats, and the smallest delivered bank has only three recordings in it, so on Type C a repeat would be heard within a few shakes rather than rarely. Excluding the last recording is the whole of the fix, and it is preferred to a shuffle bag: on a bank of three, a shuffle bag produces a rotating pattern that is its own kind of audible, whereas excluding the last leaves the order genuinely unpredictable.

A bank holding exactly one recording sounds that recording every time. There is no alternative to draw, and this case must not be allowed to search for one.

### 5. Keep the loudness ramp exactly as it is

`shake/responses/jingle_response.gd` scales each stop from a quietest level to a loudest level across `ShakeEvent.intensity`, with both ends exported and currently set to negative twenty-four and zero decibels. This is unchanged. It continues to apply on top of whichever recording requirement 2 chose, and both ends remain exported so they can be retuned by ear on a device.

The recordings now carry dynamics of their own, so the ramp and the bank choice both act on the same stop. That is intended: the bank choice gives the change of character between a soft strike and a hard one, and the ramp gives the continuous response within each band, so that a shake at the bottom of the piano range is still softer than one at the top of it.

### 6. Size the voice pool from the longest recording a bell carries

The jingle response sizes its pool of voices from the length of the recording it holds, against a highest sustained event rate of eight stops per second, with a floor of four voices. That rule is preserved, measured against the longest recording across both of the bell's banks rather than against the only recording it had.

The longest is the correct measure because the pool exists to stop a recording being cut short by reuse of its voice, and the recording most at risk of that is the longest one. Sizing from an average or from the first entry would leave the longest recordings clipped under sustained shaking, which is exactly the case the pool was built for.

Because a voice can now play any recording in either bank, each voice is assigned its recording at the moment it is played rather than when the pool is built. The round-robin reuse of voices, and the trade it carries — that a burst faster than the pool holds reuses its oldest voice and cuts a recording short — are unchanged.

### 7. Build the third choice as a scene showing both instruments together

Type C is a recording of both instruments being shaken at once, so the third choice on the selection screen shows both. Add a new scene that draws the paddle bells and the strap bells together: overlapping slightly, one in front of the other, and each turned a little off vertical, so the pair reads as two instruments being shaken rather than as two pictures set side by side.

The new scene instances the two existing bell scenes rather than referring to their images directly. This is what keeps the pair honest as the artwork changes: if either instrument is later re-cut, repositioned within its own scene, or replaced, the pair picks that up without being edited. Referring to the two images directly would create a second definition of what each instrument looks like, and the two would drift.

Every part of the arrangement — the offset between the two, which one is in front, and how far each is turned — is authored in that scene and adjustable in the editor. Nothing about the arrangement is computed at run time. This is the property the whole instrument system already has, and the reason the third choice is a scene rather than a special case in the carousel.

The pair is authored to occupy about the footprint of a single bell, achieved through how far the two overlap and, if needed, a modest scale on the pair as a whole. The carousel scales and places a slot rather than correcting the artwork inside it, and the play screen draws the chosen artwork at twice size through `InstrumentHolder`; a pair authored to a single bell's footprint therefore drops into both screens with no change to either. Neither screen is given a special case for this choice.

### 8. Retire the green shaker from the selection screen

The green stick shaker is not one of the recorded instruments and no longer appears anywhere in the application. Its image, its scene, and its instrument resource all move under `legacy/`, mirroring their original paths, and the carousel's list of instruments no longer includes it. None is deleted.

The carousel offers three choices as it does today: the paddle bells, the strap bells, and the pair, in that order, so that the two single instruments come before the one that combines them.

The `legacy/` directory carries a `.gdignore`, so the engine does not scan it and the retired files are not imported. One consequence is worth recording rather than discovering: the abandoned version 1 carousel already in `legacy/` refers to the shaker's image at its current path, and that reference will no longer resolve once the image moves. Both files sit inside the ignored directory and neither is loaded by anything, so this is a dead reference inside dead artwork and is left as it is.

### 9. Point the three choices at the delivered recordings

Assign the delivered recordings to the three instrument resources in `app/instruments/` as follows.

- Type A to the paddle bells, `sleighbells_01.tres`: fourteen piano recordings to the piano bank, fourteen forte recordings to the forte bank.
- Type B to the strap bells, `sleighbells_03.tres`: all twenty-five recordings to the piano bank, forte bank left empty, as requirement 3 describes.
- Type C to the pair, the new resource added by requirement 7: three piano recordings to the piano bank, five forte recordings to the forte bank.

The two surviving instrument resources keep the names they have. The pair takes a new name that says what it is rather than reusing the number freed by the retired shaker, because a resource numbered between the two single instruments would read as a third single instrument.

### 10. Retire the placeholder recordings to the legacy archive

The five placeholder recordings in `sounds/` — the bright, airy, deep, and light jingle bells and the single jingle — are all superseded by this feature and move under `legacy/`, mirroring their original path. None is deleted, and none is left behind: nothing in the application should still be sounding a placeholder once the delivered recordings are in.

Four of them are referenced only by the instrument resources, which requirement 9 re-points, so they become unreferenced as that requirement is carried out. The fifth, the single jingle, is different and must not be overlooked: it is the exported default recording baked into `shake/responses/jingle_response.tscn` itself, which is the scene the capture harness at `capture/shake_capture.tscn` instances. That reference is repointed at one of the delivered recordings, so the harness keeps sounding.

It is repointed at a recording in `sounds/v2/`, never at the retired file's new path. The `legacy/` directory carries a `.gdignore` and the engine does not import it, so a reference into it resolves to nothing and would leave the harness silent. The harness is a measurement rig and wants one short dry click per detected stop, so that stops are countable by ear while a run is being recorded; the shortest of the delivered recordings is what it takes.

The capture harness is otherwise untouched. Its readout, its flash response, and the detector it instances are all unchanged.

### 11. Say plainly when a bell cannot sound

The jingle response already reports, and goes inert rather than substituting a sound, when it has no recording to play. That discipline is preserved against the new structure: a bell whose piano bank is empty cannot sound at any level, since requirement 3 makes the piano bank the one every stop can reach, and such a bell reports that and connects to nothing.

Each message names the resource to fix and what to do to it, in the manner the file already establishes, so that a mis-assigned bank is fixed rather than diagnosed. A silent bell remains a fault to be corrected, not a case to be handled.

## Token and design considerations

This feature builds no skill. It changes one resource script, one response script, and a small number of scenes and resource files in a Godot application, so there is no prompt to size, nothing loaded into a model's context, and no per-run cost to account for.

## Teaching topic

**Topic:** why the strength of a shake should choose a recording rather than only a volume. **Competency:** a developer who can explain that a struck instrument changes timbre with force, not just amplitude, and that this is why the detector has published a level since the Shake It Discovery feature (C1_09) alongside a continuous intensity, will reach for the right one of the two when adding any future response — a recording bank from the level, a continuous parameter from the intensity — instead of scaling one asset and calling it dynamics.

## Future work

**The size the recordings add to the application bundle.** The delivered recordings are twenty-five megabytes of uncompressed audio in the repository, but that is not what ships. Every one of them imports with Quite OK Audio compression already applied, and the sixty-one recordings resolve to about five megabytes of imported samples, which is what an export bundle carries. That was measured after this specification was first written and it is a fifth of what the paragraph here originally assumed. The recordings go in as delivered and no import setting is changed. A future feature that wants the number lower still would be trading audible quality on a phone speaker against a handful of megabytes, which is a smaller question than it looked.

**Dynamic layers for the strap bells.** That instrument was delivered without a piano and forte split, so requirement 3 sounds one bank at every level for it. If those takes are recorded later, filling its forte bank is the whole of the change, and it needs no further feature.

**Animating the pair.** Requirement 7 draws the two instruments in a fixed arrangement that reads as both being shaken. Actually moving them, together or against each other, in response to a stop is a different kind of work: it is the instrument animation the flash response was written as a placeholder for, and it would apply to the single instruments as much as to the pair. It belongs in a feature about how a bell responds on screen, not in this one.
