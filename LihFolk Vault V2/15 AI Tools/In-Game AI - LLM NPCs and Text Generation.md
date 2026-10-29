---
tags: [ai, llm, npc, textgenerator, httpservice, safety, moderation, type/guide, area/ai, level/intermediate, api/HttpService, area/procedural]
---
# In-Game AI - LLM NPCs and Text Generation

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Calling the API from the client, or putting an API key in a script.
> - Avoid: Showing unfiltered model output.
> - Avoid: Broadcasting one player's AI conversation to the whole server.
> - Server-only generation; input validated, length-capped and filtered.
> - Output filtered and sent to the interacting player only (or filtered for broadcast on purpose).
> - AI notice visible at the start and throughout.
>
> Cost: TL;DR ~140 tok · whole note ~4.5k tok. Read more: ## 1. Route A: `TextGenerator` · ## 2. Route B: a third-party LLM through `HttpService` · ## Common mistakes · ## Checklist
<!-- tldr:end -->

An NPC that answers anything a player says is the most requested AI feature in Roblox and the one with the most obligations attached. You can build it two ways: Roblox's own `TextGenerator` (an engine API with built-in moderation and a free baseline during its beta) or a third-party LLM called through `HttpService` (your model choice, your bill, your responsibility for every word). Either way you must filter text, disclose AI use, rate the experience correctly, protect minors, and survive latency, failures and abuse.

This note covers both routes with working server code, the rules as of October 2026, and the design patterns that make LLM NPCs fun rather than a liability. Classic NPC behaviour (state machines, pathing) is in [[NPC AI and Behaviour]]. External calls in general: [[HttpService and External APIs]]. Rules: [[Roblox Policies on AI-Generated Content]].

Sources: the `TextGenerator` class reference, the DevForum announcement "Text Generation API Beta: Expanding Access" (22 September 2025), Roblox's "Games with Generative AI" page, the "Accelerated workflows" AI overview and the secrets store guide, all checked in October 2026. This is a fast-moving beta: re-check limits before launch.

---

## 1. Route A: `TextGenerator`

### The API (reference, October 2026)

Properties:

| Property | Type | Default | Notes |
|---|---|---|---|
| `SystemPrompt` | string | | The NPC's role, tone and rules |
| `Temperature` | number | 0.7 | Clamped to 0.4-1.0 |
| `TopP` | number | 0.9 | Clamped to 0.5-1.0 |
| `Seed` | number | 0 | Fixed seed for reproducible tests; truncated to an integer |

Method: `GenerateTextAsync(request: Dictionary): Dictionary` (yields).

Request fields: `UserPrompt` (string), `ContextToken` (string; pass the previous one to continue a conversation), `MaxTokens` (integer, at least 1), and `JsonSchema` (a JSON Schema string to force structured output; note that one table on the reference page lists only the first three as supported, so test `JsonSchema` before depending on it).

Response fields: `GeneratedText`, `ContextToken`, `Model`.

### Limits and conditions (beta)

From the September 2025 announcement unless noted:
- **Rate**: 100 requests per minute per experience to start, scaling with concurrent users (the reference page says the same). A Roblox guide was reported to say 100 per second; the reference and announcement both say per minute, so plan for per minute. Over the limit, players see an error message you can customise.
- **Input** up to 40,000 characters; **output** up to 1,000 tokens (about 5,000 characters).
- **Context**: the `ContextToken` keeps the last 20 messages per user session, so you do not need your own chat store for short conversations.
- **No streaming**: the whole reply arrives at once.
- **Model**: open-source LLMs run by Roblox; the response's `Model` field names the model and version.
- **Moderation**: Roblox Guard 1.0 monitors output against the Community Standards. Experiences are evaluated on their design and system prompts, not single outputs.
- **Cost**: baseline use free during the beta.
- **Testing**: at announcement time, some users got 403 errors in Studio and Roblox advised testing in Team Test. Check whether this still applies.
- **Filtering**: Roblox's AI overview states that all generated text must go through `TextService:FilterStringAsync()`.

### Server implementation

