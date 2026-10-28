---
tags: [authoring, mocap, animation-capture, video, face]
---
# Animation Capture and Mocap

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Shipping capture output unedited: floaty, slow anticipation, mushy contacts.
> - Avoid: Smoothing through the hit frame.
> - Avoid: Leaving tiny translations on every limb after retargeting.
> - Source shot meets the capture requirements (one person, one shot, under 15 s, stable camera)
> - Skeleton errors and flips fixed
> - Jitter filtered, contacts protected
>
> Read more (13 KB note): ## 1. Studio's Animation Capture · ## 2. External mocap · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Motion capture records real movement and turns it into keys. On Roblox you have Studio's built-in **Animation Capture** (body from video, face from webcam), external mocap (video AI services, inertial suits, optical studios) brought in through Blender, and the humble option that every good game animator uses daily: **video reference** that you count frame by frame and key by hand.

This note covers what each gives you, the clean-up that raw capture always needs, and why captured motion usually has to be made *less* realistic before it feels good in a game.

Labels: "Roblox docs" = the official Animation capture page (October 2026). "Measured" = the reference project. Rules of thumb are labelled.

## 1. Studio's Animation Capture

### Body: video to R15 keys (Roblox docs)
- Enable **File > Beta Features > Live Animation Creator**.
- Open the Animation Editor (the Avatar tab's **Clip Editor** button), select an **R15 rig**, create an animation.
- **⋯ > Import > Live Animation Creator > Choose Video**, pick the file. Keys appear on the timeline after about a minute.
- Requirements: `.mp4` or `.mov`; **one person**, well lit and visible the whole time; **one continuous shot**; **under 15 seconds**; a **stable camera**; content must follow Roblox's Community Rules and Terms of Use.
- Output is ordinary keyframes you can edit, save and publish.

### Face: webcam to dynamic-head keys (Roblox docs)
- Enable **File > Beta Features > Face Capture**.
- Select a rig with an **animation-compatible (dynamic) head**, create an animation, press **Face Capture** in the track list, accept the consent prompt (collection of facial movement and camera access), choose a camera if you have several, record with the red circle, stop with the red square or the countdown.
- Recordings up to **60 seconds**. **Re-Record** discards and retries.
- Light the room well and sit so your face is centred and close; the docs note this helps the tracker separate you from the background.
- Facial keys drive the head's FACS controls; see [[Facial Animation and Dynamic Heads]].

### Getting good results from video capture
Rules of thumb (consistent with the requirements above and with how pose-estimation trackers fail):
- **Full body in frame the whole time**, including feet. Trackers guess missing limbs, and guessed limbs jitter.
- **Side-on or three-quarter view** for actions in the sagittal plane (punches, kicks, swings toward camera are the hardest to read in depth). Shoot the move from the angle that shows the limbs separated from the torso.
- **Fitted, contrasting clothes**, plain background, even light, no other people or mirrors.
- **Tripod.** Camera motion becomes body motion.
- **Higher frame rate helps fast moves.** A 30 fps video of a fast swing has motion blur and only a few frames of contact; 60 fps gives the tracker sharper frames (rule of thumb; the docs do not state a frame-rate requirement).
- **Act it bigger and cleaner than real life.** Pause briefly in key poses; make the anticipation obvious. You will be exaggerating it afterwards anyway.
- **Under 15 s means one action.** Capture a move, not a sequence; join moves in the editor.

### What it is good and bad at
| Good | Weak |
|---|---|
| idles, gestures, emotes, social and conversational motion | fast combat (blur, occlusion, depth ambiguity) |
| natural weight shifts and timing reference | hands and fingers (R15 hands are one part anyway) |
| quick NPC variety | interaction with props: the weapon is not captured |
| blocking a long motion to then re-key | anything needing exact foot plants or exact hit frames |

Treat capture output as **dense reference keys**, not a finished clip.

## 2. External mocap

### Sources
- **AI video mocap services** (upload video, download FBX/BVH). Similar strengths and weaknesses to Studio's body capture, usually with longer clips and more skeleton options.
- **Inertial suits** (IMU sensors). Good for long takes and large spaces; drift in global position over time, foot contacts need clean-up.
- **Optical studios**. Highest quality; expensive; still need clean-up and retargeting.
- **Marketplace mocap libraries**. Check the licence allows use in a game you monetise.

### Getting it onto a Roblox rig
The usual route is: mocap skeleton (FBX/BVH) > Blender > retarget onto an armature with your rig's joint names and rest pose > export > import into Studio, or use a Blender to Studio bridge. Retargeting itself is covered in [[Retargeting Animations Between Rigs]] and [[Animation Data from Blender to Roblox]]. Roblox-specific points:

- **R15 has no clavicles, no separate forearm twist, one-piece hands and feet.** Shoulder shrugs in the capture must be folded into the upper-arm rotation, and wrist twist all lands on the hand joint. Expect odd shoulders until you correct them.
- **Rotation only on limbs.** Mocap retargets often leave small translations on every joint. On R15 arms, translation over about 0.05 studs reads as a detached shoulder (reference project QA). Zero limb translations; keep translation on the root's first child.
- **Root motion.** Roblox ignores the top-level root pose in a clip (measured). Put the hips' travel on LowerTorso (or your first child joint), or strip horizontal travel completely and let gameplay move the character (the usual choice for player characters, since the Humanoid owns the root).
- **Scale.** Translation keys are studs. A 1.8 m actor retargeted to a 9-stud character (the reference project's 1.6x R15 avatar) needs the root translation scaled to the character's leg length, or feet slide and float. The reference project also measured that clip root offsets are applied literally on characters scaled through body-scale values, but multiplied by `Model:GetScale()` on model-scaled rigs. See [[Scale and Animation]].
- **Frame rate.** Mocap is often 60 to 120 fps. Roblox stores times in seconds, so keep the timing, but **reduce the keys**: every Pose is an instance.

## 3. Cleaning up captured motion

Raw capture always needs these passes, roughly in this order.

### 3a. Fix the skeleton first
- Bad frames: swapped left and right legs, a limb pointing backwards for one frame. Delete those keys and let interpolation bridge, or re-key by hand.
- Flips: the tracker suddenly picks the other solution for an elbow or knee. Look for one-frame jumps of 30 degrees or more (the reference project's pop definition at 60 Hz).

### 3b. Filter jitter
High-frequency noise reads as shivering. Smooth each rotation channel over time:
- A **Gaussian** window of about 1 to 2 frames (at 60 Hz) on fast parts and 3 to 4 frames on slow parts is a good start (the reference project's arm solver smooths joint rotations with sigma 0.8 frames where the blade matters and 3.5 elsewhere).
- **Never smooth across contacts and hits.** Smoothing rounds off the impact, which is the frame that matters most. Keep a window of untouched frames around each contact (the reference project protects 90 ms around markers).
- Smooth **rotations as rotations** (quaternions or rotation vectors with consistent hemisphere), not Euler channels independently, or you create wobbles at wrap-around points.

### 3c. Fix contacts
- **Foot plants**: find frames where the foot should be still (low velocity, near the ground) and lock it there with IK, then re-key the leg. Foot slide is the most visible mocap artefact on a third-person camera.
- **Ground height**: after scaling, check that the lowest foot touches the floor in idles and lands at floor height. The reference project ground-fitted 205 of 304 enemy clips and moved the worst penetration from -7.79 studs to -0.17 (see [[Ground Fitting Pipeline]]).

### 3d. Reduce keys
Keep a key only where interpolating its neighbours would miss it by more than a tolerance. Tolerances the reference project used for bodies: **0.75 degrees and 0.03 studs** (hips 0.5 degrees), checked at 60 Hz, with planted feet held to 0.05 studs. The editor's **Optimize Keyframes** slider does a simpler version (see [[Animation Editor Advanced]]). After thinning, check that no key-to-key segment turns more than 120 degrees.

### 3e. Make it a game animation
This is the step people skip. See the next section.

## 4. Why realistic is not enough

Captured motion is *correct*, and that is the problem. Game animation must be readable at a distance, responsive to input and clear about timing. Real movement is none of those by default.

| Real motion | What the game needs | Typical edit |
|---|---|---|
| Anticipation is small and slow | anticipation that reads but does not delay input | shorten it to 2 to 6 frames for light player attacks; enlarge the pose so it still reads (rule of thumb; the reference project's standard uses these numbers) |
| Contact is a blur | one clear contact pose held briefly | add a 2 to 4 frame moving hold at contact (reference standard) and line it up with the `Hit` marker |
| Recovery is long and natural | recovery that lets the player act | cut it; add a cancel window marker; let the idle blend take over |
| Arms stay close to the body | arms that read in silhouette | open the arms away from the torso, especially the off hand |
| Subtle weight shifts | weight that reads from 15 studs | exaggerate hips and spine by 20 to 50% (rule of thumb) |
| Real actor proportions | blocky R15 proportions with short legs | adjust stride and crouch depth; R15 legs are short (the reference project measured hip height about 3.5 studs on its 1.6x character) |

Enemies and bosses need the opposite tweak for telegraphs: **lengthen and enlarge** the wind-up so other players can react. The reference project kept boss warnings at 0.5 s or more and locked attack markers at least 0.45 s before the blow. See [[Animating Creatures and Monsters]].

## 5. Video reference without capture

The most common professional use of video is not tracking but **counting**:
1. Film yourself (or find footage) doing the move, at 60 fps if possible.
2. Step through frame by frame. Note the frame of each key pose: start of anticipation, deepest anticipation, contact, furthest follow-through, settled.
3. Convert to 30 fps frames and seconds (see [[Timing Spacing and Frame Charts]]).
4. Block those poses by hand on the game rig, then exaggerate.

This gives you real timing and weight while keeping full control of pose, silhouette and contact frames, and it avoids every clean-up problem above.

## 6. Data budget

Captured motion is dense by nature. On Roblox:
- Every Pose is an instance; the reference project budgeted **2,500 instances per ability kit folder** and measured that enemy clips baked at 16 to 25 keys per second added up to **323k instances** in one folder.
- Typical thinned gameplay clips there ran **22 to 30 keys per second** for normal moves and about **16** for long ultimates.
- Large unthinned libraries hurt every client's load time if they live in ReplicatedStorage. Publish and archive the sources, or ship compressed buffers (see [[Baked Clip Stubs and Archiving]] and [[Clip Buffer Format]]).

## 7. Consent, likeness and rules

- Face Capture explicitly asks for consent to collect facial movement. Do not record other people without their permission.
- Uploaded videos must follow Roblox's Community Rules and Terms of Use (Roblox docs).
- Check licences on purchased mocap; some forbid redistribution in user-generated content.

## Common mistakes

- Shipping capture output unedited: floaty, slow anticipation, mushy contacts.
- Smoothing through the hit frame.
- Leaving tiny translations on every limb after retargeting.
- Putting root motion on the top-level root (it is never applied).
- Forgetting to scale root translation to the character's size.
- Keeping every frame of a 60 fps capture as keys.

## Checklist

- [ ] Source shot meets the capture requirements (one person, one shot, under 15 s, stable camera)
- [ ] Skeleton errors and flips fixed
- [ ] Jitter filtered, contacts protected
- [ ] Feet planted, ground height checked on the game character
- [ ] Limb translations removed; root motion on the first child joint or stripped
- [ ] Keys thinned with a tolerance; no segment over 120 degrees
- [ ] Anticipation, contact and recovery retimed for gameplay
- [ ] Markers added for gameplay events
- [ ] Reviewed with [[Animation Review Checklist]]

## See also
[[Animation Editor Advanced]], [[Facial Animation and Dynamic Heads]], [[Retargeting Animations Between Rigs]], [[Principles of Animation for Games]], [[Timing Spacing and Frame Charts]], [[Combat Animation Craft]], [[Performance and Memory]].

## Connected notes
<!-- auto-links:start -->
[[AI Animation and Motion from Video]] · [[Animation Editor Workflow]] · [[Moon Animator and Third-Party Tools]] · [[Modeling Characters for R15 and Custom Rigs]] · [[Voxel Characters - Proportions Joints and Rigging]] · [[Links - Animation creation]] · [[Animation Start Here]]
<!-- auto-links:end -->
