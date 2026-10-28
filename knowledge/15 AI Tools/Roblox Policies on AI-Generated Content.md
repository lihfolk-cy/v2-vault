---
tags: [ai, policy, compliance, licensing, moderation, ratings]
---
# Roblox Policies on AI-Generated Content

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Assuming that because an AI made it, nobody owns it and anyone may use it.
> - Avoid: Free-plan output in a monetised game.
> - Avoid: AI thumbnails showing scenes the game does not contain.
> - AI-made art, audio or code in the game
> - AI-assisted thumbnails and trailers
> - NPC chat via `TextGenerator`
>
> Read more (13 KB note): ## 2. AI-made assets you upload · ## 3. AI features at runtime · ## 6. A compliance checklist by feature · ## Common mistakes
<!-- tldr:end -->

This note collects the rules that apply when AI is involved in a Roblox experience: assets made with AI before upload, AI features players interact with at runtime, and the licences of the AI tools themselves. The short version: Roblox treats AI-made content like any other content (you need the rights, it must follow the Community Standards, it must not mislead), and adds specific duties for experiences where players trigger AI responses (disclosure, notices, ratings, filtering).

Everything here was checked against Roblox's Creator Hub ("Games with Generative AI", the AI overview, audio assets, thumbnails, secrets) and DevForum announcements in October 2026. Policies change; Roblox revised its Terms of Use in 2026. This note is a working summary, not legal advice. For the full compliance picture see [[Roblox Policies Ratings and Compliance]] and [[Age Checks and Safety Features]].

---

## 1. Two different questions

| Question | Applies to | Main rules |
|---|---|---|
| "I made this asset with AI. Can I upload and use it?" | Meshes, images, audio, code, text made with any AI tool before upload | Rights to the content (tool licence), Community Standards, moderation, IP, no misleading marketing |
| "My experience uses AI while people play." | `TextGenerator`, `GenerationService`, TTS, speech-to-text, third-party models via `HttpService` | Disclosure in the maturity questionnaire, AI notices, filtering, rating rules for extended interactions, responsibility for third-party output |

---

## 2. AI-made assets you upload

### The rules are the same as for any asset

- **Moderation.** All uploads (images, meshes, audio, video) are moderated and must follow the Community Standards and Terms of Use. AI origin neither helps nor hurts.
- **Rights.** You must have the rights to what you upload. Roblox's audio documentation says it directly: the uploader must have the legal rights to the audio. If an AI tool's terms do not grant you commercial use on the plan you used, you do not have the rights you need for a monetised experience.
- **Intellectual property.** A generated image of a trademarked character, a generated song imitating an artist's recording, or a generated model of a branded car is still an IP problem. "The AI made it" is not a defence.
- **Impersonation.** Cloned voices or generated likenesses of real people need their consent and are subject to Roblox's rules on impersonation.

### Is there a labelling requirement for AI-made assets?

As of October 2026, no Roblox requirement to label assets as AI-generated when uploading them was found in the Creator Hub pages checked. This may change; re-check the Terms of Use and Creator Store rules before you rely on it. A third-party tracker reported that Roblox's Terms of Use update effective 30 April 2026 consolidated AI-related terms into the main user and creator terms, mostly reorganising rather than adding restrictions; this could not be confirmed against Roblox's own text.

### Marketing images and video

Roblox's thumbnail documentation requires video thumbnails to be authentic and to accurately show in-experience content, and names "artificial visuals" (graphics enhanced beyond what players will see) and misrepresented gameplay as violations. Rejected videos still count against the monthly quota of 3 video uploads. AI-generated thumbnails, icons and trailers are the easiest way to break this by accident: a generated scene almost always contains things the game does not have. See [[AI Image Generation for Icons Thumbnails and Concepts]] and [[Thumbnails Icons and Store Page]].

### Assets you distribute

Putting an AI-made mesh, image or sound on the Creator Store, or selling an AI-made UGC item, means you distribute it to others. Check that your tool's licence allows redistribution (some free plans require attribution, which is awkward on a store listing; some forbid resale). UGC avatar items also have their own technical and policy requirements ([[UGC Avatar Items and Accessories]]).

