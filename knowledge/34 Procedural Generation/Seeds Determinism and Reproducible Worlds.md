---
tags: [procedural, generation, seeds, determinism, random, hashing, testing, luau]
---
# Seeds Determinism and Reproducible Worlds

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Linear sub-seed formula -> Hash-combine coordinates
> - Avoid: One `Random` for everything -> Purpose-named streams
> - Avoid: Draw order depends on dictionary iteration -> Sort keys
> - Every stochastic decision names its purpose and its coordinates.
> - Coordinates are hash-combined, not added.
> - `Random` streams are bounded to one job and seeded from a hash.
>
> Read more (20 KB note): ## The Hash module · ## Versioning generators · ## Common mistakes · ## Checklist
<!-- tldr:end -->

[[Procedural World Generation]] gives the first rule of procedural work: use `Random.new(seed)`, one generator per purpose, and derive chunk seeds from coordinates. That rule gets you started. This note is about everything that breaks once a generator is real: seeds that collide, output that changes when you add one feature, dictionaries that iterate in a different order, floats that disagree between machines, saved worlds that no longer match after an update, and seeds that leak loot to exploiters. Every other note in this section builds on the small `Hash` module written here.

## What "deterministic" has to mean

A generator is deterministic when the same inputs always give the same output. The trap is the word "inputs". In practice a generator silently reads far more than its seed:

| Hidden input | How it leaks in | Symptom |
|---|---|---|
| Call order of a shared generator | One `Random` used for terrain and props | Adding a prop type reshapes mountains |
| Generation order | Chunks generated in the order players walk | The same chunk looks different on two servers |
| Table iteration order | `for k, v in dict` | Rare, unreproducible differences |
| Instance order | `GetChildren()`, `GetDescendants()`, `GetTagged()` | Prefab picks change after an unrelated edit in Studio |
| Time | `os.clock()`, `tick()`, frame-budget loops that branch on time | Output depends on server load |
| Engine version | Changes in `Random` or `math.noise` internals | Old saved seeds give new worlds (unverified risk, see below) |
| Floating point | Different CPUs or compiler paths | Thresholds that flip on a 0.0000001 difference |
| Tunable data | Weight tables, tile sets, item catalogues | Old seeds give new results after a balance patch |

The fix in every row is the same idea: **make the hidden input explicit or remove it.** The rest of this note is how.

## Order independence: counter-based randomness

A sequential generator (`Random`) produces a stream: the tenth number depends on the nine before it. That is fine inside one small, self-contained job (one room, one item). It is wrong for anything a player can reach in more than one order, because the order of work becomes an input.

The cure is a **counter-based** generator: a hash function that turns `(seed, x, y, z, purpose)` directly into a random number, with no state. Chunk (12, -3) asks for its tree density, and gets the same answer whether it is generated first or ten-thousandth, on the server or a client, today or after a restart.

### Why linear sub-seeds are not enough

The common recipe `seed + cx * 73856093 + cz * 19349663` is order-independent, but it is **linear**, and linear mixes collide in structured ways:

- World seed `s`, chunk (1, 0) gives the same sub-seed as world seed `s + 73856093`, chunk (0, 0). Two "different" worlds share content, shifted by one chunk.
- Many pairs `(cx, cz)` produce the same sum, and nearby seeds produce nearby sub-seeds. `Random.new` scrambles its seed internally, so this is usually invisible, but if you then feed the sub-seed into `math.noise` as an offset (very common), neighbouring chunks get correlated noise.
- Large coordinates times large primes pass 2^53 and lose integer precision, so far chunks can collapse onto the same seed.

A proper integer hash (avalanche: flipping one input bit flips about half the output bits) removes all three problems for a few extra operations.

## The Hash module

Luau numbers are doubles, which hold integers exactly up to 2^53. A 32-bit multiply of two 32-bit values can reach 2^64, so you cannot just write `a * b % 2^32`: the low bits are already lost. `mul32` splits one operand into 16-bit halves so every intermediate stays under 2^49.

