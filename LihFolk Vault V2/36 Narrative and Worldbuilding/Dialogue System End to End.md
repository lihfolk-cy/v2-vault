---
tags: [narrative, dialogue, worked-build, luau, strict, server-authority, localization, npc, ui]
---
# Dialogue System End to End

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Tree in `ReplicatedStorage` -> Server-only data, one screen at a time
> - Avoid: Generic greeting listed before the specific one -> Order start entries from specific to general
> - Avoid: Paying effect without a flag -> Set a flag in the same choice; validator warns
> - Trees in `ServerStorage`; only `DialogueShared` replicates.
> - Every line and choice is a key plus an English default; CSV generated from trees.
> - Start entries ordered from specific to general.
>
> Cost: TL;DR ~160 tok · whole note ~12.2k tok. Read more: ## 5. Server: DialogueService · ## 7. Client: DialogueController · ## 11. Common mistakes and extensions · ## 12. Checklist
<!-- tldr:end -->

This note builds a complete NPC dialogue system from an empty place: conversations written as data, a server that owns every decision (which greeting you get, which choices you see, what a choice does), a client that only displays and reports clicks, conditions and effects that other systems plug into, text that is sent as keys and translated on each player's own client, a typewriter that does not break translation or accessibility, and a validator that catches broken trees before players do.

The writing craft lives in [[Writing Dialogue for Roblox Players]]. The theory of quest objectives is in [[Quests and Objectives]], and a full quest build is in [[Quest Chain System End to End]]; this system plugs into that kind of quest service through one effect. Translation plumbing (automatic capture, the cloud table, format specifiers) is covered in [[Localization]] and [[Localization Pipeline]]; this note only uses it.

> **All code in this note is reviewed, not run.** It is written in `--!strict` Luau against Roblox docs (as of October 2026) and checked by reading. Section 9 lists the tests to run before trusting it.

Labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**.

---

## 1. The decisions that shape everything

**The server owns the conversation.** The client never says "I am on node `reward`" or "give me the reward choice". It says only "on screen number 41 I clicked option 2". The server knows which screen 41 was, which options it showed, and whether option 2 is still allowed. This matters more than it looks: a dialogue choice that grants coins, starts a quest or opens a shop is a remote that hands out value, and every rule in [[Server Authority and Validation]] applies to it.

**Trees live on the server.** The dialogue data sits in `ServerStorage`, not `ReplicatedStorage`. Anything replicated can be read by an exploiter, so a tree in `ReplicatedStorage` leaks every spoiler, every secret branch, and every condition you use to gate rewards. The client receives one screen at a time.

**Text travels as keys plus a default.** The server sends `{ key = "npc.smith.intro", default = "New face. You look like you could use a better blade." }`, never a finished sentence. Each client turns the key into its own language. This follows the rule in [[Localization]] (server messages should be keys and parameters) and has a second benefit: the English default doubles as the fallback when a key has no translation yet.

**Effects are named, not coded into trees.** A tree says `{ kind = "give", name = "Coins", value = 50 }`. The dialogue system does not know what coins are. The game registers a function for `give` at boot. That keeps trees as plain data that writers can edit, and keeps the dialogue code free of every other system's internals (the same idea as the signal bus in [[Quests and Objectives]]).

**One conversation per player, not per NPC.** Three players can talk to the same blacksmith at once, each in their own private panel, each on a different branch. Shared conversations (a group cutscene, a vote) are a different feature; see section 11.

| Decision | Alternative | Why this one |
|---|---|---|
| Server-driven screens | Client walks a replicated tree | Rewards and spoilers stay safe; one source of truth |
| Trees in `ServerStorage` | Trees in `ReplicatedStorage` | Exploiters can read anything replicated |
| Keys plus English default | Finished strings | Per-player language; no capture junk |
| Named effects and conditions | Functions inside tree data | Trees stay data; systems stay decoupled |
| Private panel per player | Speech bubbles for everything | Readable, choice-capable, not spammy for others |
| Screen tokens | Trusting node ids from the client | Stale and duplicate clicks are ignored for free |

---

## 2. Folder layout

```
ReplicatedStorage
  DialogueShared            (ModuleScript)  types and constants, no data
  DialogueRemotes           (Folder, created by the server)
    Show                    (RemoteEvent)   server -> client: one screen, or nil to close
    Input                   (RemoteEvent)   client -> server: token, choice index
ServerStorage
  DialogueTrees             (Folder)
    Smith                   (ModuleScript)  one tree per module
ServerScriptService
  Dialogue
    DialogueService         (ModuleScript)  sessions, validation, conditions, effects
  DialogueBoot              (Script)        registers game effects, calls init
StarterPlayer
  StarterPlayerScripts
    DialogueController      (LocalScript)   UI, typewriter, translation, input
Workspace
  Smith                     (Model, tag "DialogueNpc", attributes TreeId = "Smith", DisplayName = "Hedda")
```

NPCs are found by the CollectionService tag `DialogueNpc` and say which tree they use through a `TreeId` attribute ([[CollectionService Patterns]], [[Instances Attributes and Tags]]). A second copy of the same NPC in another hub needs no extra wiring, and because state is per player rather than per NPC, copies cannot share state by accident. That was a real bug class in the reference project, where a copied quest NPC kept its original's "home" attribute (measured in the reference project).

---

## 3. Shared types