### Code

AI-written code has no special Roblox rule. The practical risks are security (exploitable remotes), licence contamination if a tool reproduces licensed code verbatim (rare, but check large blocks that look copied), and quality. See [[AI Code Assistants for Luau]].

---

## 3. AI features at runtime

From Roblox's "Games with Generative AI" page (October 2026):

### Moderation and responsibility

- All content, including AI-generated content, must follow the Community Standards.
- **Roblox's own APIs** (`GenerationService`, `TextGenerator`): inputs and outputs are moderated (text filtering, image review, asset review). Violating content is not shown, and players are not penalised for violating outputs produced from non-violating inputs.
- **Third-party AI tools**: you are responsible for all delivered content, even if it is AI-generated. Outputs must meet the Community Standards, and inputs and outputs may not bypass Roblox's safety measures; text must go through Roblox's text systems. Roblox's AI overview states that all generated text must go through `TextService:FilterStringAsync()`.

### Content maturity

- **Disclosure:** if players can trigger AI responses through text chat, voice chat, images, 3D generations or avatar movement, you must disclose it in the Content Maturity questionnaire.
- **An AI component does not by itself change your rating.**
- **Limited interactions:** model outputs must match the experience's maturity classification. Roblox-served models target All Ages and avoid content needing a descriptor (such as horror); experiences rated Mild Violence or higher may generate otherwise compliant weapons. With third-party tools, matching the rating is your job.
- **Extended interactions** must carry the **Restricted** label, which blocks users under 18. An experience is extended if:
  - its main purpose is continuous conversation with a generative AI bot or character with no time limit, or
  - the AI keeps **cross-session memory** (saves conversation context and reloads it in later sessions).

The September 2025 DevForum announcement added that brief NPC conversations during regular gameplay are not extended, and that creators with extended-interaction experiences had to retake the questionnaire by a deadline or face moderation and reduced visibility.

### Required notices

- Players must see that they are talking to AI at the start of any interaction and throughout the session. Roblox's example text: "This is an AI-powered conversation, not human. It may make mistakes."
- For professional or medical advice, direct players to authoritative resources.
- In self-harm or mental health situations, the AI must encourage players to seek support and point them to the resources listed in the Community Standards.

### Further guidance from the text generation beta announcement

- Limit each output to the interacting user rather than broadcasting it.
- Avoid designs that encourage spending Robux or money.
- Keep the model on specific topics.
- Give players instructions for safe use (do not share personal information).
- Collect only necessary data and follow the privacy policy ([[Player Privacy and Data Deletion]]).

### Speech APIs

- Text-to-speech: all text is filtered and generated audio is moderated. For real-time `AudioTextToSpeech`, creators are not held responsible for rare violating outputs unless deliberately programmed; for `GenerateSpeechAsset`, moderation applies to the account that owns the saved asset, and Roblox advises against letting players enter text for asset generation (June 2025 beta announcement).
- Speech-to-text uses the microphone; enabling it also enables voice chat by default unless you disconnect the default routing. Voice input that triggers AI responses is covered by the disclosure rule above.

---

## 4. Licences of the AI tools themselves

Roblox's rule "you must have the rights" pushes the real question to each vendor's terms. Common patterns seen in October 2026 (summaries from vendor pages and third-party sources; verify the current terms):

| Pattern | Examples reported | Consequence |
|---|---|---|
| Free plan: commercial use with attribution (open licence) | Meshy's Free plan listed under CC BY 4.0 | You may ship, but must credit as the licence requires |
| Free plan: non-commercial only | Reported for ElevenLabs, Suno and Tripo free plans | Do not use free-plan output in a monetised game |
| Rights tied to the plan at generation time | Suno: no retroactive licence for free-plan songs | Upgrading later does not fix old output |
| Paid plans: commercial use | Most vendors | Keep proof of your plan at the time |
| Open-weight models | Each model has its own licence | Read the model licence and any fine-tune's licence |

Keep a provenance record for every AI-made asset: tool, model version, plan, date, prompt, and a saved copy of the terms you relied on. When a question comes up a year later, this record is the difference between a quick answer and replacing the asset.

