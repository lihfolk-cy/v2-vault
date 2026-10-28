---
tags: [ai, generative, mesh, cube, generationservice, 3d]
---
# Roblox Generative AI - Cube Mesh and Texture Generation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Placing a generated mesh at whatever size it arrived.
> - Avoid: Firing many generation jobs in parallel and reading "Too Many Requests" as a bug.
> - Avoid: Using anatomy words in prompts for a stylised or horror set and wondering why everything fails.
> - Raw size and proportions checked after every generation.
> - Jobs queued, a few at a time.
> - Collision and render fidelity set; triangles within budget.
>
> Cost: TL;DR ~150 tok · whole note ~4.1k tok. Read more: ## 2. The Studio-side tools · ## 3. `GenerationService`: generation at runtime · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Roblox runs its own generative 3D system, called Cube. In Studio it shows up as mesh generation, procedural models, mesh segmentation and the Texture Generator. At runtime it shows up as `GenerationService`, which lets your servers (and so your players) generate objects during play. This note covers what each piece produces, what it is good for, the limits that are published, and the failure modes seen in production. For material and texture generation in depth see [[AI Material and Texture Generation]]; for 3D generators outside Roblox see [[AI 3D Model Generation Outside Roblox]].

Status: as of October 2026, verified against the Roblox Creator Hub (Assistant guide, Texture Generator, model generation guide, `GenerationService` reference, "Accelerated workflows" AI overview) and Roblox's March 2025 newsroom post "Introducing Roblox Cube". Several of these features are labelled beta or "early preview". Limits change.

---

## 1. Cube in one paragraph

Roblox announced Cube in March 2025 as its "core generative AI system for 3D and 4D". The first release was Cube 3D, a model that generates 3D objects from text, with a beta mesh generation API exposed through Assistant ("/generate a motorcycle" style prompts). Roblox also released a version of Cube 3D as open source on GitHub and Hugging Face, so others can run or fine-tune it. "4D" in Roblox's wording means objects that are also functional (they move or behave), which is what the later procedural and schema-based model generation does: a generated car is split into a body and four wheels so driving scripts can spin the wheels.

You do not need to run the open-source model to use any of this in Studio. It matters if you want to experiment offline or understand why the output looks the way it does: it is a learned model of shapes, not a modeller, so it produces plausible surfaces without the topology a human would build.

---

## 2. The Studio-side tools

| Tool | How to reach it | Input | Output | Published limits |
|---|---|---|---|---|
| Mesh generation | Assistant `/generate_mesh`, Studio MCP `generate_mesh` | Text prompt or one image (not both) | A textured MeshPart | Default max 10,000 triangles (you can set lower) |
| Procedural models | Assistant `/generate_procedural_model`, MCP `generate_procedural_model` + `wait_job_finished` | Text prompt | A model of primitive parts that adjusts to attributes you define, in a `GeneratedFolder` | 50 per rolling 24 hours |
| Mesh segmentation | Assistant `/segment_mesh` on a selected MeshPart ("early preview") | Up to 5 part names per run | The mesh split into named parts | Up to 8 parts per generated model |
| Texture Generator | Model tab > Texture, Assistant `/generate_texture`, MCP | Selected mesh plus text or image prompt | Fast: 1K diffuse via texture id. Quality: 4K PBR via `SurfaceAppearance` | Fast under 30 s; Quality "a couple of minutes" |
| Avatar Auto-Setup | Studio (avatar tools) | A 3D model | Rigged, caged, segmented avatar body | See [[UGC Avatar Items and Accessories]] |

### Mesh generation: what you actually get

- A single MeshPart with a baked colour texture.
- Triangle count up to the cap you set (default 10,000). Lower caps give a more faceted, low-poly result.
- A shape whose overall proportions come from the model's idea of the object, not from your requested dimensions.

**Measured in the reference project:** `generate_mesh` ignored requested size and proportions. Generated set pieces (a train car, a sarcophagus, an apse, a tree stump) came out with unexpected aspect ratios and had to be measured and re-scaled. Always read the raw size of the result before placing it:

```lua
-- Normalise a generated mesh to a target height, keeping its proportions.
local function fitToHeight(part: MeshPart, targetHeight: number)
	local size = part.Size
	if size.Y <= 0 then
		return
	end
	local k = targetHeight / size.Y
	part.Size = size * k
	print(("generated raw size %s -> scaled by %.3f to %s"):format(tostring(size), k, tostring(part.Size)))
end
```

Check the proportions too: if the ratio of width to height is wrong for the object, rescaling uniformly will not fix it, and non-uniform scaling distorts the baked texture.

**Also measured:** prompts naming body parts such as "skeleton", "ribcage", "teeth" or "throat" failed moderation, even for a stylised dungeon set. Many parallel jobs returned "Too Many Requests". Queue generation jobs and run a few at a time.

### Procedural models

