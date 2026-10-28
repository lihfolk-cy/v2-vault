---
tags: [testing, playtesting, multi-client, devices, qa, protocol, bug-reports]
---
# Multi-Client and Device Playtesting Protocols

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Running a live session for bugs Studio's eight-client test would have found.
> - Avoid: Mixing verification, exploration and first-impression goals in one session.
> - Avoid: No build label, so reports describe an old build.
> - Session type chosen (verification, exploratory or experience).
> - Studio rehearsal with Server & Clients, Device Simulator and Network Simulator done.
> - Test place published; test data reset; build label visible.
>
> Read more (15 KB note): ## 2. Preparation · ## 3. The device matrix · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Multi-Client and Live Testing]] covers Studio's test modes, the multiplayer scenario matrix, gated cheat tools and where to test live. This note turns that into a repeatable procedure: how to prepare a session, who does what during it, which devices to cover, how to script the scenarios so they are actually run, and how to turn a chaotic hour of play into a short list of reproducible bugs. A playtest without a protocol mostly produces "it felt laggy" and "something was weird with the shop".

---

## 1. Three kinds of session

Mixing goals in one session is the most common reason sessions find little. Pick one per session.

| Session | Goal | Who | Length | Output |
|---|---|---|---|---|
| **Verification** | Confirm specific changes work with several players and devices | Developers, 2 to 4 people | 30 to 45 min | Pass or fail per test card |
| **Exploratory** | Find what nobody thought to test | Mixed; include someone new to the feature | 45 to 60 min | Bug reports with steps |
| **Experience** | Is it fun, is it clear, where do new players get stuck | People who have never seen the game | 20 to 40 min, observed silently | Notes on confusion and drop-off moments |

Rule of thumb: verification sessions before every release that touches multiplayer state; an exploratory session per major feature; experience sessions at milestones (first playable, before launch, before a big update). Experience sessions are wasted if the build still has verification failures: testers spend the time on bugs instead of on the experience.

---

## 2. Preparation

### Studio rehearsal first

Before people are invited, run the scenarios in Studio. Roblox docs (as of October 2026) say Server & Clients testing usually needs 1 to 2 clients but can simulate **up to eight**; the Party Simulator adds or removes local test players to match a setting during a Server & Clients test; the Device Simulator previews screen size, pixel density, on-screen keyboard and touch input; the Controller Emulator covers gamepads and other controllers; and the Network Simulator adds latency, jitter and packet loss ([[Testing Modes - Play Run and Multi-Client]]).

Studio rehearsal catches the replication logic bugs (late joiner, leave mid-action, UI isolation). It cannot catch: real devices' performance, real mobile networks, real asset loading from Roblox's servers, real purchases, teleports between places, and real human behaviour. That is what the live session is for. Do not spend live testers' time on things Studio would have found.

### Build and environment

- Publish to a **test place** or a test experience with its own data stores, not the live game ([[Places Universes and Experience Settings]]). If you must test in the live experience, use a private server and a developer-only feature flag ([[Global State and Live Config]]).
- Put a **build label** on screen: a short version string (for example `0.42.3`) in a corner of the HUD in test builds. Every bug report and screenshot then says which build it came from. Without it, half the reports in a busy week are about a build that is already fixed.
- Reset test data to a known state, or give testers commands to set it (level, currency, unlocked items) through the gated cheat service ([[Multi-Client and Live Testing]]).
- Write the **test cards** (section 4) before the session, not during.

### A bug-marker command for testers

Testers are bad at describing where and when something happened. Give them a key or chat command that writes a marker to the server log with everything you need:

```lua
--!strict
-- Server: a developer-gated "mark" remote. The client sends a short note;
-- the server logs it with context and returns a short code the tester writes in the report.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local BUILD = "0.42.3" -- set by your release script
local MarkRemote = Instance.new("RemoteEvent")
MarkRemote.Name = "TesterMark"
MarkRemote.Parent = game:GetService("ReplicatedStorage")

local lastMark: { [Player]: number } = {}

local function isTester(player: Player): boolean
	-- Replace with your own allowlist or group rank check.
	return player:GetAttribute("Tester") == true
end

MarkRemote.OnServerEvent:Connect(function(player: Player, note: unknown)
	if not isTester(player) or typeof(note) ~= "string" then
		return
	end
	local now = os.clock()
	if (lastMark[player] or 0) > now - 2 then
		return -- simple rate limit
	end
	lastMark[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local code = string.sub(HttpService:GenerateGUID(false), 1, 6)
	print(string.format("[MARK %s] build=%s t=%.1f pos=%s players=%d note=%q",
		code, BUILD, workspace.DistributedGameTime,
		root and tostring(root.Position) or "none",
		#Players:GetPlayers(), string.sub(note, 1, 200)))
	MarkRemote:FireClient(player, code)
end)

Players.PlayerRemoving:Connect(function(player)
	lastMark[player] = nil
end)
```