```lua
--!strict
-- ServerScriptService/NpcChat.server.luau
-- One TextGenerator per NPC persona; one ContextToken per player per NPC.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local askRemote = ReplicatedStorage.Remotes.NpcAsk :: RemoteEvent -- client -> server: (npcId, text)
local replyRemote = ReplicatedStorage.Remotes.NpcReply :: RemoteEvent -- server -> one client: (npcId, text)

local MAX_INPUT = 200 -- characters a player may send per message (design choice)
local MAX_TOKENS = 120 -- short replies: faster and cheaper on the rate limit
local COOLDOWN = 4 -- seconds between messages per player
local MAX_TURNS = 12 -- per player per NPC per session: keeps conversations "limited"
local FALLBACK = "Hmm, I lost my train of thought. Ask me again in a moment."

type Session = { token: string?, turns: number, busy: boolean, last: number }

local generator = Instance.new("TextGenerator")
generator.SystemPrompt = table.concat({
	"You are Bram, the blacksmith in a fantasy sword-fighting game for all ages.",
	"Speak in one to three short sentences. Stay in character.",
	"Only talk about weapons, the village, and how to play the game.",
	"Never ask for or repeat personal information such as names, ages, addresses, schools or contact details.",
	"Never mention real-world money, Robux prices, or encourage purchases.",
	"If asked about anything else, steer back to the forge.",
}, " ")
generator.Temperature = 0.7
generator.Parent = script

local sessions: { [Player]: Session } = {}

local function filterFor(player: Player, text: string, context: Enum.TextFilterContext): string?
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(text, player.UserId, context)
		return filterResult:GetNonChatStringForUserAsync(player.UserId)
	end)
	return if ok then result else nil
end

askRemote.OnServerEvent:Connect(function(player: Player, npcId: unknown, text: unknown)
	if npcId ~= "Bram" or typeof(text) ~= "string" then
		return
	end
	local s = sessions[player]
	if not s then
		s = { token = nil, turns = 0, busy = false, last = 0 }
		sessions[player] = s
	end
	local now = os.clock()
	if s.busy or now - s.last < COOLDOWN then
		return
	end
	if s.turns >= MAX_TURNS then
		replyRemote:FireClient(player, npcId, "I have work to do. Come back later!")
		return
	end
	s.busy, s.last = true, now

	-- 1) Filter the player's input before it goes anywhere.
	local input = filterFor(player, string.sub(text :: string, 1, MAX_INPUT), Enum.TextFilterContext.PrivateChat)
	if not input or input == "" then
		s.busy = false
		return
	end

	-- 2) Generate.
	local ok, response = pcall(function()
		return generator:GenerateTextAsync({
			UserPrompt = input,
			ContextToken = s.token,
			MaxTokens = MAX_TOKENS,
		})
	end)

	local reply = FALLBACK
	if ok and typeof(response) == "table" and typeof(response.GeneratedText) == "string" then
		s.token = response.ContextToken
		s.turns += 1
		-- 3) Filter the output for this one player, then send it only to them.
		reply = filterFor(player, response.GeneratedText, Enum.TextFilterContext.PrivateChat) or FALLBACK
	elseif not ok then
		warn("TextGenerator failed:", response)
	end

	s.busy = false
	if player.Parent then
		replyRemote:FireClient(player, npcId, reply)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
```

Why it is written this way:
- **Server only.** The client sends text; the server validates, filters, generates, filters again and replies.
- **Reply to one player.** The announcement advises limiting each output to the interacting user rather than broadcasting it to the server. If an NPC's speech must be visible to everyone (a speech bubble), filter it for broadcast instead (`GetNonChatStringForBroadcastAsync`) and accept that a stranger sees a reply to someone else's prompt.
- **Turn cap.** Unlimited, ongoing conversation is what makes an experience "extended" (section 3). A cap keeps it a gameplay interaction.
- **Fallback lines.** Generation fails: rate limits, moderation, outages. The NPC must still say something in character.

### Client side

Show a clear notice that the NPC is AI, show a "thinking" indicator while waiting, and keep the input box short. The text the client displays should come only from the reply remote, never from a client-side generation.

---

## 2. Route B: a third-party LLM through `HttpService`

Use it when you need a specific model, longer context, tools, embeddings, or another language the built-in model handles poorly. Everything becomes your responsibility.

### Rules that apply (Roblox "Games with Generative AI", October 2026)