```lua
--!strict
-- ReplicatedStorage/DialogueShared (ModuleScript)
-- Types and constants only. No dialogue data lives here (it would replicate).

-- A piece of player-facing text: a localization key plus the English source.
export type TextRef = { key: string, default: string }

-- Parameters for {Name} placeholders. A TextRef value is translated on the
-- client before it is inserted (for item names that are themselves keyed).
export type ArgValue = string | number | TextRef
export type Args = { [string]: ArgValue }

-- Conditions and effects are data; their meaning is registered on the server.
export type Condition = { kind: string, name: string?, value: number? }
export type Effect = { kind: string, name: string?, value: number? }

export type Choice = {
	text: TextRef,
	args: Args?,
	next: string?, -- nil ends the conversation
	conditions: { Condition }?,
	effects: { Effect }?,
}

export type Node = {
	speaker: TextRef,
	line: TextRef,
	args: Args?,
	portrait: string?, -- an image id string, optional
	effects: { Effect }?, -- applied every time the node is shown
	choices: { Choice }?, -- either choices...
	next: string?, -- ...or a single "Continue" target, or neither (end)
}

export type StartEntry = { node: string, conditions: { Condition }? }

export type Tree = {
	id: string,
	start: { StartEntry }, -- first entry whose conditions pass wins
	nodes: { [string]: Node },
}

-- What actually crosses the network: one screen.
export type ChoiceView = { index: number, text: TextRef, args: Args? }

export type LineView = {
	token: number, -- echoed back by the client; changes every screen
	speaker: TextRef,
	line: TextRef,
	args: Args?,
	portrait: string?,
	choices: { ChoiceView }, -- empty: show one Continue or Goodbye button
	final: boolean, -- true: the single button ends the conversation
}

local DialogueShared = {}
DialogueShared.REMOTE_FOLDER = "DialogueRemotes"
DialogueShared.MAX_CHOICES = 4
return DialogueShared
```

Why `MAX_CHOICES = 4`: four buttons is what fits under a two-line body on a phone in landscape without scrolling, and it maps onto number keys 1 to 4 and a gamepad's vertical list (rule of thumb; see [[Writing Dialogue for Roblox Players]] for the writing reasons). The validator enforces it so a writer cannot add a fifth option that silently falls off the screen.

---

## 4. A tree as data

```lua
--!strict
-- ServerStorage/DialogueTrees/Smith (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = require(ReplicatedStorage:WaitForChild("DialogueShared"))

local function t(key: string, default: string): Shared.TextRef
	return { key = key, default = default }
end

local SMITH = t("npc.smith.name", "Hedda")
local BYE = t("dialogue.bye", "Goodbye.")

local tree: Shared.Tree = {
	id = "Smith",
	start = {
		-- Returning player with the ore quest finished but not turned in.
		{ node = "turnIn", conditions = { { kind = "flag", name = "OreCollected" }, { kind = "notFlag", name = "OreRewarded" } } },
		{ node = "returning", conditions = { { kind = "flag", name = "MetSmith" } } },
		{ node = "intro" },
	},
	nodes = {
		intro = {
			speaker = SMITH,
			line = t("npc.smith.intro", "New face. {Player}, is it? You look like you could use a better blade."),
			args = { Player = "$player" },
			effects = { { kind = "setFlag", name = "MetSmith" } },
			choices = {
				{ text = t("npc.smith.ask_work", "Got any work?"), next = "offer" },
				{ text = t("npc.smith.ask_town", "What is this place?"), next = "town" },
				{ text = BYE },
			},
		},
		returning = {
			speaker = SMITH,
			line = t("npc.smith.returning", "Back again. Forge is hot."),
			choices = {
				{
					text = t("npc.smith.ask_work", "Got any work?"),
					next = "offer",
					conditions = { { kind = "notFlag", name = "OreQuestStarted" } },
				},
				{ text = t("npc.smith.ask_town", "What is this place?"), next = "town" },
				{ text = BYE },
			},
		},
		town = {
			speaker = SMITH,
			line = t("npc.smith.town", "Last stop before the Ashfields. Everyone here sells something to people heading out."),
			next = "returning",
		},
		offer = {
			speaker = SMITH,
			line = t("npc.smith.offer", "Bring me {Count:int} iron ore from the quarry and I will pay you."),
			args = { Count = 5 },
			choices = {
				{
					text = t("npc.smith.accept", "Deal."),
					next = "accepted",
					effects = { { kind = "setFlag", name = "OreQuestStarted" }, { kind = "startQuest", name = "OreRun" } },
				},
				{ text = t("npc.smith.decline", "Maybe later."), next = "returning" },
			},
		},
		accepted = {
			speaker = SMITH,
			line = t("npc.smith.accepted", "Quarry is past the east gate. Mind the beetles."),
		},
		turnIn = {
			speaker = SMITH,
			line = t("npc.smith.turnin", "That is good ore. Here, you earned this."),
			choices = {
				{
					text = t("npc.smith.thanks", "Thanks."),
					-- The flag is set in the same choice that pays, and the start
					-- condition checks it, so this node cannot pay twice.
					effects = { { kind = "setFlag", name = "OreRewarded" }, { kind = "give", name = "Coins", value = 150 } },
				},
			},
		},
	},
}

return tree
```

Three things in this tree are deliberate:

- **The start list is ordered from most specific to least.** The turn-in greeting must come before the generic "returning" greeting, or a player with finished ore will never see it. This is the most common authoring bug in condition-driven greetings.
- **`$player` is a server-side token.** The server replaces it with `player.DisplayName` before sending. Display names are already filtered by Roblox, so showing them back to the player who owns them is fine; they must not be translated, which is why they go in as a plain string argument rather than a key.
- **Every paying choice is guarded by a flag it sets itself.** Without the `OreRewarded` flag, a player could walk away and back and get paid again. The dialogue system cannot know which effects are one-off, so the tree must say so. Section 10 lists the validator rule that flags unguarded `give` effects.

