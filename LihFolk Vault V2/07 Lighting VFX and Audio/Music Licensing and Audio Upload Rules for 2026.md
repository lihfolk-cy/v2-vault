---
tags: [audio, music, licensing, copyright, upload-rules, policy, compliance, type/guide, area/audio, level/intermediate, 2026, area/vfx]
---
# Music Licensing and Audio Upload Rules for 2026

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Uploading commercial songs -> Only owned, commissioned or library audio
> - Avoid: Third-party ids from old scripts -> Re-upload with rights, or replace
> - Avoid: Personal uploads in a group game -> Upload to the group or grant permission
> - Every audio asset has source, licence and uploader in the manifest.
> - Music uploaded by the group that owns the game, or granted explicitly.
> - Periodic load check for music ids, with fallbacks per context.
>
> Cost: TL;DR ~160 tok · whole note ~2.3k tok. Read more: ## 1. The five sources, ranked by risk · ## 2. Upload rules (current docs) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Audio is the asset type most likely to get a Roblox account actioned and a game silently broken. A song that played fine at launch can be taken down after a rights claim; a boombox gamepass can turn your servers into a distribution point for copyrighted music; a commissioned track can come back to bite your YouTube trailer. This note is the rights side of audio: where usable music comes from, what you may upload, what happens after upload, and the operational habits that keep a live game from going quiet. Upload mechanics, loudness and id maps are in [[Audio Pipeline]]; AI-generated audio terms in [[AI Audio - Voice Music and SFX]].

Source labels: **Roblox docs**, **Rule of thumb**, **Unverified**. This is not legal advice; for anything commercial beyond Roblox, read the actual licence or ask a lawyer.

---

## 1. The five sources, ranked by risk

