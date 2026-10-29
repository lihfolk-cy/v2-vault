---
tags: [reference, engine, guiservice, api/GuiService, type/reference, area/scripting, level/intermediate, api/SelectedObject, api/GetGuiInset, area/ui, api/TopbarInset]
---

# GuiService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: building new gamepad groups with `AddSelectionParent`.
> - Avoid: opening a menu on gamepad without setting `SelectedObject`.
> - Avoid: placing HUD buttons under the top bar by hand-tuned offsets.
> - Every modal menu sets `SelectedObject` on open and clears it on close.
> - HUD layout respects `TopbarInset` or `ScreenInsets`.
> - Text size, transparency and motion read from the player preference properties.
>
> Cost: TL;DR ~150 tok · whole note ~1.4k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The client-side service for gamepad selection, screen insets, player accessibility preferences and Roblox's built-in menus and notifications. Topic notes: [[Gamepad and Console UX]], [[Safe Areas and Insets]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| SelectedObject | prop | GuiObject? | nil | Client; the gamepad-focused element; may reset to nil when off screen | no |
| GuiNavigationEnabled | prop | boolean | - | Client; turns default controller navigation on or off | no |
| AutoSelectGuiEnabled | prop | boolean | - | Client; Select button or Backslash picks a GUI automatically | no |
| Select | method | `(selectionParent: Instance)` | - | Client; focuses a selectable descendant of PlayerGui | no |
| TouchControlsEnabled | prop | boolean | true | Client; hides or shows touch controls | no |
| [[TopbarInset]] | prop | Rect | - | Read-only; the unobstructed area beside the Roblox buttons in the top bar | no |
| GetGuiInset | method | `() -> (Vector2, Vector2)` | - | Inset in pixels; only applies to ScreenGuis with `IgnoreGuiInset` false | no |
| GetInsetArea | method | `(screenInsets: Enum.ScreenInsets) -> Rect` | - | Inset region for a given `ScreenInsets` mode | no |
| [[ViewportDisplaySize]] | prop | `Enum.DisplaySize` | - | Read-only; `Small`, `Medium` or `Large`; replaces `IsTenFootInterface` | no |
| PreferredTextSize | prop | `Enum.PreferredTextSize` | - | Read-only player preference (`Medium` to `Largest`) | no |
| PreferredTransparency | prop | number | 1 | Read-only, 0-1; multiply background transparency by it | no |
| ReducedMotionEnabled | prop | boolean | - | Read-only; tone down shakes and big tweens when true | no |
| MenuIsOpen | prop | boolean | - | Read-only; true while any CoreGui menu is open | no |
| MenuOpened / MenuClosed | event | `()` | - | Fires when the escape menu opens or closes | - |
| SendNotification | method | `(notificationInfo: {Title, Text, Icon, Buttons, OnDisplay, OnDismiss}) -> string` | - | Client; returns an id, or "" if it could not be queued | no |
| DismissNotification | method | `(notificationId: string) -> boolean` | - | Client; closes one you sent | no |
| SetInspectMenuEnabled / InspectPlayerFromUserId | method | `(enabled: boolean)` / `(userId: number)` | - | Client; control the avatar inspect menu | no |
| SetEmotesMenuOpen / GetEmotesMenuOpen | method | `(isOpen: boolean)` / `() -> boolean` | - | Client | no |
| SetGameplayPausedNotificationEnabled | method | `(enabled: boolean)` | - | Client; hides the built-in "gameplay paused" toast | no |

Retired names and their replacements:
- `AddSelectionParent`, `AddSelectionTuple`, `RemoveSelectionGroup` -> `GuiBase2d.SelectionGroup` with the `SelectionBehaviorUp/Down/Left/Right` properties, plus `GuiObject.NextSelectionDown` and friends for explicit links.
- `IsTenFootInterface` -> `ViewportDisplaySize`.
- `IsModalDialog`, `IsWindows` -> deprecated with no direct replacement; use `MenuIsOpen` for the escape menu.

## Limits and defaults

- GuiService is a client service: it is not created by scripts and its state is not replicated.
- `PreferredTransparency` ranges 0-1; 1 means the player is fine with your default transparency.
- `GetGuiInset` values are in pixels and matter only for ScreenGuis that do not ignore the inset; `ScreenGui.ScreenInsets` is the newer layout control.
- `SelectedObject` must be a visible, `Selectable` GuiObject inside PlayerGui.

## Replication and authority

- Use GuiService from LocalScripts; nothing here replicates, and preferences are per player.
- `SendNotification` shows Roblox's native notification UI on that one client; for server-triggered messages, fire a RemoteEvent and notify on the client.
- Player preferences (`PreferredTextSize`, `ReducedMotionEnabled`, `PreferredTransparency`) can change mid-session, so listen with `GetPropertyChangedSignal`.

## Common mistakes

- Avoid: building new gamepad groups with `AddSelectionParent`. Symptom: deprecated API; use `SelectionGroup` and the `SelectionBehavior*` properties.
- Avoid: opening a menu on gamepad without setting `SelectedObject`. Symptom: the controller has nothing focused and the menu feels dead.
- Avoid: placing HUD buttons under the top bar by hand-tuned offsets. Symptom: overlap on some devices; read `TopbarInset` or use `ScreenInsets`.
- Avoid: ignoring `ReducedMotionEnabled`. Symptom: players who asked for less motion still get screen shakes.
- Avoid: calling GuiService from a server Script. Symptom: the call does nothing useful because GuiService state lives on each client.

## Checklist

- Every modal menu sets `SelectedObject` on open and clears it on close.
- HUD layout respects `TopbarInset` or `ScreenInsets`.
- Text size, transparency and motion read from the player preference properties.
- Gamepad groups use `SelectionGroup` and `SelectionBehavior*`, not the retired selection APIs.

Source: https://create.roblox.com/docs/reference/engine/classes/GuiService - verified 2026-10-29

<!-- related:start -->
## Related
[[ScrollingFrame - Engine Reference Card]] · [[UserInputService - Engine Reference Card]] · [[Camera - Engine Reference Card]] · [[BillboardGui - Engine Reference Card]] · [[Instance - Engine Reference Card]] · [[TweenService - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[Player - Engine Reference Card]]
<!-- related:end -->