---

## 5. Server: DialogueService

```lua
--!strict
-- ServerScriptService/Dialogue/DialogueService (ModuleScript)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = require(ReplicatedStorage:WaitForChild("DialogueShared"))

type Tree = Shared.Tree
type Node = Shared.Node
type Choice = Shared.Choice
type Condition = Shared.Condition
type Effect = Shared.Effect
type Args = Shared.Args

export type ConditionFn = (player: Player, condition: Condition) -> boolean
export type EffectFn = (player: Player, effect: Effect) -> ()
export type FlagStore = {
	get: (player: Player, name: string) -> boolean,
	set: (player: Player, name: string, value: boolean) -> (),
}

type Session = {
	token: number,
	tree: Tree,
	nodeId: string,
	anchor: BasePart,
	visible: { Choice },
	lastInput: number,
}

local TAG = "DialogueNpc"
local MAX_DISTANCE = 16 -- studs: prompt distance (10) plus slack for walking while reading
local MIN_INPUT_GAP = 0.15 -- seconds between accepted inputs per player
local WATCH_INTERVAL = 0.5 -- seconds between distance checks

local DialogueService = {}

local trees: { [string]: Tree } = {}
local sessions: { [Player]: Session } = {}
local conditionFns: { [string]: ConditionFn } = {}
local effectFns: { [string]: EffectFn } = {}
local nextToken = 0
local started = false

-- Default flag store: memory only. Replace it with one backed by your
-- player profile (see init) so flags survive rejoining.
local memoryFlags: { [Player]: { [string]: boolean } } = {}
local memoryStore: FlagStore = {
	get = function(player: Player, name: string): boolean
		local f = memoryFlags[player]
		return f ~= nil and f[name] == true
	end,
	set = function(player: Player, name: string, value: boolean)
		local f = memoryFlags[player] or {}
		memoryFlags[player] = f
		f[name] = if value then true else nil
	end,
}
local store: FlagStore = memoryStore

-- Remotes ------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = Shared.REMOTE_FOLDER
local showRemote = Instance.new("RemoteEvent")
showRemote.Name = "Show"
showRemote.Parent = remotes
local inputRemote = Instance.new("RemoteEvent")
inputRemote.Name = "Input"
inputRemote.Parent = remotes

-- Registration ---------------------------------------------------------------
function DialogueService.registerCondition(kind: string, fn: ConditionFn)
	assert(not started, "register conditions before init")
	conditionFns[kind] = fn
end

function DialogueService.registerEffect(kind: string, fn: EffectFn)
	assert(not started, "register effects before init")
	effectFns[kind] = fn
end

-- Built-ins: flags are the backbone of branching.
conditionFns.flag = function(player: Player, c: Condition): boolean
	return c.name ~= nil and store.get(player, c.name)
end
conditionFns.notFlag = function(player: Player, c: Condition): boolean
	return c.name ~= nil and not store.get(player, c.name)
end
effectFns.setFlag = function(player: Player, e: Effect)
	if e.name then
		store.set(player, e.name, true)
	end
end
effectFns.clearFlag = function(player: Player, e: Effect)
	if e.name then
		store.set(player, e.name, false)
	end
end

-- Helpers ------------------------------------------------------------------
local function checkAll(player: Player, list: { Condition }?): boolean
	if not list then
		return true
	end
	for _, c in list do
		local fn = conditionFns[c.kind]
		if not fn then
			warn(`[Dialogue] unknown condition '{c.kind}', treating as false`)
			return false -- fail closed: an unknown gate never opens
		end
		local ok, result = pcall(fn, player, c)
		if not ok or result ~= true then
			return false
		end
	end
	return true
end

local function applyEffects(player: Player, list: { Effect }?)
	if not list then
		return
	end
	for _, e in list do
		local fn = effectFns[e.kind]
		if fn then
			local ok, err = pcall(fn, player, e)
			if not ok then
				warn(`[Dialogue] effect '{e.kind}' failed: {err}`)
			end
		else
			warn(`[Dialogue] unknown effect '{e.kind}'`)
		end
	end
end

local function resolveArgs(player: Player, args: Args?): Args?
	if not args then
		return nil
	end
	local out: Args = {}
	for name, value in args do
		out[name] = if value == "$player" then player.DisplayName else value
	end
	return out
end

local function anchorOf(npc: Instance): BasePart?
	if npc:IsA("BasePart") then
		return npc
	end
	if npc:IsA("Model") then
		local root = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root
		end
	end
	return nil
end

local function inRange(player: Player, anchor: BasePart): boolean
	local character = player.Character
	if not character or not anchor.Parent then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - anchor.Position).Magnitude <= MAX_DISTANCE
end

-- Sessions -------------------------------------------------------------------
local function endSession(player: Player, reason: string)
	if sessions[player] then
		sessions[player] = nil
		showRemote:FireClient(player, nil, reason)
	end
end

local function show(player: Player, session: Session, nodeId: string)
	local node = session.tree.nodes[nodeId]
	if not node then
		warn(`[Dialogue] {session.tree.id}: missing node '{nodeId}'`)
		endSession(player, "error")
		return
	end
	session.nodeId = nodeId
	applyEffects(player, node.effects)
	if sessions[player] ~= session then
		return -- an effect ended or replaced the conversation
	end

	local visible: { Choice } = {}
	local views: { Shared.ChoiceView } = {}
	for _, choice in node.choices or {} do
		if #visible >= Shared.MAX_CHOICES then
			break
		end
		if checkAll(player, choice.conditions) then
			table.insert(visible, choice)
			table.insert(views, { index = #visible, text = choice.text, args = resolveArgs(player, choice.args) })
		end
	end
	session.visible = visible

	nextToken += 1
	session.token = nextToken
	local view: Shared.LineView = {
		token = session.token,
		speaker = node.speaker,
		line = node.line,
		args = resolveArgs(player, node.args),
		portrait = node.portrait,
		choices = views,
		final = #visible == 0 and node.next == nil,
	}
	showRemote:FireClient(player, view)
end

function DialogueService.start(player: Player, treeId: string, npc: Instance)
	if sessions[player] then
		return
	end
	local tree = trees[treeId]
	local anchor = anchorOf(npc)
	if not tree or not anchor or not inRange(player, anchor) then
		return
	end
	local startNode: string? = nil
	for _, entry in tree.start do
		if checkAll(player, entry.conditions) then
			startNode = entry.node
			break
		end
	end
	if not startNode then
		return
	end
	local session: Session = {
		token = 0,
		tree = tree,
		nodeId = startNode,
		anchor = anchor,
		visible = {},
		lastInput = 0,
	}
	sessions[player] = session
	show(player, session, startNode)
end

function DialogueService.stop(player: Player)
	endSession(player, "stopped")
end

function DialogueService.isTalking(player: Player): boolean
	return sessions[player] ~= nil
end

inputRemote.OnServerEvent:Connect(function(player: Player, token: unknown, index: unknown)
	local session = sessions[player]
	if not session then
		return
	end
	if typeof(token) ~= "number" or typeof(index) ~= "number" then
		return
	end
	if token ~= session.token then
		return -- stale screen or a double click: ignore silently
	end
	if index ~= index or index % 1 ~= 0 then
		return -- NaN or a fraction
	end
	local now = os.clock()
	if now - session.lastInput < MIN_INPUT_GAP then
		return
	end
	session.lastInput = now

	if index == -1 then
		endSession(player, "closed")
		return
	end
	if not inRange(player, session.anchor) then
		endSession(player, "distance")
		return
	end

	local node = session.tree.nodes[session.nodeId]
	if not node then
		endSession(player, "error")
		return
	end

	local nextId: string? = nil
	if #session.visible == 0 then
		if index ~= 0 then
			return
		end
		nextId = node.next
	else
		local choice = session.visible[index]
		if not choice then
			return
		end
		-- State may have changed since the screen was drawn (another system
		-- set a flag, a quest finished). Re-check before acting.
		if not checkAll(player, choice.conditions) then
			show(player, session, session.nodeId)
			return
		end
		applyEffects(player, choice.effects)
		if sessions[player] ~= session then
			return
		end
		nextId = choice.next
	end

	if nextId then
		show(player, session, nextId)
	else
		endSession(player, "done")
	end
end)

-- Validation -----------------------------------------------------------------
local seenKeys: { [string]: string } = {} -- key -> default, across all trees

local function validate(tree: Tree): { string }
	local problems: { string } = {}
	local function note(message: string)
		table.insert(problems, `{tree.id}: {message}`)
	end
	local function checkTarget(from: string, target: string?)
		if target and not tree.nodes[target] then
			note(`{from} -> missing node '{target}'`)
		end
	end
	local function checkText(where: string, ref: Shared.TextRef)
		if ref.key == "" or ref.default == "" then
			note(`{where}: empty key or default`)
			return
		end
		local previous = seenKeys[ref.key]
		if previous and previous ~= ref.default then
			note(`{where}: key '{ref.key}' reused with different English text`)
		end
		seenKeys[ref.key] = ref.default
	end
	local function checkKinds(where: string, conds: { Condition }?, effs: { Effect }?)
		for _, c in conds or {} do
			if not conditionFns[c.kind] then
				note(`{where}: unknown condition '{c.kind}'`)
			end
		end
		for _, e in effs or {} do
			if not effectFns[e.kind] then
				note(`{where}: unknown effect '{e.kind}'`)
			end
		end
	end

	if #tree.start == 0 then
		note("no start entries")
	end
	for i, entry in tree.start do
		checkTarget(`start[{i}]`, entry.node)
		checkKinds(`start[{i}]`, entry.conditions, nil)
	end
	for id, node in tree.nodes do
		checkText(`{id}.speaker`, node.speaker)
		checkText(`{id}.line`, node.line)
		checkTarget(id, node.next)
		checkKinds(id, nil, node.effects)
		local choices = node.choices or {}
		if #choices > Shared.MAX_CHOICES then
			note(`{id}: {#choices} choices, max is {Shared.MAX_CHOICES}`)
		end
		if #choices > 0 and node.next then
			note(`{id}: has both choices and next; next is ignored`)
		end
		for i, choice in choices do
			local where = `{id}.choices[{i}]`
			checkText(where, choice.text)
			checkTarget(where, choice.next)
			checkKinds(where, choice.conditions, choice.effects)
			-- A paying effect with no flag guard can be farmed by re-talking.
			local pays, sets = false, false
			for _, e in choice.effects or {} do
				if e.kind == "give" then
					pays = true
				elseif e.kind == "setFlag" then
					sets = true
				end
			end
			if pays and not sets then
				note(`{where}: 'give' without a 'setFlag' in the same choice`)
			end
		end
	end
	return problems
end

-- Binding NPCs -----------------------------------------------------------------
local function makePrompt(anchor: BasePart, npc: Instance): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	local displayName = npc:GetAttribute("DisplayName")
	prompt.ObjectText = if typeof(displayName) == "string" then displayName else ""
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	return prompt
end

local function bindNpc(npc: Instance)
	local rawId = npc:GetAttribute("TreeId")
	local anchor = anchorOf(npc)
	if typeof(rawId) ~= "string" or not anchor then
		warn(`[Dialogue] {npc:GetFullName()} needs a TreeId attribute and a root part`)
		return
	end
	local treeId = rawId :: string
	if not trees[treeId] then
		warn(`[Dialogue] {npc:GetFullName()} uses unknown tree '{treeId}'`)
		return
	end
	local prompt: ProximityPrompt = anchor:FindFirstChildOfClass("ProximityPrompt") or makePrompt(anchor, npc)
	prompt:SetAttribute("Dialogue", true)
	prompt.Triggered:Connect(function(player: Player)
		DialogueService.start(player, treeId, npc)
	end)
end

-- Init -----------------------------------------------------------------------
function DialogueService.init(customStore: FlagStore?)
	assert(not started, "DialogueService.init called twice")
	started = true
	if customStore then
		store = customStore
	end

	local folder = ServerStorage:WaitForChild("DialogueTrees")
	local problemCount = 0
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if not ok then
				warn(`[Dialogue] {module.Name} failed to load: {result}`)
				continue
			end
			local tree = result :: Tree
			for _, problem in validate(tree) do
				warn(`[Dialogue] {problem}`)
				problemCount += 1
			end
			trees[tree.id] = tree
		end
	end
	if problemCount > 0 then
		warn(`[Dialogue] {problemCount} problem(s) found in dialogue trees`)
	end

	remotes.Parent = ReplicatedStorage

	for _, npc in CollectionService:GetTagged(TAG) do
		bindNpc(npc)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(bindNpc)

	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
		memoryFlags[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(WATCH_INTERVAL)
			for player, session in sessions do
				if not inRange(player, session.anchor) then
					endSession(player, "distance")
				end
			end
		end
	end)
end

return DialogueService
```

### Notes on the server code

- **Tokens, not node ids.** Every screen gets a fresh number from a single counter. The client echoes it back. A double tap, a lagged click on an old screen, or a replayed remote all carry an old token and are dropped without any special case. Because the token is a global counter, a token from another player's session can never match yours either.
- **Fail closed.** An unknown condition kind returns false, so a typo in a tree hides a choice rather than opening it. An unknown effect kind warns and does nothing. A condition that errors also counts as false (`pcall`).
- **Re-check on click.** Between drawing a screen and the click, another system can change state. The ore quest can complete while the player is reading. Re-checking conditions before applying effects closes a window where a choice that should have disappeared still pays.
- **The distance watchdog** ends conversations when the player walks off, dies or the NPC is removed (`anchor.Parent` becomes nil). It checks every 0.5 s, which costs nothing for the handful of open sessions a server ever has. Setting existing keys to nil while iterating with a generic `for` is allowed in Luau.
- **Effects on node entry run every time the node is shown.** That includes going "back" to a hub node. Keep node effects idempotent (setting a flag that is already set is harmless; paying coins is not). Put paying effects on choices, guarded by a flag.
- **Init order.** Games register their own effects and conditions, then call `init`. Registration after `init` asserts, because trees were already validated against the known kinds.

---

## 6. Boot script: wiring the game in

```lua
--!strict
-- ServerScriptService/DialogueBoot (Script)
local ServerScriptService = game:GetService("ServerScriptService")
local DialogueService = require(ServerScriptService:WaitForChild("Dialogue"):WaitForChild("DialogueService"))

-- Example 'give' effect: adds to a leaderstats IntValue.
-- In a real game, call your economy service here so the grant is logged and saved.
DialogueService.registerEffect("give", function(player: Player, e)
	local stats = player:FindFirstChild("leaderstats")
	local stat = if stats and e.name then stats:FindFirstChild(e.name) else nil
	if stat and stat:IsA("IntValue") then
		stat.Value += math.clamp(e.value or 0, 0, 10000) -- a sanity cap on data mistakes
	end
end)

-- Example 'startQuest' effect: hand off to your quest service.
DialogueService.registerEffect("startQuest", function(player: Player, e)
	print(`[Dialogue] would start quest {e.name} for {player.Name}`)
end)

-- Example condition reading a number attribute set by a progression system.
DialogueService.registerCondition("minLevel", function(player: Player, c): boolean
	local level = player:GetAttribute("Level")
	return typeof(level) == "number" and level >= (c.value or 0)
end)

DialogueService.init() -- pass a FlagStore backed by your profile in production
```

For persistence, implement `FlagStore` on top of the player's saved profile: `get` reads `profile.Data.Dialogue[name]`, `set` writes it and marks the profile dirty. Use a dedicated sub-table so dialogue flags cannot collide with other keys, and keep flag names stable forever, exactly like quest ids ([[Data Schema Design and Migrations]], [[Session Locking and Profile Libraries]]). Do not save the conversation position itself. Rejoining mid-conversation should start a fresh conversation from the right greeting, which the ordered start list already handles.

---

## 7. Client: DialogueController

```lua
--!strict
-- StarterPlayer/StarterPlayerScripts/DialogueController (LocalScript)
local GuiService = game:GetService("GuiService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = require(ReplicatedStorage:WaitForChild("DialogueShared"))
local remotes = ReplicatedStorage:WaitForChild(Shared.REMOTE_FOLDER)
local showRemote = remotes:WaitForChild("Show") :: RemoteEvent
local inputRemote = remotes:WaitForChild("Input") :: RemoteEvent

local player = Players.LocalPlayer
local CHARS_PER_SECOND = 45 -- rule of thumb: fast enough not to annoy, slow enough to feel spoken
local CONTINUE: Shared.TextRef = { key = "dialogue.continue", default = "Continue" }
local GOODBYE: Shared.TextRef = { key = "dialogue.end", default = "Goodbye" }

-- Translation ------------------------------------------------------------------
local translator: Translator? = nil
local current: Shared.LineView? = nil
local render: (view: Shared.LineView) -> ()

task.spawn(function()
	local ok, result = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(player)
	end)
	if ok then
		translator = result
		result:GetPropertyChangedSignal("LocaleId"):Connect(function()
			if current then
				render(current) -- scripted text does not re-translate itself
			end
		end)
	else
		warn("[Dialogue] translator unavailable, showing source text")
	end
end)

local function fillDefault(text: string, args: { [string]: string | number }): string
	-- Handles {Name} and {Name:spec}; the spec is ignored in the fallback.
	return (string.gsub(text, "{([%w_]+)[^}]*}", function(name: string): string
		local value = args[name]
		return if value ~= nil then tostring(value) else "{" .. name .. "}"
	end))
end

local function resolve(ref: Shared.TextRef, args: Shared.Args?): string
	local flat: { [string]: string | number } = {}
	if args then
		for name, value in args do
			if typeof(value) == "table" then
				flat[name] = resolve(value, nil) -- keyed sub-text, e.g. an item name
			else
				flat[name] = value :: any
			end
		end
	end
	local t = translator
	if t then
		local ok, out = pcall(function()
			return t:FormatByKey(ref.key, flat)
		end)
		if ok and type(out) == "string" then
			return out
		end
	end
	return fillDefault(ref.default, flat)
end

-- UI ---------------------------------------------------------------------------
-- Small builder: sets properties, parents last. Returns any; callers cast.
local function new(className: string, props: { [string]: any }): any
	local inst: any = Instance.new(className :: any)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local gui = new("ScreenGui", {
	Name = "Dialogue",
	ResetOnSpawn = false,
	Enabled = false,
	AutoLocalize = false, -- we translate ourselves; keep capture out of it
	Parent = player:WaitForChild("PlayerGui"),
}) :: ScreenGui

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(0.92, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(24, 28, 36),
	BackgroundTransparency = 0.1,
	Parent = gui,
}) :: Frame
new("UISizeConstraint", { MaxSize = Vector2.new(760, math.huge), Parent = panel })
new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = panel })
new("UIPadding", {
	PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
	PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
	Parent = panel,
})
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })

local speakerLabel = new("TextLabel", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
	TextSize = 20,
	TextColor3 = Color3.fromRGB(255, 214, 120),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
}) :: TextLabel

local bodyLabel = new("TextLabel", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	FontFace = Font.fromEnum(Enum.Font.BuilderSans),
	TextSize = 20,
	TextWrapped = true,
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = panel,
}) :: TextLabel

local choiceList = new("Frame", {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Parent = panel,
}) :: Frame
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = choiceList })

local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 8, 0, -8),
	Size = UDim2.fromOffset(36, 36),
	Text = "X",
	FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
	TextSize = 18,
	Parent = panel,
}) :: TextButton

-- Typewriter -------------------------------------------------------------------
-- Text is set in full once; only MaxVisibleGraphemes animates. Translation,
-- rich text and wrapping see the whole string from the first frame, so the
-- layout never jumps and partial strings are never captured.
local typing: thread? = nil

local function graphemeCount(s: string): number
	local n = 0
	for _ in utf8.graphemes(s) do
		n += 1
	end
	return n
end

local function stopTyping(): boolean
	local thread = typing
	if thread then
		typing = nil
		task.cancel(thread)
		bodyLabel.MaxVisibleGraphemes = -1
		return true
	end
	return false
end

local function typeOut()
	stopTyping()
	local total = graphemeCount(bodyLabel.ContentText)
	if GuiService.ReducedMotionEnabled or total == 0 then
		bodyLabel.MaxVisibleGraphemes = -1
		return
	end
	bodyLabel.MaxVisibleGraphemes = 0
	typing = task.spawn(function()
		local shown = 0
		while shown < total do
			shown += RunService.Heartbeat:Wait() * CHARS_PER_SECOND
			bodyLabel.MaxVisibleGraphemes = math.min(total, math.floor(shown))
		end
		bodyLabel.MaxVisibleGraphemes = -1
		typing = nil
	end)
