---
tags: [atlas, api, type/atlas, area/platform, area/networking, api/SocialService]
---
# SocialService

<!-- tldr:start -->
> [!tldr] TL;DR
> - `SocialService` provides the platform invite prompt.
> - `SocialService:GetPlayersByPartyId(partyId)` returns the connected `Player` objects in this server whose `PartyId` matches.
> - `SocialService.ShareSheetClosed` fires on the server when the sheet closes.
> - Roblox also exposes platform party data (`SocialService:GetPartyAsync`, `Player.PartyId`); check the current docs and...
>
> Cost: TL;DR ~140 tok · whole note ~400 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`SocialService` provides the platform invite prompt. (from [[Community Building]])

API snapshot: service, inherits `Instance` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `SocialService:GetPlayersByPartyId(partyId)` returns the connected `Player` objects in this server whose `PartyId` matches. ([[Parties and Group Teleports]])
- `SocialService.ShareSheetClosed` fires on the server when the sheet closes. ([[Friend Invites Referrals and Experience Invites]])
- Roblox also exposes platform party data (`SocialService:GetPartyAsync`, `Player.PartyId`); check the current docs and availability before relying on them (Unverified for rollout and permissions in your context). ([[Joining Friends Parties and Private Servers]])

## Mentioned in

10 notes in 7 sections. The 10 most relevant are linked:

### 01 Studio and Workflow
[[Testing Modes - Play Run and Multi-Client]]

### 10 Game Design and Genres
[[Social Design and Multiplayer Play]]

### 11 Monetization Publishing and Live Ops
[[Community Building]]

### 41 Multiplayer Services
[[Multiplayer Services Start Here]] · [[Parties and Group Teleports]]

### 46 Resource Library
[[Links - Community and social]]

### 49 Roblox Platform Features
[[Avatar Context Menus Profiles and Social Surfaces]] · [[Experience Notifications and Return Prompts]] · [[Friend Invites Referrals and Experience Invites]]

### 58 Player QoL and Game Tweaks
[[Joining Friends Parties and Private Servers]]

<!-- atlas:generated -->