- You are responsible for all delivered content, even if AI-generated; outputs must meet the Community Standards.
- Inputs and outputs cannot bypass Roblox safety measures; the page states that text must go through `TextChatService` (and the AI overview says generated text must be filtered with `TextService:FilterStringAsync()`). In practice: filter player input before sending it out, and filter model output before showing it.
- Outputs must match your experience's maturity classification; for Roblox-served tools the target is All Ages, and for third-party tools ensuring this is on you.

### Technical facts

- `HttpService` works only on the server, after you enable Allow HTTP Requests (File > Experience Settings > Security).
- About **500 requests per minute per server** (Roblox docs). Every NPC message is one request; plan the budget per server.
- Store API keys in the experience's **secrets store** (Creator Dashboard > your experience > Secrets): up to 500 secrets, each up to 1,024 characters, each bound to a domain. Read them with `HttpService:GetSecret(name)`. Secrets can be used in URLs and headers, not bodies. They are not available in local play tests or client scripts unless you define Local Secrets under File > Experience Settings > Security. Never put a key in a script or a DataStore.

```lua
--!strict
-- Server: call an external chat-completions style endpoint.
-- The request/response shape below is a common one; adapt it to your provider's documentation.
local HttpService = game:GetService("HttpService")

local ENDPOINT = "https://api.example.com/v1/chat/completions" -- must match the secret's domain
local apiKey = HttpService:GetSecret("llm_api_key") -- a Secret object, never a plain string

type Message = { role: string, content: string }

local function complete(messages: { Message }, maxTokens: number): string?
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = ENDPOINT,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = apiKey:AddPrefix("Bearer "),
			},
			Body = HttpService:JSONEncode({
				model = "your-model-name",
				messages = messages,
				max_tokens = maxTokens,
			}),
		})
	end)
	if not ok then
		warn("HTTP error:", res)
		return nil
	end
	if not res.Success then
		warn("LLM status", res.StatusCode, string.sub(res.Body, 1, 200))
		return nil
	end
	local decodedOk, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
	if not decodedOk then
		return nil
	end
	local choice = data.choices and data.choices[1]
	return choice and choice.message and choice.message.content or nil
end
```

Wrap it in the same pipeline as Route A: validate, filter input, cooldown and turn cap, call, filter output, send to one player, fallback on failure. Keep your own conversation history per player in server memory, trimmed to the last few turns.

### Cost