end

-- Input ------------------------------------------------------------------------
local sentToken: number? = nil
local buttons: { TextButton } = {}

local function send(index: number)
	local view = current
	if not view or sentToken == view.token then
		return
	end
	sentToken = view.token
	inputRemote:FireServer(view.token, index)
	-- If the server dropped the input (rate limit), allow a retry.
	local token = view.token
	task.delay(1, function()
		if sentToken == token and current and current.token == token then
			sentToken = nil
		end
	end)
end

local function press(index: number)
	if stopTyping() then
		return -- first press finishes the line; the next one chooses
	end
	send(index)
end

local function clearChoices()
	for _, b in buttons do
		b:Destroy()
	end
	table.clear(buttons)
end

local function makeButton(text: string, index: number, order: number)
	local button = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextWrapped = true,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = Color3.fromRGB(44, 52, 66),
		TextColor3 = Color3.new(1, 1, 1),
		Parent = choiceList,
	}) :: TextButton
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = button })
	button.Activated:Connect(function()
		press(index)
	end)
	table.insert(buttons, button)
end

render = function(view: Shared.LineView)
	speakerLabel.Text = resolve(view.speaker, nil)
	bodyLabel.Text = resolve(view.line, view.args)
	clearChoices()
	if #view.choices == 0 then
		makeButton(resolve(if view.final then GOODBYE else CONTINUE, nil), 0, 1)
	else
		for i, choice in view.choices do
			makeButton(`{i}. {resolve(choice.text, choice.args)}`, choice.index, i)
		end
	end
	typeOut()
	if UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 and buttons[1] then
		GuiService.SelectedObject = buttons[1]
	end
