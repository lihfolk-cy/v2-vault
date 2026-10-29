---
tags: [reference, engine, scrollingframe, api/ScrollingFrame, type/reference, area/scripting, level/intermediate, api/AutomaticCanvasSize, api/CanvasSize]
---

# ScrollingFrame - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: leaving the default `CanvasSize` scale on the automatic axis.
> - Avoid: `ScrollingDirection` left on `XY` for a vertical list.
> - Avoid: thousands of rows each as a live instance.
> - One axis per list: `ScrollingDirection` and `AutomaticCanvasSize` both set to that axis.
> - `CanvasSize` zeroed on automatic axes, or computed on manual ones.
> - Long lists virtualised; padding via `UIPadding` so the first and last rows are not flush.
>
> Cost: TL;DR ~150 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

A Frame with built-in scrolling: a clipped window over a larger canvas, driven by mouse wheel, touch drag or gamepad. Topic notes: [[UI Layout Objects - Lists Grids and Pages]], [[Virtualized Lists and Large Inventories]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| CanvasSize | prop | UDim2 | `{0, 0}, {2, 0}` (twice the frame height) | The scrollable area; set it yourself when not automatic | no |
| AutomaticCanvasSize | prop | `Enum.AutomaticSize` | `None` | `Y` for lists, `X` for strips, `XY` for both; canvas grows with content | no |
| AbsoluteCanvasSize | prop | Vector2 | - | Read-only; the real scrollable size in pixels after automatic sizing | no |
| AbsoluteWindowSize | prop | Vector2 | - | Read-only; the visible window minus scroll bars | no |
| CanvasPosition | prop | Vector2 (pixels) | `0, 0` | Current scroll offset; set it (or tween it) to scroll from code; no effect while no bar is visible | no |
| ScrollingDirection | prop | `Enum.ScrollingDirection` | `XY` | Lock to `Y` or `X` so a list never drifts sideways | no |
| ScrollingEnabled | prop | boolean | true | Turn off to freeze scrolling (for example during a drag) | no |
| ScrollBarThickness | prop | number (pixels) | 12 | Applies to both bars | no |
| ScrollBarImageColor3 / ScrollBarImageTransparency | prop | Color3 / number | white / 0 | Tints the bar images | no |
| TopImage / MidImage / BottomImage | prop | ContentId | built-in scroll textures | `*Content` variants take the `Content` type | no |
| VerticalScrollBarInset / HorizontalScrollBarInset | prop | `Enum.ScrollBarInset` | `None` | `ScrollBar` or `Always` narrows the canvas so the bar never covers content | no |
| VerticalScrollBarPosition | prop | `Enum.VerticalScrollBarPosition` | `Right` | `Left` for right-to-left layouts | no |
| ElasticBehavior | prop | `Enum.ElasticBehavior` | `WhenScrollable` | Touch overscroll bounce: `Always`, `Never`, `WhenScrollable` | no |
| GetScrollVelocity | method | `() -> Vector2` | - | Inertia after the finger lifts; meaningful on devices or the Device Emulator | no |
| ResetScrollVelocity | method | `()` | - | Stops inertial scrolling on both axes | no |
| ClipsDescendants | prop (GuiObject) | boolean | - | Keep true so content outside the window stays hidden | no |
| Selectable / SelectionGroup | prop (GuiObject / GuiBase2d) | boolean | - | Gamepad users scroll by moving selection through children | no |

Sizing choice in one line: `AutomaticCanvasSize` for dynamic lists you build with a `UIListLayout` or `UIGridLayout`; a computed `CanvasSize` (for example from `UIListLayout.AbsoluteContentSize`, or rows times row height) for virtualised lists where you place items yourself.

## Limits and defaults

- Default `CanvasSize` is `UDim2.new(0, 0, 2, 0)`: a scale of 2 means the canvas is twice the window height before any content is added.
- `ScrollBarThickness` defaults to 12 pixels.
- Scroll bars appear only when the canvas (set or automatic) is larger than the frame on that axis.
- ScrollingFrame is a GuiObject: it renders only under a ScreenGui, SurfaceGui or BillboardGui on the client.

## Replication and authority

- UI lives in each player's PlayerGui; a ScrollingFrame cloned from StarterGui is per client, and scroll state never reaches the server.
- Build and fill lists in LocalScripts from data the server sends; the server validates any action a list row triggers.

## Common mistakes

- Avoid: leaving the default `CanvasSize` scale on the automatic axis. Symptom: a list with blank space below its items; set `CanvasSize = UDim2.new()` when `AutomaticCanvasSize` is on.
- Avoid: `ScrollingDirection` left on `XY` for a vertical list. Symptom: the list wobbles sideways on touch.
- Avoid: thousands of rows each as a live instance. Symptom: frame drops while scrolling; virtualise and recycle rows.
- Avoid: assuming `CanvasPosition` updates when no bar is visible. Symptom: code-driven scrolling does nothing on short lists.
- Avoid: thick bars covering the last column. Symptom: clipped buttons; set `VerticalScrollBarInset` to `ScrollBar`.

## Checklist

- One axis per list: `ScrollingDirection` and `AutomaticCanvasSize` both set to that axis.
- `CanvasSize` zeroed on automatic axes, or computed on manual ones.
- Long lists virtualised; padding via `UIPadding` so the first and last rows are not flush.
- Tested with mouse wheel, touch and gamepad.

Source: https://create.roblox.com/docs/reference/engine/classes/ScrollingFrame and https://create.roblox.com/docs/ui/scrolling-frames - verified 2026-10-29

<!-- related:start -->
## Related
[[BillboardGui - Engine Reference Card]] · [[Debugging UI Layout and Input]] · [[GuiService - Engine Reference Card]] · [[UserInputService - Engine Reference Card]] · [[TweenService - Engine Reference Card]] · [[ParticleEmitter - Engine Reference Card]] · [[Camera - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[Animator - Engine Reference Card]]
<!-- related:end -->