The tester presses the key, gets a six-character code on screen, and writes the code in the report. You search the server log (or your error pipeline, [[Crash and Error Telemetry]]) for the code and get exact time, position and player count. Note that the server log is only available while the server runs; ship marks to your own logging if sessions are long.

---

## 3. The device matrix

You cannot test every device. You can test every *class* of device, chosen by what breaks.

| Slot | Device | What it catches |
|---|---|---|
| Low phone | The weakest phone you intend to support (2 to 3 GB of memory, an older chip) | Memory crashes, frame rate, texture memory, join time |
| Mid phone, small screen | A common phone with a notch or rounded corners | Layout, safe areas, touch target size, text size ([[Safe Areas and Insets]]) |
| Tablet | Any tablet | Aspect ratio, scale constraints, UI that looks lost on a large touch screen |
| PC, low graphics | Desktop with graphics quality forced low | Visual fallbacks, things that only look right at high quality |
| PC, high | A good desktop | The reference experience; frame-time spikes are easiest to profile here |
| Console or gamepad | Console, or a gamepad on PC | Selection navigation, button prompts, menus you cannot leave ([[Gamepad and Console UX]]) |

Rule of thumb: a verification session needs at least the low phone, one other touch device, a PC and a gamepad. If you have only one tester, rotate devices across sessions rather than always testing on your development PC.

Per-device checks that take under a minute each:
- Join time from pressing Play to controllable character (stopwatch is fine; [[Case Study - Fast Join and Deferred Loading]]).
- Frame rate and memory in the heaviest area, from the Performance Stats or the Developer Console (F9 on PC; type `/console` in chat on mobile, per Roblox docs).
- Every menu opened and closed with that device's input only.
- One full core loop.

### Network conditions

Have at least one tester on a mobile data connection or a deliberately poor network, and rehearse with the Network Simulator before the session. Bugs that only appear with latency include double-claims from impatient double taps, client effects that play before the server rejects the action, and UI that waits forever for a response that was dropped.

---

## 4. Test cards

A test card is one scenario, written so anybody can run it and anybody can judge the result. Short, numbered, with an expected result per step.

```
CARD M-07  Trade cancelled by leaving
Build: 0.42.3     Players: 2 (A on PC, B on phone)     Time: 5 min
Setup: A has 3 Rare swords, B has 500 coins (cheat: /give)
1. A opens a trade with B, offers 1 Rare sword.     Expect: B sees the offer within 1 s.
2. B adds 200 coins and accepts.                    Expect: A sees "B accepted".
3. A leaves the game before accepting.              Expect: B's trade window closes with a message.
4. B checks inventory.                              Expect: B still has 500 coins, no sword.
5. A rejoins, checks inventory.                     Expect: A still has 3 Rare swords.
Result: PASS / FAIL (mark code if FAIL)
```

What makes a card good:
- **Starting state is explicit.** Most "cannot reproduce" outcomes come from different starting states.
- **Each step has one expected result.** "Works" is not an expected result.
- **Roles are named** (A, B) and tied to devices.
- **It targets one risk.** The card above is about leave-during-trade. A separate card covers both players accepting at the same moment.

Write cards from three sources: the multiplayer scenario matrix in [[Multi-Client and Live Testing]], the change list of this release, and the bug history (every fixed multiplayer bug gets a card that stays in the deck).

---

## 5. Running the session

### Roles

| Role | Does | Does not |
|---|---|---|
| Host | Starts the server, reads cards aloud, keeps time, decides when to move on | Play the cards (they need to watch) |
| Players | Run the cards on their assigned devices, press the mark key on anything odd | Debug in the middle of a card |
| Scribe | Records PASS/FAIL, mark codes and one-line notes | Discuss fixes |

With three people, the host is also the scribe. With two, run fewer cards and record after each one.

### A 45-minute verification session

| Minutes | Activity |
|---|---|
| 0 to 5 | Everyone joins; host checks build label on each screen; Developer Console open on one PC to watch the server log |
| 5 to 30 | Cards in priority order. Fail a card, mark it, move on. No debugging during the session |
| 30 to 38 | Free play in the changed areas; everyone uses the mark key generously |
| 38 to 42 | Join and leave pass: one player rejoins, one switches server, one joins late and checks every shared state (doors, events, boss health) |
| 42 to 45 | Host reads the fail list aloud and confirms each has a mark code |