end

closeButton.Activated:Connect(function()
	send(-1)
end)

local NUMBER_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	local view = current
	if not view or processed then
		return
	end
	local number = NUMBER_KEYS[input.KeyCode]
	if number and number <= #view.choices then
		press(view.choices[number].index)
	elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
		if #view.choices == 0 then
			press(0)
		else
			stopTyping()
		end
	end
end)

showRemote.OnClientEvent:Connect(function(view: Shared.LineView?, _reason: string?)
	current = view
	sentToken = nil
	if view then
		gui.Enabled = true
		ProximityPromptService.Enabled = false -- hide other prompts while talking
		render(view)
	else
		stopTyping()
		clearChoices()
		gui.Enabled = false
		ProximityPromptService.Enabled = true
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end
end)
```

### Notes on the client code

- **`MaxVisibleGraphemes`, not substring.** The common typewriter sets `label.Text = string.sub(full, 1, n)` every frame. That breaks in four ways at once: it cuts multi-byte characters in half (any accented, CJK or emoji text), it breaks rich text tags mid-tag, it makes wrapped lines reflow as words grow, and if `AutoLocalize` is on, automatic capture can record every partial string. Setting the full text once and revealing graphemes avoids all four. Grapheme counting uses `ContentText`, the text after rich text tags are removed.
- **First press finishes, second press chooses.** Players tap fast. If the first tap both finished the line and chose option 1, players would pick options they never read. This is a writing-quality issue as much as a UI one.
- **Reduced motion.** When the player has reduced motion on (`GuiService.ReducedMotionEnabled`, Roblox docs as of October 2026), the line appears at once. A typewriter is motion.
- **Hiding prompts.** `ProximityPromptService.Enabled = false` on the client hides every prompt for this player only. If another system also toggles it (a cutscene, a shop), give them a shared counter instead of each writing the property, or the last writer wins and prompts stay hidden. This is the same bug shape as the hidden HUD in [[HUD Design]].
- **Number prefixes** ("1. Got any work?") are built in code, outside the translated string, so translators never see or break them.
- **Fonts and sizes** follow [[Text Fonts and Rich Text]]. 18 to 20 px body text is the floor this note uses for phones; the reference project's UI pipeline used a 12 px absolute floor for scaled text, which is too small for reading dialogue (rule of thumb).

---

## 8. Localization: what flows where

| Piece | Where it is translated | Why |
|---|---|---|
| Line and choice text | Client, `FormatByKey(key, args)` | Player's own locale; re-renders on `LocaleId` change |
| Item names inside a line | Client, nested `TextRef` argument | The item name has its own key and translation |
| Player display name | Not translated | It is a name; inserted as a plain string |
| Numbers | Client, through the entry's format specifier (`{Count:int}`) | Locale-aware separators (Roblox docs) |
| Prompt "Talk" | Set on the server once | Check whether your prompts are captured and translated; this note could not confirm prompt capture behaviour, so test it or set `ActionText` from a client translator |
| Button numbers | Code, outside strings | Never shown to translators |

The English default in each `TextRef` must match the `Source` column of the localization table exactly. The cleanest way to guarantee that is to generate the CSV from the tree modules, as the [[Localization Pipeline]] does for item data: walk every tree, emit `Key, Source, Context` rows, and put the speaker's name and the node id into `Context` so translators know who is talking. The validator already rejects one key reused with two different English texts, which is the bug that makes a translation silently appear in the wrong place.

Per Roblox docs, `FormatByKey` accepts named arguments as a dictionary (`{ Count = 5 }`) or positional ones as an array. Use named ones for dialogue: translators can move `{Player}` to wherever their grammar needs it, and the name tells them what it is. Docs do not describe plural or gender handling for parameters (as of October 2026); [[Localization-Ready Writing]] covers how to write lines that do not need them.

---

## 9. Testing in Studio

1. **Validator first.** Start a server (Play or Run). The output should show no `[Dialogue]` warnings. Deliberately break a tree (point a choice at `"nope"`) and confirm the warning appears with the tree id and choice index.
2. **Happy path.** Talk to the NPC: intro, ask about the town, come back to the hub, accept the quest, leave. Talk again: you should get the "returning" greeting, and "Got any work?" should be gone.
3. **Turn-in.** In the command bar on the server, set the flag through your store (or temporarily add a debug effect), talk again, take the reward. Talk a third time: the turn-in greeting must not appear and no coins should be paid.
4. **Walk away.** Open a conversation and walk 20 studs away. The panel should close within half a second.
5. **Death and respawn.** Open a conversation and reset your character. The panel should close, and the prompt should work after respawn (the GUI has `ResetOnSpawn = false`, so check that prompts were re-enabled).
6. **Double input.** Click a choice many times quickly, and press 1 while clicking. Only one advance should happen per screen.
7. **Multi-client.** Start a local server with 2 or 3 players ([[Testing Modes - Play Run and Multi-Client]]) and talk to the same NPC at once on different branches. Each player's panel should be independent.
8. **Locale.** Test with a pseudo-locale or a real one through Studio's player emulator, and switch language while a line is on screen: the line should re-render in the new language.
9. **Phone and gamepad.** Emulate a phone in landscape with the longest line in the game. Two lines of body plus four choices must fit. With a gamepad, the first choice should be selected when a screen opens.
10. **Reduced motion.** Turn it on in the Roblox settings and confirm lines appear instantly.

---

## 10. Exploits it must resist

| Attack | What stops it |
|---|---|
| Fire `Input` with a choice that was never shown | Index is looked up in `session.visible`, built on the server |
| Fire `Input` for a choice whose condition is false | Conditions re-checked on click |
| Replay an old click to repeat a paying choice | Token changes every screen; paying choices set a guarding flag |
| Fire `Input` from across the map | Distance checked on input and by the watchdog |
| Spam `Input` | Token match plus a 0.15 s gap per session |
| Send NaN, huge numbers, strings or tables | Type and integer checks before use |
| Read the tree to find secret branches | Trees are in `ServerStorage`; only one screen is ever sent |
| Start dialogue remotely | Only the server-side `Triggered` handler calls `start`, and it checks range |

Rate limiting here is light because each input already needs a fresh token, and the server only issues one per screen. A general per-player limiter like the one in [[Rate Limiting and Abuse Prevention]] is still worth having on all remotes.

---

## 11. Common mistakes and extensions

### Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Tree in `ReplicatedStorage` | Spoilers and gated branches dumped by exploiters | Server-only data, one screen at a time |
| Generic greeting listed before the specific one | Turn-in text never appears | Order start entries from specific to general |
| Paying effect without a flag | Reward farmed by re-talking | Set a flag in the same choice; validator warns |
| Typewriter with `string.sub` | Broken accents and emoji, jumping layout, junk capture | Full text plus `MaxVisibleGraphemes` |
| First tap chooses | Players pick options they never read | First tap finishes the line |
| Server sends English sentences | Every player sees English | Keys plus arguments, translated on the client |
| Same key, different English in two trees | Wrong translation appears | Validator rejects it |
| Node effects that pay | Paid again each time the node is revisited | Pay on choices only |
| No distance end | Players run off with the panel open and click rewards later | Watchdog plus check on input |
| Everyone toggles prompt visibility | Prompts stay hidden after a cutscene | One owner or a counter |

### Extensions

- **Portraits and expressions.** `portrait` is already in the view. Add `expression` per node and drive a dynamic head or a portrait sheet ([[Facial Animation and Dynamic Heads]]).
- **Voice lines.** Add a `sound` key per node, localized the same way as images (an asset id per language in the table, per Roblox docs).
- **NPC turns to face the player** on start, and plays a talk animation ([[Enemy and NPC Animation]]).
- **Shared conversations.** For a group scene, make the session belong to a party instead of a player, show the same screen to everyone, and pick a rule for choices (leader decides, majority vote with a timer). See [[Genre Playbook - Horror and Story]] for group decision rules.
- **Speech bubbles for barks.** Short one-way lines over an NPC's head can use `TextChatService:DisplayBubble(part, message)`, which Roblox docs say only works from client-side scripts (as of October 2026). Use them for ambient flavour, not for anything with choices; see [[Text Chat Customization with TextChatService]].
- **Generated replies.** If you add an LLM-driven NPC, keep this system for anything that grants value, and confine generated text to flavour. The rules and filters are in [[In-Game AI - LLM NPCs and Text Generation]].
- **Writer tooling.** A spreadsheet or a node-graph tool that exports to these modules lets writers work without touching Luau ([[Data and Config Pipeline - Spreadsheets to Game]]). Keep the validator in the build so exports cannot ship broken trees.

---

## 12. Checklist

- [ ] Trees in `ServerStorage`; only `DialogueShared` replicates.
- [ ] Every line and choice is a key plus an English default; CSV generated from trees.
- [ ] Start entries ordered from specific to general.
- [ ] Every paying choice sets a guarding flag; node effects are idempotent.
- [ ] Validator runs at boot with zero warnings; it is part of the test pass.
- [ ] Server checks token, type, integer, rate, range and conditions on every input.
- [ ] Watchdog ends sessions on distance, death and NPC removal.
- [ ] Flags persisted through a profile-backed `FlagStore` with stable names.
- [ ] Typewriter uses `MaxVisibleGraphemes`, first tap finishes, reduced motion respected.
- [ ] Scripted text re-renders on `LocaleId` change.
- [ ] Phone landscape fits the longest line plus four choices; gamepad selects the first choice.
- [ ] Multi-client test on one NPC passes.

## See also

[[Narrative Start Here]] · [[Writing Dialogue for Roblox Players]] · [[Quest Writing and Hooks]] · [[Localization-Ready Writing]] · [[Quest Chain System End to End]] · [[Quests and Objectives]] · [[Localization]] · [[Localization Pipeline]] · [[Server Authority and Validation]] · [[RemoteEvents RemoteFunctions and Unreliable Remotes]] · [[Rate Limiting and Abuse Prevention]] · [[Text Fonts and Rich Text]] · [[Accessibility]] · [[Gamepad and Console UX]] · [[Luau Type System and Strict Mode]]

## Connected notes
<!-- auto-links:start -->
[[Strings Patterns and Formatting]] · [[Lore Delivery Without Walls of Text]] · [[Naming Items Zones and Abilities]] · [[Notification and Toast Systems]] · [[Captions and Audio Accessibility]] · [[Links - NPCs and AI]]
<!-- auto-links:end -->
