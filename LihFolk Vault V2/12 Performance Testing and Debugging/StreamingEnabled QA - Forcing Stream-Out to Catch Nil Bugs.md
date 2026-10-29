---
tags: [testing, qa, streaming, client, nil-bugs, networking, type/guide, area/testing, area/networking, level/intermediate, area/performance, api/StreamingEnabled]
---
# StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: QA in Studio with `LowMemory` on a powerful PC, so nothing ever streams out.
> - Avoid: Turning streaming off to make bugs go away (Instance Streaming explains why that crashes phones on large maps).
> - Avoid: Fixing nil errors with longer `WaitForChild` timeouts instead of tag-based setup.
> - QA place or project config with `Opportunistic` and a reduced target radius.
> - Each interactable used, left, returned to and used again.
> - Far spawn, internal teleports and respawn tested.
>
> Cost: TL;DR ~160 tok · whole note ~2.0k tok. Read more: ## 1. A streaming QA configuration · ## 3. Simulating stream-out locally (fast, scriptable) · ## Common mistakes · ## Checklist
<!-- tldr:end -->

With instance streaming on, a client only has the parts of Workspace near it, and parts can disappear and come back. Most streaming bugs are client scripts that assumed a part exists: `attempt to index nil`, a proximity prompt that works only on the second visit, an effect that keeps a dead reference forever. They rarely appear in Studio because a developer's PC has plenty of memory, and with the default `StreamOutBehavior` of `LowMemory` parts beyond the minimum radius only stream out under memory pressure (Roblox docs, see [[Instance Streaming]]). So the bugs ship and appear on phones.

This note is about making stream-out happen on purpose during testing. How streaming works and how to write streaming-safe code is in [[Instance Streaming]]; read that first.

Labels as marked. Streaming properties are **not scriptable** (Roblox docs): you set them in the Properties panel, so the QA setup is a place configuration, not a script.

---

## 1. A streaming QA configuration

Keep a QA copy of the place (or a QA branch of your Rojo project file) with streaming set to be aggressive:

| Property | QA value | Why |
|---|---|---|
| `StreamOutBehavior` | `Opportunistic` | Regions beyond the target radius may be removed at any time, not only under memory pressure (Roblox docs) |
| `StreamingTargetRadius` | Lower than live (for example a few hundred studs) | Things stream out after a short walk instead of a long trip. Keep it above `StreamingMinRadius` (Roblox docs require target > min) |
| `StreamingMinRadius` | Default 64 | Leave it |
| `StreamingIntegrityMode` | Same as live | You want to see the pause behaviour players get |
| `ModelStreamingBehavior` | Same as live (`Improved` recommended by docs) | Model behaviour differs between Legacy and Improved |

**Unverified:** the minimum allowed value for `StreamingTargetRadius`; Studio will refuse values it does not accept. **Rule of thumb:** a QA radius around a quarter of live finds most bugs without making the map unplayable.

Live servers can also use `Opportunistic` (the docs recommend it); if yours does, QA with the same value plus the smaller radius.

---

## 2. Routes that force stream-out and stream-in

Walk or teleport through these with the Network Stats streaming view open (Shift+Ctrl+F3 in a Studio playtest, then Shift+1 to the streaming panel, per [[Instance Streaming]]):

1. **Go far, come back.** Teleport the character far from spawn, wait a few seconds, return. Every interactable near spawn has now streamed out and in once.
2. **Interact, leave, return, interact.** Use each prompt, door, shop and NPC; leave its area; return; use it again. The "works once" bug lives here.
3. **Join far away.** Spawn testers at a far spawn so the client starts without the hub. Scripts that index the hub at startup break.
4. **Teleport inside the place.** Use your teleport feature (pads, fast travel, respawn at checkpoint). The destination should be requested first with `Player:RequestStreamAroundAsync` on the server (Roblox docs).
5. **Watch something remote.** UI that tracks a far object (boss health, a minimap marker, a quest arrow) while you are out of range.
6. **Die and respawn.** The respawn location may not be streamed yet.

For each step watch the Output for errors and check the feature still works.

---

## 3. Simulating stream-out locally (fast, scriptable)

