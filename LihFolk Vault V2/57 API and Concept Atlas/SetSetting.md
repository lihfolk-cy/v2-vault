---
tags: [atlas, api, type/atlas, area/studio, area/security, api/SetSetting]
---
# SetSetting

<!-- tldr:start -->
> [!tldr] TL;DR
> - `SetSetting` stores JSON per plugin, persists across Studio restarts, and has documented restrictions: no backslashes in keys...
> - Anything stored with `SetSetting` can be changed by the other copy at any moment, and the docs warn that both `GetSetting` and...
> - Plugin settings are per user, not per place.
> - Never put keys in `SetSetting`. It is a plain JSON file on disk, readable by anything running as your user.
>
> Cost: TL;DR ~150 tok · whole note ~380 tok. Read more: ## In short · ## Key facts
<!-- tldr:end -->

## In short

`SetSetting` stores JSON per plugin, persists across Studio restarts, and has documented restrictions: no backslashes in keys or values, no newlines, quotes or periods in keys (Roblox docs). (from [[Building a Studio Plugin End to End]])

API snapshot: member of `Plugin` (`_tools/roblox_api.json`, docs build of 2026-10-27).

## Key facts

- Anything stored with `SetSetting` can be changed by the other copy at any moment, and the docs warn that both `GetSetting` and `SetSetting` can silently fail under contention. ([[Building a Studio Plugin End to End]])
- Plugin settings are per user, not per place. `plugin:SetSetting` stores data for that user on that machine, so a team does not share settings through it. ([[Plugins - Using and Writing]])
- Never put keys in `SetSetting`. It is a plain JSON file on disk, readable by anything running as your user. ([[Plugin Security and Permissions]])

## Mentioned in

8 notes in 3 sections. The 8 most relevant are linked:

### 01 Studio and Workflow
[[Plugins - Using and Writing]] · [[Studio Settings and Shortcuts]]

### 22 Anti-Exploit and Security
[[Threat Modeling a Roblox Game]]

### 39 Studio Plugins and Tooling
[[Building a Studio Plugin End to End]] · [[Plugin Security and Permissions]] · [[Plugin UI with DockWidgets]] · [[Publishing Selling and Updating Plugins]] · [[Undo and ChangeHistoryService Done Right]]

<!-- atlas:generated -->