Procedural models are built from primitive parts rather than a single mesh, and can respond to attributes (for example a shelf whose number of boards follows an attribute). They are easier to edit after generation than a mesh, because every piece is a normal part you can recolour, resize or delete. The cost is the part count: a procedural model can carry many parts, which matters for draw calls and physics if you spray them across a map ([[Art Budgets - Triangles Draw Calls Memory]]).

### Segmentation

Segmentation splits a generated or imported mesh into separately named parts (say "lid" and "body" of a chest). It is how you get something that can animate or be partly destroyed. Each run accepts up to five names; run it again for more, up to eight parts per generated model. Because it is "early preview", check every split visually: the cut lines are a guess.

---

## 3. `GenerationService`: generation at runtime

`GenerationService` lets server code generate objects during play. As of October 2026 the class reference lists four methods:

| Method | Status | What it does |
|---|---|---|
| `GenerateMeshAsync(inputs, player, options, intermediateResultCallback?)` | Deprecated | The original runtime mesh API. Do not build on it |
| `GenerateModelAsync(inputs, schema, options?)` | Current; yields; needs the DynamicGeneration capability | Generates a model from inputs (text prompt, optional image) split according to a schema |
| `LoadGeneratedMeshAsync(generationId)` | Current; yields | Returns a `MeshPart` for a generation id |
| `SegmentMeshAsync(meshPart, schema, options?)` | Current; yields | Splits a MeshPart by a schema |

### Schemas

From the model generation guide and reference:
- `PredefinedSchema = "Car5"`: a vehicle as five parts (a body and four wheels), found by names such as "body" and "front left wheel".
- `PredefinedSchema = "Body1"`: a single MeshPart.
- `SchemaDefinition = { Groups = { ... } }`: your own list of part names; the result is organised to match.

The guide says the output has higher fidelity and fewer artifacts than the older API, lower latency, optional bounding boxes to suggest size and proportions, and an optional maximum triangle count. It does not publish the exact option keys for those; check the reference page before using them rather than guessing key names.

Behaviour is not generated. The guide's car example loads separate "retargetable" behaviour scripts that adapt driving to whatever car came out (wheel radius, wheelbase). Plan for that: the AI makes the shape, your code makes it work.

**Replication:** the guide states that any object generated in-game is replicated and visible to all players. That has moderation and design consequences (section 4).

### A server-side pattern

This follows the shape of the official examples (prompt plus predefined schema, `pcall`, scale, anchor, parent). It adds the things a real game needs: a per-player cooldown, a length cap on the prompt, and filtering of the prompt before you store or display it.

```lua
--!strict
-- ServerScriptService/GenerateProp.server.luau
local GenerationService = game:GetService("GenerationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local request = ReplicatedStorage.Remotes.GeneratePropRequest :: RemoteEvent

local COOLDOWN = 30 -- seconds per player (rule of thumb; tune for cost and abuse)
local MAX_PROMPT = 120 -- characters
local TARGET_SIZE = 8 -- studs, longest side

local lastUse: { [number]: number } = {}

local function fitModel(model: Model, longest: number)
	local size = model:GetExtentsSize()
	local current = math.max(size.X, size.Y, size.Z)
	if current > 0 then
		model:ScaleTo(model:GetScale() * (longest / current))
	end
end

request.OnServerEvent:Connect(function(player: Player, prompt: unknown, spawnAt: unknown)
	if typeof(prompt) ~= "string" or typeof(spawnAt) ~= "Vector3" then
		return
	end
	local now = os.clock()
	if (lastUse[player.UserId] or 0) + COOLDOWN > now then
		return
	end
	lastUse[player.UserId] = now

	local text = string.sub(prompt :: string, 1, MAX_PROMPT)

	-- Filter the prompt as player text before it is used or shown anywhere.
	local okFilter, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not okFilter or filtered ~= text then
		return -- filtered text changed (hashes) or the call failed: refuse rather than generate from it
	end

	-- Also validate the spawn point server-side (distance from the player, inside the build zone, etc.).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or ((spawnAt :: Vector3) - root.Position).Magnitude > 40 then
		return
	end

	local ok, model, metadata = pcall(function()
		return GenerationService:GenerateModelAsync({ TextPrompt = text }, { PredefinedSchema = "Body1" })
	end)
	if not ok or typeof(model) ~= "Instance" or not (model :: Instance):IsA("Model") then
		warn("generation failed", model)
		return
	end
	local m = model :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	fitModel(m, TARGET_SIZE)
	m:PivotTo(CFrame.new(spawnAt :: Vector3))
	m.Parent = workspace
	_ = metadata
end)

game:GetService("Players").PlayerRemoving:Connect(function(p)
	lastUse[p.UserId] = nil
end)
```

Notes on the code:
- The filter step is belt and braces. Roblox states that inputs and outputs of its generation APIs are moderated. Filtering the prompt yourself still matters if you store, log or display it ([[In-Game AI - LLM NPCs and Text Generation]]).
- The return of `GenerateModelAsync` is a tuple of the model and metadata, as in the official examples; the content of the metadata is not documented in detail, so the code does not depend on it.
- Generation takes seconds. Show the player a "generating..." state and do not block other gameplay on it.

---

