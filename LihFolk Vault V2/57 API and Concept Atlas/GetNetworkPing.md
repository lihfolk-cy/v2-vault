---
tags: [atlas, api, type/atlas, area/security, area/networking, api/GetNetworkPing]
---
# GetNetworkPing

<!-- tldr:start -->
> [!tldr] TL;DR
> - `GetNetworkPing` returns seconds (Roblox docs).
> - `GetNetworkPing()` returns the player's isolated network latency in seconds, measured as a client-server round trip (Roblox docs).
> - Current server ping is measurable: `Player:GetNetworkPing()` on the client returns the player's network latency to their...
>
> Cost: TL;DR ~120 tok · whole note ~360 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`GetNetworkPing` returns seconds (Roblox docs). (from [[Feedback - Autosave Indicator Ping Display and Error Toasts]])

API snapshot: member of `Player` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- `GetNetworkPing()` returns the player's isolated network latency in seconds, measured as a client-server round trip (Roblox docs). ([[Detecting Movement Exploits - Speed Fly Noclip Teleport]])
- Current server ping is measurable: `Player:GetNetworkPing()` on the client returns the player's network latency to their current server in seconds (Roblox docs). ([[Server Hop Rejoin and Server Lists with Ping]])

## Mentioned in

8 notes in 6 sections. The 8 most relevant are linked:

### 03 Architecture and Networking
[[Client-Server Model]]

### 09 Gameplay Systems
[[Hitboxes and Hit Detection]]

### 12 Performance Testing and Debugging
[[In-Game Bug Report Button with Automatic Context]]

### 22 Anti-Exploit and Security
[[Detecting Combat Exploits - Reach Rate and Aim]] · [[Detecting Movement Exploits - Speed Fly Noclip Teleport]]

### 58 Player QoL and Game Tweaks
[[Feedback - Autosave Indicator Ping Display and Error Toasts]] · [[Server Hop Rejoin and Server Lists with Ping]]

### 62 Engine Reference Cards
[[Player - Engine Reference Card]]

<!-- atlas:generated -->