```lua
--!strict
-- Hash: stateless, order-independent randomness for procedural generation.
-- Everything is exact integer arithmetic on doubles (< 2^53), so results do not
-- depend on CPU or platform.
local Hash = {}

local TWO32 = 4294967296

-- (a * b) mod 2^32 for 0 <= a, b < 2^32, without losing precision.
local function mul32(a: number, b: number): number
	local lo = b % 65536
	local hi = (b - lo) / 65536
	return (a * lo + ((a * hi) % 65536) * 65536) % TWO32
end
Hash.mul32 = mul32

-- MurmurHash3 finaliser: strong avalanche on a 32-bit value.
local function fmix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end
Hash.fmix = fmix

-- Fold any integer (negative too) into 0..2^32-1. Lua's % is floored, so -1 -> 2^32-1.
local function u32(n: number): number
	return math.floor(n) % TWO32
end

-- Combine a seed with up to four integer coordinates into one 32-bit hash.
function Hash.hash(seed: number, a: number?, b: number?, c: number?, d: number?): number
	local h = fmix(u32(seed))
	if a then h = fmix(bit32.bxor(h, u32(a)) ) end
	if b then h = fmix(bit32.bxor(mul32(h, 31), u32(b))) end
	if c then h = fmix(bit32.bxor(mul32(h, 37), u32(c))) end
	if d then h = fmix(bit32.bxor(mul32(h, 41), u32(d))) end
	return h
end

-- Uniform float in [0, 1) from the same inputs.
function Hash.float(seed: number, a: number?, b: number?, c: number?, d: number?): number
	return Hash.hash(seed, a, b, c, d) / TWO32
end

-- FNV-1a over a string: turns "purpose" names and player-typed seeds into numbers.
function Hash.string(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = mul32(bit32.bxor(h, string.byte(s, i)), 16777619)
	end
	return h
end

-- A Random seeded for one purpose at one place. Use for small sequential jobs
-- (fill one chunk, roll one item) where a stream is convenient.
function Hash.rng(seed: number, purpose: string, a: number?, b: number?, c: number?): Random
	return Random.new(Hash.hash(bit32.bxor(u32(seed), Hash.string(purpose)), a, b, c))
end

return Hash
```

Usage patterns:

```lua
local worldSeed = 1234567
-- Stateless: same answer in any order.
local treeChance = Hash.float(worldSeed, cx, cz, Hash.string("trees"))
-- Small sequential job: one stream per chunk per purpose.
local propRng = Hash.rng(worldSeed, "props", cx, cz)
```

The `purpose` string is what keeps systems independent. Terrain, props, ore and enemies each get their own namespace, so adding a fifth system cannot shift the first four. Hash the purpose names once at module load if you call this in a hot loop.

## Sequential streams done safely

`Random` is still the right tool inside a bounded job. Rules that keep it deterministic:

1. **Create it at the start of the job from a hash, never share it across jobs.** A dungeon floor gets `Hash.rng(runSeed, "floor", floorIndex)`. Rooms on that floor may draw from it only if the order of rooms is itself fixed by the algorithm, not by timing.
2. **Fork, do not share.** When a job spawns sub-jobs, derive each child's seed up front: `local childSeed = rng:NextInteger(0, 2^31 - 1)` for each child, in a fixed order, before any child runs. Now children can run in any order, in parallel, or be regenerated alone.
3. **Burn a fixed count.** If a branch sometimes draws two numbers and sometimes three, every later draw shifts. When a design change adds a draw, it changes everything downstream. Either accept that (bump the generator version, see below) or give the new feature its own stream.
4. **`Random:Clone()`** (Roblox docs lists it) copies the generator's current state. It is handy for "try this, and if it fails, rewind" in backtracking generators.

`Random.new` takes a number seed. The docs page lists signatures without describing seed handling, so treat fractional or very large seeds as unverified: pass integers in 0 to 2^32 - 1 and you avoid the question.

## Iteration order and other quiet inputs

**Dictionaries.** Luau does not promise an iteration order for the hash part of a table. In practice the order is often stable for the same insertion sequence, which is why the bug hides. Any time a generator loops over a dictionary and draws random numbers inside the loop, the draws are assigned to keys in an order you do not control. Sort the keys first:

```lua
local function sortedKeys<K>(t: { [K]: any }): { K }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys :: any)
	return keys
end
```

Arrays iterated with `ipairs` or `for i = 1, #t` are ordered and safe.

**Instances.** `Folder:GetChildren()` returns children in an engine order that changes when someone reparents or renames things in Studio. If prefabs are picked by index into `GetChildren()`, a decorator moving one model reshuffles every future dungeon. Pick from a **sorted list of names** (or an explicit array in a config module), and give each prefab a stable `Id` attribute.

**Time and budget.** Frame-budgeted generators (stop after 4 ms, continue next frame) are fine as long as the **work list** is fixed and the budget only decides when to pause. Bugs appear when the budget decides what to generate ("if we are out of time, skip decoration"). That makes slow servers produce different worlds.

**`math.random`.** Shared per Luau VM, reseeded by the engine, and called by any script or library. Never in a generator.

## Floating point: where determinism quietly ends

Integer arithmetic on doubles below 2^53 is exact everywhere. Floating point arithmetic is deterministic for the same operations in the same order on IEEE-754 hardware, but transcendental functions (`math.sin`, `math.exp`, `math.noise`) can differ in the last bits between implementations. Roblox does not document that `math.noise` returns bit-identical results on every client platform and the server; treat it as **unverified**. Design so it does not matter:

- **Keep the authoritative copy in one place.** If collision, enemies and loot depend on the result, generate on the server and replicate, or have the server generate and let clients generate only cosmetics.
- **Quantize before you branch.** `if n > 0.3` flips when `n` is 0.2999999 on one machine and 0.3000001 on another. Quantize noise to a grid of, say, 1/1024 before thresholding, so tiny differences round the same way in all but rare cases.
- **Integer decisions from hashes.** Where a client and server must agree exactly (which chunk has a chest, which tile is solid), decide with `Hash.hash`, which is exact integer math, not with noise thresholds.

## Versioning generators

A seed means nothing without the code and data that interpret it. When you save a world as "seed 1234567", you are really saving "seed 1234567, as interpreted by generator v7 with biome table v3". Change either and the same seed builds a different world.

That matters in three situations:

| Situation | What breaks | Approach |
|---|---|---|
| Per-player saved worlds (player islands, bases) | Their terrain shifts under their buildings after an update | Save `{seed, genVersion}`; keep old generator versions callable, or bake the terrain once and save the result |
| Shareable seeds ("try seed 4242") | Players' shared seeds stop matching | Show the version with the seed; accept breakage across major versions |
| Daily or weekly challenges | Mid-day patch changes today's map | Freeze generator data for the day; deploy changes at rollover |

Old generator versions are cheap to keep if the generator is pure (seed and config in, description out). They are expensive if generation is entangled with live gameplay code. That is one more reason to split **generate a description** (a plain Luau table: tiles, rooms, item stats) from **build instances** from that description.

The engine itself is a dependency too. Roblox does not document a guarantee that `Random`'s sequence for a given seed will never change across engine updates (unverified). For anything you must regenerate identically months later, either store the generated result, or use your own generator built from `Hash` (pure integer math you control):

```lua
--!strict
-- A tiny counter-based stream built on Hash: stable forever because you own it.
local Hash = require(script.Parent.Hash)

local Stream = {}
Stream.__index = Stream

export type Stream = typeof(setmetatable({} :: { seed: number, n: number }, Stream))

function Stream.new(seed: number): Stream
	return setmetatable({ seed = seed, n = 0 }, Stream)
end

function Stream.nextFloat(self: Stream): number
	self.n += 1
	return Hash.float(self.seed, self.n)
end

function Stream.nextInt(self: Stream, lo: number, hi: number): number
	return lo + math.floor(self:nextFloat() * (hi - lo + 1))
end

return Stream
```

It is slower than `Random` (a few hash rounds per number), so use it where stability matters, not for every particle.

## Seeds and security

Seeds are information. If a client can compute what a seed produces, so can an exploiter.