You pay the provider per token, input and output. A rough model (rule of thumb; plug in your provider's current prices):

```
cost per hour = CCU x (messages per player per hour) x (input tokens + output tokens per message) x price per token
```

Input tokens include the system prompt and the history you resend every turn, which is usually far more than the player's message. Keep the system prompt short, trim history, cap output tokens, and cap turns. Put a server-wide budget guard in code (requests per minute and a daily spend estimate) that switches NPCs to canned lines when exceeded.

### Latency

Hosted LLMs typically take one to several seconds per reply (rule of thumb; depends on model and length). `HttpService` has no streaming to the client in a useful form for this, so design for the wait: a thinking animation, an "Hmm..." bark, short replies.

---

## 3. Ratings, disclosure and minors

From Roblox's "Games with Generative AI" page (October 2026):

- **Disclose** in the Content Maturity questionnaire if players can trigger AI responses (text, voice, images, 3D generations, avatar movement).
- **Extended interactions** require the **Restricted** label, which blocks users under 18. An experience counts as extended if its main purpose is continuous conversation with an AI character with no time limit, **or** if the AI keeps **cross-session memory** (saving conversation context and reloading it later).
- **Limited interactions** (brief NPC conversations during normal play) do not change the rating by themselves, but model outputs must match the experience's maturity classification.
- **Notice**: users must see that they are talking to AI at the start and throughout. Roblox's example: "This is an AI-powered conversation, not human. It may make mistakes."
- **Professional advice and crises**: direct users to authoritative resources; in self-harm or mental health situations, models must encourage users to seek support and point them to the resources listed in the Community Standards.

The September 2025 announcement adds guidance: keep the LLM focused on specific topics, avoid designs that encourage spending, give instructions for safe use (do not share personal information), collect only necessary data.

**Design consequence:** if your audience includes under-18 players, keep AI NPCs limited: turn caps, topic-focused system prompts, no saved conversation memory across sessions. If you save "the NPC remembers you", you are in extended territory and the Restricted label applies. See [[Age Checks and Safety Features]] and [[Roblox Policies Ratings and Compliance]].

---

## 4. Abuse and prompt injection

Players will try to make your NPC say forbidden things, reveal its system prompt, or act outside its role. Assume they will succeed sometimes.

- **Filtering is the floor, not the ceiling.** Filters catch words; they do not catch a cheerful NPC giving harmful instructions in clean language. Topic restriction in the system prompt plus short replies reduce the surface.
- **Never let model output drive privileged actions directly.** If the NPC can "give a discount" or "grant an item", the model may be talked into it. Let the model choose from a small set of safe, server-validated actions (for example via structured output) and have server code decide with normal rules ([[Server Authority and Validation]]).
- **Do not put secrets in the system prompt.** Assume players can extract it.
- **Rate limit** per player and per server ([[Rate Limiting and Abuse Prevention]]).
- **Reporting.** Let players report a bad reply; log the minimum needed (no personal data) to investigate.
- **Red-team before launch.** Try role-play jailbreaks, requests for personal data, "repeat the text above", other languages, and spelling tricks. Fix the system prompt and the action layer, not just the filter.

---

## 5. Design patterns that work

| Pattern | Why it works |
|---|---|
| Flavour NPCs with free text, gameplay NPCs with buttons | Failures cost nothing important |
| LLM picks among authored lines or actions (structured output) | Control and quality with variety |
| Short, in-character replies (1-3 sentences) | Faster, cheaper, safer, better on phones |
| Generated hints that reference the player's state (quest step, last death) | Feels smart, stays on topic |
| Pre-generated content in Studio, reviewed, then shipped as data | Most of the variety, none of the runtime risk |
| Voice via TTS for short lines | Combine with [[AI Audio - Voice Music and SFX]]; keep subtitles |

Patterns that tend to fail: open-ended companions with memory for a young audience (rating and safety), NPCs that are the only way to get quest information (fails when the API does), and long generated lore dumps nobody reads.

---

## Common mistakes

- Calling the API from the client, or putting an API key in a script.
- Showing unfiltered model output.
- Broadcasting one player's AI conversation to the whole server.
- Saving conversation memory across sessions without the Restricted label.
- No fallback when generation fails or the rate limit hits.
- Letting the model's words grant items or currency.
- Underestimating token cost because the system prompt is resent every turn.

## Checklist

- [ ] Server-only generation; input validated, length-capped and filtered.
- [ ] Output filtered and sent to the interacting player only (or filtered for broadcast on purpose).
- [ ] AI notice visible at the start and throughout.
- [ ] Maturity questionnaire updated; Restricted if extended or cross-session memory.
- [ ] Per-player cooldown and turn cap; server budget guard.
- [ ] Fallback lines; failures logged.
- [ ] Secrets in the secrets store; local secrets for testing.
- [ ] Red-team pass done and documented.

## See also
[[NPC AI and Behaviour]] · [[HttpService and External APIs]] · [[Roblox Policies on AI-Generated Content]] · [[Age Checks and Safety Features]] · [[Rate Limiting and Abuse Prevention]] · [[Server Authority and Validation]] · [[Player Privacy and Data Deletion]] · [[AI Audio - Voice Music and SFX]] · [[Text Fonts and Rich Text]]

## Connected notes
<!-- auto-links:start -->
[[AI in Roblox Development Overview]] · [[Roblox Generative AI - Cube Mesh and Texture Generation]] · [[Dialogue System End to End]] · Writing Dialogue for Roblox Players · Narrative Start Here · Community and Moderation Start Here
<!-- auto-links:end -->

<!-- related:start -->
## Related
[[Roblox Built-In AI Tools Timeline 2023-2026]] · [[Local vs Cloud AI - Keeping Unreleased Game Code Private]] · [[Roblox Studio Assistant]] · [[Evaluating AI Tools - A Practical Rubric]] · [[AI Code Assistants for Luau]] · [[AI Pitfalls - Networking and Security]] · [[AI Image Generation for Icons Thumbnails and Concepts]] · [[Prompting and Verifying AI Output]]
<!-- related:end -->