| Source | Risk | Notes |
|---|---|---|
| **Roblox-provided licensed library** (Creator Store audio published by Roblox and its partner libraries) | Lowest inside Roblox | Free to use in experiences (**Roblox docs**: https://create.roblox.com/docs/audio/assets). Licence scope covers use in Roblox; see section 4 for uses outside Roblox |
| **Music you made yourself** | Low | Keep project files and dated exports as proof of authorship |
| **Commissioned music** | Low if contracted | Needs a written grant covering Roblox use, trailers and streams; see section 5 |
| **Royalty-free or stock library you licensed** | Medium | Licences vary: some forbid redistribution in "interactive" products or re-hosting in a platform's library. Read the licence for "games" and "user-generated platform" language |
| **Commercial songs you do not own** | High | Do not upload. Moderation and copyright systems catch many; rights holders file claims for the rest. Uploading is the account risk, not just the game risk |

AI-generated music sits between rows 3 and 4: the platform rules are the same as for any audio, and the generator's terms at generation time decide your rights ([[AI Audio - Voice Music and SFX]]).

## 2. Upload rules (current docs)

From the Roblox audio assets documentation (https://create.roblox.com/docs/audio/assets), as summarised in V2 in October 2026: monthly import caps that are higher for ID-verified accounts, a maximum duration of 7 minutes and size of 20 MB per file, `.mp3`/`.ogg`/`.wav`/`.flac`, private by default with per-experience permission grants, and the uploader must hold the rights. Exact caps are in [[AI Audio - Voice Music and SFX]] section 3; re-check the page before planning a large batch, because caps have changed more than once.

What changed historically and still matters:
- **Audio privacy (2022).** Roblox made most existing user audio private and moved to private-by-default uploads, granting use per experience (**Roblox docs**, audio assets page; the original announcement was on the DevForum in March 2022). Practical effect: an id from someone else's upload will often not play in your game. If an old script references a third-party id, assume it is silent.
- **Group-owned games.** Upload audio to the group that owns the experience, or grant the experience permission explicitly. Personal uploads used in a group game are a classic "works in Studio, silent live" bug ([[Sound Fundamentals]]).
- **Moderation and classification.** Uploads are reviewed and categorised (sound effect versus music); music may be held to stricter checks.

## 3. After upload: takedowns and silent failure

- A rights claim or moderation action can remove an asset at any time. The game does not error; the sound just stops (`IsLoaded` never becomes true, or loading fails).
- **Operational habit (Rule of thumb):** keep an id manifest with source, licence, uploader and date per asset ([[Audio Pipeline]] stage 3), and run a periodic in-game check that loads every music id and logs failures to your analytics or error tracker. Fallback tracks per context mean a removed song becomes a different song, not silence.
- Repeated copyright strikes affect the uploading account. Keep music uploads on an account or group you are prepared to defend, and never let collaborators upload unverified tracks to the main group.

## 4. Licensed library tracks outside Roblox

The Roblox library licence is aimed at use **in Roblox experiences**. Whether it covers a trailer on YouTube, a TikTok ad or a streamer's VOD of your game is a separate question:
- **Unverified:** the scope for off-platform marketing and streams differs between partner libraries and has changed over time. Before using a library track in an external trailer, check the track's licence text on its Creator Store page and the current Roblox terms; if unclear, use music you own for trailers.
- Streamers playing your game are a common worry. **Rule of thumb:** offer a "streamer mode" setting that swaps music for tracks you own outright, as many games on other platforms do. It costs one setting and avoids content-ID claims landing on the creators who promote you.

## 5. Commissioning music

A contract (even a short email agreement) should state:
1. **Grant**: perpetual, worldwide licence (or full assignment) to use the track in the named experience and any successor or sequel, on Roblox and in marketing (trailers, ads, social clips, store pages, streams).
2. **Exclusivity**: whether the composer can resell the track. Non-exclusive is cheaper; you then cannot stop others using it.
3. **Content ID**: the composer must not register the track with content-identification services, or must whitelist your channels. Registered tracks generate claims on your own videos and on streamers.
4. **Deliverables**: stems, loop points, stingers, and the master in a format within Roblox's limits (48 kHz or lower, under 7 minutes per file).
5. **Credit**: where the composer is credited (game description, credits screen).

Pay through a traceable method and keep the agreement with the id manifest.

## 6. Player-supplied audio: boomboxes and radios

Letting players type an audio id is the highest-risk audio feature:
- Your game becomes a player for any public audio, including uploads that infringe and have not been caught yet.
- Players use it for harassment (earrape, slurs in songs). You are responsible for what your experience plays.
- **Rule of thumb:** offer a curated list of tracks you own or that come from the Roblox licensed library, not free id entry. If you must allow ids, restrict to a whitelist you review, add per-player mute, a server-wide volume cap, and an "all boomboxes off" setting. Never sell free id entry as a gamepass.
- Age and region rules apply to music content as to other content ([[Policy and Age Rules 2026]]).

## 7. Distributor and artist programmes

**Unverified:** Roblox has announced partnerships that let independent artists distribute music to Roblox through third-party music distributors, and has run licensed-music programmes with labels. If you plan to rely on artist tracks from such programmes, read the specific programme terms at the time; do not assume a track available on the platform is cleared for every use.

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Uploading commercial songs | Asset removed, account strike | Only owned, commissioned or library audio |
| Third-party ids from old scripts | Silent music after the privacy change | Re-upload with rights, or replace |
| Personal uploads in a group game | Silent live, fine in Studio | Upload to the group or grant permission |
| No monitoring of music ids | Silence after a takedown | Load-check job and fallbacks |
| Commission without Content ID clause | Claims on your own trailer | Contract clause and whitelists |
| Free-entry boombox gamepass | Infringement and harassment in your servers | Curated list, mute, volume cap |

## Checklist
- [ ] Every audio asset has source, licence and uploader in the manifest.
- [ ] Music uploaded by the group that owns the game, or granted explicitly.
- [ ] Periodic load check for music ids, with fallbacks per context.
- [ ] Commissioned tracks covered by a written grant including marketing and Content ID.
- [ ] Streamer-safe music option considered.
- [ ] Player audio features curated, mutable and capped.

## See also
[[Audio Pipeline]] · [[AI Audio - Voice Music and SFX]] · [[Music and Adaptive Audio]] · [[Sound Fundamentals]] · [[Policy and Age Rules 2026]] · [[Roblox Policies on AI-Generated Content]] · [[Links - Audio creation and uploading]]

## Connected notes
<!-- auto-links:start -->
[[Roblox Changes 2025-2026]] · Creator Store and Toolbox Safety · Sound Design Pitfalls - Reused Ids Onsets and Layered Loops
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Legal Basics - IP Licenses and Assets]] · [[Who Owns AI-Generated Code and Assets]] · [[Spatial Audio and Mixing]] · [[Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools]] · [[Combat Sound Design and Feedback]] · [[The Audio API - Players Emitters Wires and Effects]]
<!-- related:end -->