- **World layout from a shared seed is fine.** Players can already see the world; predicting it slightly early gives little advantage. Even then, hide secrets (a hidden room's treasure) behind server-side state, not just behind "the client does not know the seed".
- **Loot, crits, drops and gacha rolls must never be predictable.** If item rolls come from `Hash.rng(worldSeed, "loot", chestId)` and the world seed is replicated, an exploiter knows every chest's contents before opening it and knows which to skip. Use a server-only secret for loot: `Random.new()` with no seed (engine entropy), or a server secret mixed into the hash and never replicated.
- **Daily seeds are public by nature.** "The day number" is guessable. For a daily dungeon that is intended (everyone gets the same map), but the daily reward roll still uses a private generator.
- **Client-side generation trusts nothing.** If clients generate terrain for visuals, the server must still validate positions against its own model of the world. See [[Server Authority and Validation]].

## Distributing a seed to every server

Some games want a world shared across servers (a weekly map, a global event layout).

- **Derive it.** `Hash.hash(Hash.string("weekly-map"), weekNumber)` with `weekNumber` from UTC time (`DateTime.now().UnixTimestamp // 604800`). Every server computes the same seed with no messaging. Mind the boundary: servers started just before rollover keep the old seed unless they recheck.
- **Publish it.** For a seed chosen by a person (a curated layout), store it in a DataStore or live config and read it on server start ([[Global State and Live Config]]).
- **Teleport it.** For a party entering a private run, generate the seed in the lobby and pass it in teleport data, so the run server and any reconnecting player agree ([[Teleporting and Multi-Place Games]]). Validate it on arrival: teleport data comes from the client side of the teleport and should be treated as a hint, with the authoritative copy in MemoryStore or a DataStore keyed by the reserved server ([[MemoryStore Service]]).

## Testing for determinism

Determinism is a property you can test automatically, and you should, because it regresses silently.

**Golden hashes.** Generate a description for a handful of fixed seeds and hash it. Store the hashes in the test. If someone changes the generator without bumping its version, the test fails and tells them.

```lua
--!strict
-- Hash a generated description (a plain table) into one number, in a stable order.
local Hash = require(script.Parent.Hash)

local function digest(value: any, h: number?): number
	local acc = h or 2166136261
	local t = typeof(value)
	if t == "number" then
		-- Quantize so float noise below 1e-6 does not fail the test.
		return Hash.fmix(bit32.bxor(acc, math.floor(value * 1e6) % 4294967296))
	elseif t == "string" or t == "boolean" then
		return Hash.fmix(bit32.bxor(acc, Hash.string(tostring(value))))
	elseif t == "table" then
		local keys = {}
		for k in value do
			table.insert(keys, tostring(k))
		end
		table.sort(keys)
		for _, k in keys do
			acc = digest(k, acc)
			local v = value[k]
			if v == nil then
				v = value[tonumber(k)]
			end
			acc = digest(v, acc)
		end
		return acc
	end
	return acc
end

return digest
```

**Order tests.** Generate chunks A, B, C in order and in reverse; compare digests per chunk. Any difference means hidden state.

**Regenerate tests.** Generate chunk A, then generate 500 other chunks, then regenerate A. Compare.

**Cross-boundary tests.** For seams (chunk edges, room joins), sample the shared edge from both sides and compare values exactly.

Run these in your test framework ([[Automated Testing with TestEZ and Jest-Lua]]) and in CI if you have it ([[Code Pipeline - Rojo Git and CI]]).

## Debugging a non-deterministic generator

When two runs of the "same" seed differ:

1. **Find the first difference.** Log a digest after each stage (heights, biomes, features, props). The first stage whose digest differs contains the leak.
2. **Inside that stage, log draws.** Wrap your `Random` so every call logs `(purpose, callIndex, value)` for a small region. Diff the logs. The first divergent call tells you where an extra or missing draw happened.
3. **Check the usual suspects** in this order: a shared `Random`, dictionary iteration, `GetChildren()` picks, time-based branches, `math.random` in a library, float thresholds.

The general method is in [[The Debugging Method - Reproduce Isolate Bisect]].

## When not to bother

- **Throwaway randomness.** A one-off particle burst or idle animation offset can use `math.random`.
- **Hand-tuned edit-time builds.** If a generator runs once in Studio and the result is saved and hand-edited, perfect reproducibility matters less than tagging and safe regeneration (see [[Procedural World Generation]]).
- **Rolls that should be unpredictable.** Loot, crits and gacha want fresh entropy, not seeds.

## Common mistakes

| Mistake | How to spot it | Fix |
|---|---|---|
| Linear sub-seed formula | Two seeds share content shifted by a chunk | Hash-combine coordinates |
| One `Random` for everything | Adding a feature reshapes unrelated content | Purpose-named streams |
| Draw order depends on dictionary iteration | Rare, unreproducible differences | Sort keys |
| Prefab chosen by `GetChildren()` index | Layout changes after a Studio tidy-up | Sorted names or explicit list |
| Budget decides what to generate | Busy servers make different worlds | Fixed work list; budget only pauses |
| Seed saved without generator version | Saved worlds shift after updates | Save `{seed, genVersion}` |
| Loot derived from a replicated seed | Exploiters skip bad chests | Server-only entropy for rewards |
| Thresholding raw noise for shared decisions | Client and server disagree on rare cells | Quantize, or decide with integer hashes |

## Checklist

- [ ] Every stochastic decision names its purpose and its coordinates.
- [ ] Coordinates are hash-combined, not added.
- [ ] `Random` streams are bounded to one job and seeded from a hash.
- [ ] No dictionary iteration or `GetChildren()` order feeds a random draw.
- [ ] Generation is split into "describe" (pure) and "build" (instances).
- [ ] Saved worlds store seed plus generator version.
- [ ] Rewards use server-only entropy.
- [ ] Golden-hash, order and regenerate tests exist and run.

## See also

- [[Procedural Generation Start Here]], [[Procedural World Generation]]
- [[Noise Functions and Terrain Generation]], [[Infinite and Streamed Worlds]], [[Procedural Loot and Item Generation]]
- [[RNG Drops and Luck Systems]], [[Buffers and Binary Data]], [[Data Schema Design and Migrations]]
- [[Testing Strategies and Frameworks]], [[Debugging Race Conditions and Yield Order]]

## Connected notes
<!-- auto-links:start -->
[[Deterministic Simulation]] · [[Dungeon and Room Generation]] · [[Wave Function Collapse on Roblox]] · [[Math Vectors and CFrames]] · [[Variance]] · [[2D Multiplayer - Server Authority and Replicating GUI Worlds]]
<!-- auto-links:end -->