---

## 5. Using Roblox's own creator AI tools

Assistant, mesh generation, procedural models, Material Generator and Texture Generator are Roblox features operating under Roblox's terms. A few practical points:

- Generated meshes, materials and textures become assets or instances in your place and are subject to the same moderation as anything else. Prompts can fail moderation (the reference project saw anatomy words such as "skeleton" and "ribcage" rejected for a stylised dungeon).
- Assistant can insert Creator Store assets. Third-party assets bring their own licences and their own scripts; inspect them ([[Creator Store and Toolbox Safety]]).
- If you connect your own API keys (Anthropic, OpenAI or Google) to Assistant, or connect external AI clients through the Studio MCP server, your provider's terms also apply to that usage. Roblox's MCP page warns: "MCP clients can read and modify content in your open Roblox places. Make sure to only connect clients you trust."

---

## 6. A compliance checklist by feature

| Feature | Required | Recommended |
|---|---|---|
| AI-made art, audio or code in the game | Rights under the tool's licence; Community Standards; IP clearance | Provenance record; attribution where required |
| AI-assisted thumbnails and trailers | Authentic, no artificial visuals, no misrepresented gameplay | Compare with real captures |
| NPC chat via `TextGenerator` | Questionnaire disclosure; AI notice; filter output; Restricted if extended | Turn caps, topic focus, reply to one player |
| NPC chat via a third-party LLM | All of the above; full responsibility for outputs; outputs matched to rating | Server budget guard, red-team testing, reporting |
| Player-generated 3D objects | Questionnaire disclosure | Per-player limits, removal tools, fallbacks |
| TTS of player text | Moderation applies; prefer real-time TTS over saved assets for player text | Subtitles |
| Speech-to-text | Questionnaire disclosure if it triggers AI; voice chat settings understood | Filter recognised text |
| AI companion with memory | Restricted label (cross-session memory = extended) | Consider whether the feature is worth an 18+ audience |

---

## 7. Nuance: where the obvious answer is wrong

- **"Roblox moderates it, so I am covered."** Only for Roblox's own APIs. Output from a third-party model is your responsibility, even after it passes the text filter: a filter checks words, not whether a cheerful answer is harmful.
- **"A small AI feature does not change anything."** It changes the questionnaire answer. The rating may stay the same, but the disclosure is required.
- **"No memory means no extended interaction."** Memory is one trigger; the other is an experience whose main purpose is unlimited conversation, even without saved context.
- **"Paying now fixes old output."** For tools whose rights depend on the plan at generation time, it does not.
- **"An AI thumbnail is just marketing."** Misleading thumbnails are a policy violation regardless of who made them.

---

## Common mistakes

- Assuming that because an AI made it, nobody owns it and anyone may use it.
- Free-plan output in a monetised game.
- AI thumbnails showing scenes the game does not contain.
- Forgetting the questionnaire when adding a small AI feature.
- "The NPC remembers you" without realising it makes the experience extended.
- Treating Roblox's moderation as covering third-party model output.

## Checklist

- [ ] Every AI-made asset has a provenance record and a licence that covers your use.
- [ ] Marketing images and video show the real game.
- [ ] Runtime AI disclosed in the questionnaire; notices in place.
- [ ] All generated text filtered; third-party output matched to your rating.
- [ ] Extended interaction or cross-session memory means Restricted.
- [ ] Policies re-checked before each major release (date noted).

## See also
[[Roblox Policies Ratings and Compliance]] · [[Age Checks and Safety Features]] · [[In-Game AI - LLM NPCs and Text Generation]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[AI Audio - Voice Music and SFX]] · [[AI 3D Model Generation Outside Roblox]] · [[Thumbnails Icons and Store Page]] · [[Ethical Design and Player Trust]]

## Connected notes
<!-- auto-links:start -->
[[AI in Roblox Development Overview]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]] · [[Legal Basics - IP Licenses and Assets]] · [[Community and Moderation Start Here]] · [[Publishing an Experience]] · [[Links - Moderation compliance]]
<!-- auto-links:end -->
