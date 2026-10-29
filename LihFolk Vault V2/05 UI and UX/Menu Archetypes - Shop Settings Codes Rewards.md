---
tags: [ui, menus, shop, settings, codes, daily-rewards, quests, archetypes, type/guide, area/ui, level/intermediate, api/ProcessReceipt]
---
# Menu Archetypes - Shop Settings Codes Rewards

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: No pending state on claim and buy buttons (double requests).
> - Avoid: Granting purchases from client prompt callbacks.
> - Avoid: Code lists shipped to the client.
> - One presenter, one open panel, large close in the top-right, gamepad B closes.
> - Claim/buy buttons implement claim, claimed, locked and pending.
> - All grants and validations on the server; claims marked before paying.
>
> Cost: TL;DR ~140 tok · whole note ~4.0k tok. Read more: ## 2. The button state triad · ## 5. Codes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Most Roblox games, whatever their genre, ship the same half-dozen menus: a shop, settings, a codes box, daily or playtime rewards, a quest board and often a rebirth or prestige screen. Players have learned what these look like from the most popular games, so following the archetype makes your menu instantly usable, and breaking it costs players time. This note describes each archetype's anatomy, the server/client split behind its buttons, the numbers that worked in production, and the mistakes that turn a menu into a support ticket.

Sources: **Docs** (MarketplaceService, TextBox, GuiButton; October 2026), the **reference project** (one production game: quest board, free gifts, shop, settings and backpack rebuilds), a **cartoon simulator UI kit standard** (menu specs quoted as that kit's rules), and **rule of thumb**. Visual components are in [[UI Design Systems]]; purchases in [[Developer Products and ProcessReceipt]] and [[Game Passes]].

---

## 1. Shared anatomy

Every archetype is the same frame:

```
+------------------------------------------------------+
| [icon] TITLE                     (header action) [X] |  header, 60 px design
|======================================================|  2-tier divider
| [tab] [tab] [tab]                                     |  optional tab strip
|                                                      |
|   content: cards / rows / input                      |  scrolls if needed
|                                                      |
| footer: summary, "Claim all", timer                  |  optional
+------------------------------------------------------+
```

Fixed rules that hold across archetypes:

- **One open panel at a time**, opened and closed by one presenter (see [[ScreenGui Fundamentals]]).
- **Close is always top-right**, large (the reference project settled on 72 design px), and also bound to `B` on gamepad and `Escape`/the back action on keyboard.
- **The header colour tells players which menu they are in.** The cartoon kit assigns magenta to the shop, cyan to codes, silver to settings, violet to rebirth and lime to daily rewards.
- **The primary action is the brightest thing on screen.** One lime button per card at most.

---

## 2. The button state triad

Rewards and purchases share one state machine. Getting it wrong is how players double-claim or think a claim failed.

| State | Look (cartoon kit) | Interactable | Meaning |
|---|---|---|---|
| Claim / Buy | lime | yes | Available now |
| Claimed / Owned | silver | no | Done; keep visible as feedback |
| Locked | crimson, lock icon, requirement text | no (or opens an explanation) | Not yet available |
| Skip / Premium | amber | yes | Pay or watch to bypass |
| Pending | current colour, spinner, dimmed | no | Request in flight |

The **pending** state is the one most games forget. Between the click and the server's answer (50 to 500 ms on a normal connection, seconds on a bad one) the button must be non-interactable, or a second tap sends a second request.

```lua
--!strict
-- Client side of a claim button. The server is the authority; the client only asks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local claimRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimReward") :: RemoteFunction

type State = "claim" | "claimed" | "locked" | "pending"

local function paint(button: GuiButton, state: State)
	button.Interactable = state == "claim"
	button:SetAttribute("State", state) -- a style rule or painter reads this
end

local function bindClaim(button: GuiButton, rewardId: string, getState: () -> State)
	paint(button, getState())
	button.Activated:Connect(function()
		if getState() ~= "claim" then
			return
		end
		paint(button, "pending")
		local ok, result = pcall(claimRemote.InvokeServer, claimRemote, rewardId)
		if ok and result == true then
			paint(button, "claimed")
		else
			paint(button, getState()) -- server said no or the call failed: show truth
		end
	end)
end
```

The server must re-check everything (is it claimable, has it already been claimed, rate limit) and mark the claim **before** paying, so a crash between the two cannot double-pay. See [[Server Authority and Validation]] and [[Rate Limiting and Abuse Prevention]].

---

## 3. Shop

### Anatomy

- **Sections** with headers: game passes, products (currency packs, boosts), bundles, limited offers.
- **Cards**: art (square, never stretched; `ScaleType.Fit`), name, one-line benefit ("x2 Luck for 15 min"), price button with the Robux glyph.
- **Featured slot** at the top: one big card with a live preview (a `ViewportFrame` showing the item on the player's own avatar sells cosmetics far better than an icon; the reference project's exclusive armour card used one).
- **Owned** state for passes; **active timer** for running boosts ("ACTIVE 12:41").

### Purchases are prompts, not transactions

The shop button only calls `MarketplaceService:PromptProductPurchase` or `PromptGamePassPurchase`. The grant happens on the server in `ProcessReceipt` (products) or after ownership checks (passes). The UI updates when the server tells it the purchase was granted, never when the prompt closes. A shop that marks a pass owned on `PromptGamePassPurchaseFinished` without a server check is trivially spoofable and also wrong when the purchase fails.

### Sizing numbers from production

- Cards were 1.37 times larger on phones than on desktop (reference project's phone layout), with fewer columns, so prices and buttons stay tappable.
- Price strokes were reduced from 5 px to 3 px because thick outlines filled in the holes of digits; unreadable prices cost sales.
- A "server luck" product (a boost for everyone in the server) needed its card to say **this server** explicitly; buyers assumed it was global. Text precision is a monetization feature.

### Ethics

Price clearly, show what a product does, never hide the close button, and do not use fake countdowns. See [[Pricing and Store Design]] and [[Ethical Design and Player Trust]].

---

## 4. Settings

### Anatomy

Recessed rows, each with a label, an optional one-line description, and a control (toggle, segmented choice, slider). Group rows under headers: Audio, Graphics, Gameplay, Accessibility.

### What to include

| Setting | Why |
|---|---|
| Music and SFX volume (or toggles) | The most-used setting in any game |
| Graphics presets or effects toggles (particles, shadows, post-processing) | Low-end phones |
| Camera shake / screen effects | Comfort and accessibility |
| Reduced motion (respect the platform setting; see [[Accessibility]]) | Comfort |
| Hide other players' effects | Performance in crowded servers |
| UI scale | Players with large or small screens |
| Player list on/off | Players look for friends; the reference project restored it as a setting after hiding it outright |

Persist settings in the player's save (server) so they follow the player across devices, and apply them locally the moment they change.

### Production details

- On phones every control is at least 54 design units tall, with segmented options spaced by a per-holder step so taps do not hit neighbours (reference project).
- A settings row in the top bar (a gear next to Roblox's controls) is aligned live to `GuiService.TopbarInset` ([[Safe Areas and Insets]]).
- Main-menu flow: the reference project's main menu offers Play, Settings and Updates; Settings opens the same settings screen used in game, and a first-run prompt asks for graphics level with a per-device recommended default.

---

## 5. Codes

### Anatomy

A subtitle with instructions ("Follow us for codes!"), one dark input box, one lime "Redeem" button, and a result line (green "+500 Gems!" or red "Invalid or expired code").

### Server rules

- Validation, expiry, per-player one-time use and rate limiting live on the server. The client never contains the code list (it is readable by exploiters).
- Normalise input: trim spaces, compare case-insensitively.
- Rate limit attempts (for example 5 per minute per player) so the codes box is not a brute-force oracle.

```lua
--!strict
-- Client: send the text, show the server's answer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local redeem = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RedeemCode") :: RemoteFunction

local function bindCodes(box: TextBox, button: GuiButton, result: TextLabel)
	local busy = false
	local function submit()
		if busy then
			return
		end
		local code = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
		if code == "" then
			return
		end
		busy = true
		button.Interactable = false
		local ok, reply = pcall(redeem.InvokeServer, redeem, code)
		busy = false
		button.Interactable = true
		if ok and type(reply) == "table" and reply.ok then
			result.Text = tostring(reply.message)
			result.TextColor3 = Color3.fromRGB(120, 255, 120)
			box.Text = ""
		else
			result.Text = if ok and type(reply) == "table" then tostring(reply.message) else "Try again in a moment"
			result.TextColor3 = Color3.fromRGB(255, 110, 110)
		end
	end
	button.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)
end
```

Note that `TextBox.Text` typed by players is never auto-captured for translation (Docs), and placeholder text is. Keep the placeholder short ("Enter code").

---

## 6. Daily rewards and playtime gifts

### Daily rewards (7-day calendar)

The cartoon kit's spec: a 3 x 2 grid of 140 x 170 cards for days 1 to 6 (day header, 72 px icon, item name, state button) and a tall day-7 card spanning both rows (148 x 348) with a rainbow 45-degree gradient and a rotating sunburst. The visual promise of day 7 is the point: it is what brings players back.

Design rules:

- Reset on a fixed clock (UTC midnight is simplest and fair across regions), not "24 hours after last claim", which drifts later every day and punishes routine.
- Decide whether missing a day resets the streak, and say so on screen.
- Badge the entry button when a claim is ready. The reference project lit a red badge on the rail tab whenever the stored claim day was earlier than the current UTC day.

### Playtime gifts

The reference project replaced its daily chest tab with free gifts earned by **play time**: a 5-minute gift up to 9 times a day, a 15-minute gift up to 4 times, and a 60-minute gift once, with one interval banked so a short break does not waste progress, and a UTC daily reset. The screen shows each gift's odds, and **the odds on screen are the odds rolled**: the same config module drives both the display and the server roll, so they cannot disagree. That design choice matters for trust and for policy: see [[RNG Drops and Luck Systems]] and [[Roblox Policies Ratings and Compliance]].

---

## 7. Quest board

### Anatomy (the reference project's rebuilt board)

- Header with a scroll icon, title, and **"Resets in 5h 12m"** for the active tab.
- **Daily / Weekly** tabs, each with a red badge when something is ready to claim.
- A summary line: gift icon plus "done / total" for the tab, and a lime **Claim All** button with its own badge.
- Three cards per tab: objective text, tier and points pill, a gold progress bar showing `n / goal` inside the bar, reward icons with amounts (cash, gems, materials), and a reroll pill.
- Ready cards turn lime with a gold "Claim!"; claimed cards dim, show "Done" and a check mark.
- A weekly points chest track along the bottom.

### Polish details that came from player feedback

- **Do not interrupt with a popup when a quest completes.** An earlier version popped a separate "quest hunter" card on completion. The fix: open the quest dock on the HUD, fill the row's bar to the end, turn it gold, sweep a shine, pop and spark, show "Complete!" and the hint "Claim it at the Quest Board (J)". Rows finished while the dock was folded play the animation when it next opens.
- **Reward tooltips.** Hover (desktop) or tap (mobile, hidden after 2.5 s) on a reward icon explains it.
- **Number formatting.** "160M" once displayed as "16M" because trailing-zero stripping ran on integers. See [[Text Fonts and Rich Text]].
- **Claim All is one celebration**, not ten.

Quest logic and data are in [[Quests and Objectives]].

---

## 8. Rebirth / prestige

The cartoon kit's rebirth screen: two side-by-side cards comparing the current tier and the next ("Rebirth 1: x1 Money" arrow "Rebirth 2: x1.3 Money"), an orange-to-gold progress bar towards the requirement ("58% Completed"), the requirement box, and an amber "Skip" header button for a paid skip.

What matters: show **what you lose and what you gain** on the same screen, numerically. Players who rebirth by accident and lose progress they did not expect to lose do not come back. Add a confirmation step for anything that resets progress, and make the confirmation describe the reset in one line.

---

## 9. Progressive disclosure: unlock gating for menus

Not every menu should be reachable on minute one. The reference project's onboarding learned this the hard way:

- During the tutorial, the bottom bar shows **only** the button the current step needs (Roll on the roll step, Backpack on the equip step, nothing on the walk-to-gate step); auto-roll, the settings row and world prompts are hidden until the tutorial is done.
- The quest tracker stays hidden until onboarding is complete, so new players are not reading three objectives at once.
- Locked tiles show a lock veil with the unlock condition ("Unlocks in Zone 4") rather than disappearing, so players know the feature exists.
- A gate that cannot be entered yet says why and what to do ("Defeat the boss to open the next realm") instead of silently not working.

See [[First-Time User Experience and Onboarding]] and [[Progression Levels and Unlocks]].

---

## Common mistakes

- No pending state on claim and buy buttons (double requests).
- Granting purchases from client prompt callbacks.
- Code lists shipped to the client.
- Daily resets that drift ("24 h after last claim").
- Odds displayed from a different table than the one rolled.
- Completion popups that interrupt play.
- Rebirth screens that do not say what is reset.
- Every menu unlocked and badged on the first minute.

## Checklist

- [ ] One presenter, one open panel, large close in the top-right, gamepad B closes.
- [ ] Claim/buy buttons implement claim, claimed, locked and pending.
- [ ] All grants and validations on the server; claims marked before paying.
- [ ] Shop cards show benefit and duration in plain words.
- [ ] Settings persist in the save and include audio, graphics, motion and UI scale.
- [ ] Codes are rate-limited server-side.
- [ ] Rewards reset on a fixed UTC clock; badges reflect readiness.
- [ ] Displayed odds come from the rolled table.
- [ ] New players see menus only as they become relevant.

See also: [[UI Design Systems]], [[HUD Design]], [[Pricing and Store Design]], [[Developer Products and ProcessReceipt]], [[Game Passes]], [[Retention and Return Hooks]], [[Quests and Objectives]], [[Economies and Currencies]].

## Connected notes
<!-- auto-links:start -->
[[LihFolk UI Design System]] · LihFolk UI Spec · Daily Rewards System End to End · Skill - Roblox UI Builder · Reference - Purple Anime Settings UI (Claude + Figma)
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[UI Style Directions - A Visual Vocabulary for Briefs]] · [[Gamepad and Console UX]] · [[Responsive UI for Phone Tablet Console and PC]] · [[Tutorial Step Design Patterns - Teach by Doing]] · [[Notification and Toast Systems]] · [[Layout - Scale Offset and Constraints]] · [[UI Motion Language and Timing]] · [[Onboarding and FTUE - Tutorials That Keep Players]]
<!-- related:end -->