You can also stress client code without moving the character by **removing replicated instances on the client only**. Destroying a server-replicated part from a LocalScript removes it for that client, which is close to what a stream-out looks like to client code (the instance leaves the data model; tag-removed and `AncestryChanged` fire). It is not identical: a real stream-in brings a new instance, and Atomic models arrive whole. **Rule of thumb:** use it to find code that holds stale references or assumes existence; confirm fixes with real streaming.

```lua
--!strict
-- StarterPlayerScripts/QA/StreamChaos (client, QA builds only)
-- Randomly removes tagged client-side copies of streamable models to shake out nil bugs.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return -- never ship chaos to players
end

local TAG = "Streamable" -- tag the models your client code interacts with
local INTERVAL = 4

while true do
	task.wait(INTERVAL)
	local list = CollectionService:GetTagged(TAG)
	if #list > 0 then
		local victim = list[math.random(1, #list)]
		print("[StreamChaos] removing", victim:GetFullName())
		victim:Destroy() -- local only; the server copy is untouched
	end
end
```

Run a normal play session with this on. Any error mentioning a destroyed instance, any effect stuck on screen and any connection that keeps firing points at code that is not streaming-safe. Restarting the test brings everything back.

---

## 4. Static checks before the playtest

Cheap and catches most of it:

- Grep client code for direct Workspace indexing: `workspace.`, `Workspace:FindFirstChild(` chains, `game.Workspace.` followed by names. Each hit needs `WaitForChild` with a timeout, a tag-based pattern or an explanation ([[Instance Streaming]], section "Writing streaming-safe client code").
- Grep for `GetTagged(` used once at startup without a matching `GetInstanceAddedSignal` and `GetInstanceRemovedSignal`.
- The LihFolk checker flags `FindFirstChild` chains that are indexed immediately (`findfirstchild-chain`, info level; see [[Automated Luau Checks - LihFolk Hook and Audit]]). In client code under streaming those deserve a closer look.
- Server code is unaffected by streaming (the server has everything); do not "fix" server scripts.

---

## 5. Patterns that pass

The pass criteria are the streaming-safe patterns from [[Instance Streaming]]:

- Interactables set up through `CollectionService` added and removed signals, so they work for every stream-in.
- Per-instance connections cleaned on removal (Maid, Janitor or Trove, or a table keyed by instance).
- Models the client manipulates as a unit set to `Atomic`; `Persistent` only for tiny essentials.
- Remote messages that reference instances handle `nil` on the client (the server may send a reference to a part the client does not have).

---

## Common mistakes

- QA in Studio with `LowMemory` on a powerful PC, so nothing ever streams out.
- Turning streaming off to make bugs go away ([[Instance Streaming]] explains why that crashes phones on large maps).
- Fixing nil errors with longer `WaitForChild` timeouts instead of tag-based setup.
- Chaos scripts left in a build that ships.
- Testing only the spawn area.

## Checklist

- [ ] QA place or project config with `Opportunistic` and a reduced target radius.
- [ ] Each interactable used, left, returned to and used again.
- [ ] Far spawn, internal teleports and respawn tested.
- [ ] StreamChaos session run with zero errors.
- [ ] Static grep of client Workspace indexing done.
- [ ] Final pass on a real low-memory phone.

## See also

- [[Instance Streaming]], [[Level of Detail and Model Streaming]], [[Debugging Client-Server Desync]]
- [[Mobile and Low-End Optimization]], [[Multi-Client and Device Playtesting Protocols]]
- [[Genre QA Passes - Test Checklists per Game Type]]

## Connected notes

[[Automated Luau Checks - LihFolk Hook and Audit]] · [[Testing Modes - Play Run and Multi-Client]] · [[Memory Budgets and Leaks]]

<!-- related:start -->
## Related
[[Streaming Radius]] · [[Case Study - Fast Join and Deferred Loading]] · [[Client Zone Culling for Interiors and Cities]] · [[Network Performance]] · [[Multi-Client and Live Testing]] · [[Hunting Memory Leaks Step by Step]] · [[Gated Tester Commands and Debug Panels]] · [[Testing Time-Based Features with a Controllable Clock]] · [[Load and Soak Testing Servers - Long Sessions and Many Clients]]
<!-- related:end -->