The rule "no debugging during the session" matters more than it looks. The first bug found pulls two developers into a discussion, the other testers stand around, and the session ends with five cards run instead of twenty. Debug afterwards, with the mark codes.

### Experience sessions are different

Do not explain the game. Do not help unless the tester is stuck for more than about two minutes (rule of thumb). Write down *where* they hesitated, what they clicked first, and what they said out loud. Ask questions only at the end: "What were you trying to do?" beats "Did you like it?". Five observed new players usually find most of the major onboarding problems (rule of thumb borrowed from usability research; [[First-Time User Experience and Onboarding]]).

---

## 6. Bug reports that can be fixed

Template:

```
Title: [Area] What went wrong, in one line
Build: 0.42.3     Device: phone (low)     Network: mobile data
Mark code: 7F3A2C
Steps:
1. ...
2. ...
Expected: ...
Actual: ...
Happens: always / 2 of 5 tries / once
Evidence: screenshot or clip; console errors copied as text
```

Triage right after the session, while memories are fresh:

| Severity | Definition | Action |
|---|---|---|
| Blocker | Data loss, purchase problems, crash, cannot progress | Fix before release; re-run the card |
| Major | Core loop broken for some players or devices | Fix before release, or ship with a kill switch off |
| Minor | Wrong but workaround exists | Schedule |
| Polish | Cosmetic | Backlog |

"Happens once" bugs with a mark code are still worth a look: the server log at that moment often shows an error the tester never saw.

---

## 7. Reporting what was tested

After the session, write a short result in the release notes using explicit levels ([[Multi-Client and Live Testing]] defines them): which cards passed, on which devices, under which network conditions, and which cards were not run. "Multi-client tested: 18 of 20 cards passed on low phone, tablet, PC and gamepad; M-07 and M-12 failed (blockers, fixed in 0.42.4, re-run passed)" is a statement a release owner can act on.

The reference project shows the cost of skipping this. Its workflow kept all Play-mode testing with the owner, for good reasons in a shared editing session, but no testing time was scheduled. After about two weeks every system carried the label "Edit-verified, not play-tested", and the label stayed for the rest of the month (measured). The protocol in this note is the fix: testing as a scheduled, carded activity with its own time, not something squeezed in after building ([[Team Roles and Workflows]]).

---

## 8. Testing with a community

Once you have players, a test group (a separate experience or a private server with invited members) gives you more devices and more human chaos than any team. Practical rules (rule of thumb):
- Keep cards for your own team; give community testers goals ("try to break the trading system") and the mark key.
- Never test unreleased monetisation on community testers with real Robux. Test purchases with your own accounts in a test place.
- Respect privacy and policy: do not collect personal information beyond what Roblox provides, and keep testing communications on platforms appropriate for the age of your audience ([[Roblox Policies Ratings and Compliance]], [[Player Privacy and Data Deletion]]).
- Thank testers in a visible way (a badge or a title); it keeps the group alive ([[Community Building]]).

---

## Common mistakes

- Running a live session for bugs Studio's eight-client test would have found.
- Mixing verification, exploration and first-impression goals in one session.
- No build label, so reports describe an old build.
- Undefined starting states, so nothing reproduces.
- Debugging during the session.
- Always testing on the development PC.
- Testing only on good Wi-Fi.
- Reports without device, build, or steps.
- Not re-running the failed card after the fix.

## Checklist

- [ ] Session type chosen (verification, exploratory or experience).
- [ ] Studio rehearsal with Server & Clients, Device Simulator and Network Simulator done.
- [ ] Test place published; test data reset; build label visible.
- [ ] Device matrix covered: low phone, other touch device, PC, gamepad.
- [ ] At least one tester on a poor network.
- [ ] Test cards written with setup, steps, expected results.
- [ ] Roles assigned: host, players, scribe.
- [ ] Mark key working; codes recorded for every fail.
- [ ] Triage done the same day; blockers re-tested after fixes.
- [ ] Results written as explicit test levels in the release notes.

## See also

[[Multi-Client and Live Testing]], [[Testing Modes - Play Run and Multi-Client]], [[Automated Testing with TestEZ and Jest-Lua]], [[QA Checklists Before Release]], [[Responsive UI for Phone Tablet Console and PC]], [[Mobile and Low-End Optimization]], [[Gamepad and Console UX]], [[Accessibility]], [[Crash and Error Telemetry]], [[Release Process and Rollbacks]], [[First-Time User Experience and Onboarding]]

## Connected notes
<!-- auto-links:start -->
[[Debugging Start Here]] · [[Debugging Live Servers]] · [[Case Study - Phone UI Overhaul]] · [[Safe Area]] · [[Skill - Roblox UI Builder]] · [[Cookbook - UI]]
<!-- auto-links:end -->