## 4. Design and policy consequences of runtime generation

From the Roblox "Games with Generative AI" page (October 2026):
- If players can trigger AI responses, including **3D generations**, you must disclose it in the Content Maturity questionnaire.
- Inputs and outputs of Roblox's own generation APIs are moderated; violating content is not shown, and players are not penalised for violating output produced from non-violating input.
- Roblox-served models target an All Ages rating and avoid content needing a descriptor; experiences rated Mild Violence or higher may generate otherwise compliant weapons.

Design consequences:
- **Everyone sees it.** Generated objects replicate. A troll who finds a prompt that passes moderation but is still offensive in context (a shape arranged as a symbol, a "joke" object in a serious game) shows it to the whole server. Add reporting, per-player limits and a way for the server owner or moderators to remove objects.
- **Cost of a failure.** Generation can fail or be slow. The game loop must not depend on it: a racing game where your car is generated needs a default car.
- **Physics and performance.** A generated mesh's collision fidelity and triangle count are unknown in advance. Set collision to a box hull for gameplay ([[Collision and Physics Geometry]]) and cap the number of live generated objects per server.
- **Persistence.** If players expect to keep what they generated, you need to store something you can recreate. `LoadGeneratedMeshAsync(generationId)` exists for loading a generated mesh by id; the reference does not say how long ids stay valid. Test before promising permanence.

---

## 5. Where Roblox generation fits in a real pipeline

| Use | Verdict | Why |
|---|---|---|
| Game jam, prototype, greybox props | Good | Seconds to a recognisable object |
| Player creativity features (build your car, make a pet) | Good, with guard rails | That is what the runtime API is for |
| Background filler in a stylised game | Risky | Style drift; each piece needs a cleanup pass |
| Hero props, weapons, characters | Poor | Topology, UVs and style matter; see [[Modeling Weapons and Props]] |
| Concept exploration | Good | Generate ten shapes, model the best idea by hand |

The reference project tried generated meshes and generated set pieces early, then banned them. The rule written into its notes: build every model in Blender with clean topology, consistent texel density and LODs; never use mesh generation, procedural model generation, Toolbox assets or the old AI-generated meshes; greybox with temporary blockout parts and replace them one for one with hand-built assets. The reasons, in order: wrong proportions, style mismatch with the hand-made "chunky stylised" look, and no control over topology for LODs. See [[Modeling Fundamentals for Games]] and [[Low-Poly and Stylized Modeling]].

That is not a verdict against the tools. It is a verdict about a game with a defined style and a team able to model. For a solo creator without modelling skills, generated meshes plus a consistent material palette can carry a whole game, especially a low-poly one where the triangle cap helps.

---

## 6. Cleaning a generated mesh

If you keep a generated mesh, treat it like any imported asset ([[Exporting and Validating Models for Roblox]]):

1. **Measure** raw size and proportions; fix scale.
2. **Pivot and orientation**: set the pivot to the base centre; face the model down -Z (Roblox forward).
3. **Collision**: `CollisionFidelity` Box or Hull for props; `CanCollide` false for decoration; `CanTouch` false and `CanQuery` false where unused.
4. **Render fidelity**: Automatic for props.
5. **Texture**: generated colour textures may not match your palette. Options: regenerate the texture with the Texture Generator and a palette prompt; or clear the texture and use a Roblox material plus colour (the reference project's material pass did this on hundreds of meshes).
6. **Triangles**: if over budget, regenerate with a lower cap rather than decimating, because decimating a baked texture smears it.
7. **Name it** and tag it as generated (attribute `Generated = true`) so you can find and replace it later.

---

## Common mistakes

- Placing a generated mesh at whatever size it arrived.
- Firing many generation jobs in parallel and reading "Too Many Requests" as a bug.
- Using anatomy words in prompts for a stylised or horror set and wondering why everything fails.
- Shipping player generation without per-player limits and moderation tooling.
- Building on the deprecated `GenerateMeshAsync`.
- Guessing option keys that the reference does not list.

## Checklist

- [ ] Raw size and proportions checked after every generation.
- [ ] Jobs queued, a few at a time.
- [ ] Collision and render fidelity set; triangles within budget.
- [ ] Generated assets tagged for later replacement.
- [ ] Runtime generation: disclosed in the maturity questionnaire, rate limited per player, filtered, removable, with a fallback.

## See also
[[Roblox Studio Assistant]] · [[AI Material and Texture Generation]] · [[AI 3D Model Generation Outside Roblox]] · [[Roblox Policies on AI-Generated Content]] · [[Parts Unions and MeshParts]] · [[Retopology and Decimation]] · [[Art Pipeline - Concept to In-Game Asset]]

## Connected notes
<!-- auto-links:start -->
[[AI in Roblox Development Overview]] · [[Studio Assistant and AI Tools]] · [[Triangle Budget]] · [[Roblox Studio MCP Server]] · [[Skill - Roblox Asset Import]] · [[Other Modeling Tools - Maya Max ZBrush MagicaVoxel]]
<!-- auto-links:end -->
