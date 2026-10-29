# FTUE checklist

Run this on a fresh account (Studio: a new test profile, or clear the tutorial slice) before you score with `../../quality-score/rubrics/tutorial.md`. Time each line with a stopwatch; write the number next to it. Targets are Rule of thumb unless your own funnel says otherwise.

## Before the first input
- [ ] Join to control in about 10 s or less; a custom loading screen leaves on ready or a hard timeout.
- [ ] The player spawns facing the first target; the walk to it is under about 10 seconds.
- [ ] No cutscene, or one that is skippable and under about 5 s.
- [ ] No pop-ups (daily reward, favourite, group, events, purchases) until the tutorial is finished.

## First 60 seconds
- [ ] First objective visible within a second or two of control; 8 words or fewer; names the control for this device.
- [ ] First meaningful action under 20 s from control.
- [ ] First reward under 60 s, with sound, a number pop and a short celebration.
- [ ] One goal and one pointer on screen; the pointer lands exactly on the target.
- [ ] Nothing covers the middle of the screen; the player can always move.

## First five minutes
- [ ] The whole core loop completed at least once (ideally three or more times).
- [ ] The player has seen a number go up, made one choice, and spent something that changed their verb.
- [ ] Any purchase the tutorial asks for is guaranteed affordable.
- [ ] HUD items appear as their step begins; locked features show a lock and a price.
- [ ] The end hands over a next goal (quest, gate, goal chain); the moment of completion feels like a celebration.

## Respect
- [ ] Skip offered immediately to returning accounts, after the first step to new ones, with a short confirm.
- [ ] Skip grants what the steps would have paid; replaying from Settings pays nothing twice.
- [ ] Rejoin mid-tutorial resumes the same step; finished steps never reappear.
- [ ] Dying mid-step respawns quickly and the step still works.
- [ ] Friends can join and play together at any time; a social step, if any, is optional.
- [ ] Guidance fades once the player shows they know the action.

## Devices and accessibility
- [ ] Phone (about 375 px wide): text readable, nothing under the notch or core buttons, targets about 44 px or more.
- [ ] Gamepad: glyphs match the real bindings; the HUD target can be reached with selection.
- [ ] Switching device mid-step updates the prompt text.
- [ ] Every cue uses colour plus shape or words; Reduced Motion turns off pulses and moving textures.
- [ ] Any voiced line has captions.

## Data
- [ ] Funnel steps logged on the server: Joined, each step, Finished. Step numbers stable; versioned name when reordered.
- [ ] Skip and hint shown logged as custom events with the step id in a field.
- [ ] A dated note of what changed in this version, so funnel cohorts can be compared.
