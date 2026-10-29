---
tags: [ui, figma, mapping, layout, uigradient, uistroke, uicorner, text, type/guide, area/ui, level/advanced, api/UIGradient, api/UIListLayout]
---
# Figma Property Mapping for Roblox UI

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Using normalised gradient handles directly: every diagonal gradient points the wrong way.
> - Avoid: Reading the size of a rotated node from `absoluteBoundingBox`.
> - Avoid: Treating `strokeAlign` as always centred: inside strokes eat into the box, outside strokes add to it.
> - Sizes in Offset at the reference resolution, with one `Fit` `UIScale` per branch.
> - Constraints converted to `AnchorPoint`, Position and Size per the table.
> - Auto layout mapped to `UIListLayout`, `UIPadding`, `UIFlexItem` and `AutomaticSize`.
>
> Cost: TL;DR ~170 tok · whole note ~3.6k tok. Read more: ## 5. Fills and gradients · ## 6. Strokes, corners and effects · ## Common mistakes · ## Checklist
<!-- tldr:end -->

This is the readable version of the mapping that the `lihfolk-figma` converter applies, and that a hand build from the Figma MCP should follow. Each Figma property has a Roblox counterpart, an approximation, or a clear "do this instead". The contract file it mirrors is `skills/lihfolk-figma/references/property-mapping.md`; when one changes, change both.

Pipeline and handoff are in [[Figma to Roblox UI - Pipeline and Handoff]]. How to draw frames that need few approximations is in [[Designing Roblox UI in Figma - Frames, Safe Areas and Tokens]]. Engine detail behind the Roblox side is in:
- [[Layout - Scale Offset and Constraints]];
- [[UI Layout Objects - Lists Grids and Pages]];
- [[Text Fonts and Rich Text]];
- [[ScreenGui Fundamentals]].

Sources:
- **Docs:**
  - Figma REST API reference at developers.figma.com: node types, property types, global properties, file endpoints;
  - Roblox engine reference: `UIGradient`, `GradientType`, `UICorner`, `UIStroke`, `TextLabel`, `ColorSequence`.

  All checked October 2026. Every Roblox name below is in the vault's API snapshot.
- **Unverified** marks the places where no official page settled the question.

---

## 1. Sizing strategy: Offset at the reference plus one Fit scale

| Choice | Used for | Why |
|---|---|---|
| **Offset at the reference resolution** (1920 x 1080 by default) | Every size and position | Keeps the design's proportions exactly; squares stay square |
| **One `UIScale` named `Fit` on the root** | Scaling to the device | Scales sizes, stroke thickness and corner radius together ([[Layout - Scale Offset and Constraints]]) |
| **Scale** | Figma `SCALE` constraints; stretch (`LEFT_RIGHT`, `TOP_BOTTOM`) as Scale 1 with a negative Offset; full-screen roots | Places where Figma itself says "proportional" |

The `Fit` value works like this:
- It is `min(area.X / 1920, area.Y / 1080)`.
- It is clamped between `12 / smallest TextSize` (so text never draws below 12 px) and 1.4.
- It is never larger than the panel can fit in the safe area with a 16 px margin.

When fitting forces the scale under the text floor, the screen needs a phone arrangement ([[Responsive UI for Phone Tablet Console and PC]]).

---

## 2. Node types

- **`FRAME`, `COMPONENT`, `INSTANCE`, `GROUP`** become `Frame`. A `scroll_` name gives a `ScrollingFrame` and a `btn_` name gives a `TextButton`.
- **`RECTANGLE`** becomes `Frame`, or `ImageLabel` when it has an image fill.
- **`ELLIPSE`** becomes a `Frame` with `UICorner` at `UDim.new(0.5, 0)`. That is a true circle only when width equals height, so export ovals and arcs as images.
- **`TEXT`** becomes `TextLabel`, or `TextButton` for `btn_` names.
- **`VECTOR`, `BOOLEAN_OPERATION`, `STAR`, `LINE`, `REGULAR_POLYGON`** and anything named `img_` become an `ImageLabel` placeholder. The node is exported as one PNG and its children are not rebuilt.
- **Instances** keep their `componentId` and their `VARIANT` component properties as attributes (`FigmaComponentId`, `Variant_State`, `Variant_Role`).

---

## 3. Position, size, rotation and constraints

Positions are the child's `absoluteBoundingBox` minus the parent's. With `P` as the parent width, `x` and `w` as the child's position and width:

| `constraints.horizontal` (`vertical` alike) | `AnchorPoint.X` | `Position.X` | `Size.X` |
|---|---|---|---|
| `LEFT` (`TOP`) | 0 | `(0, x)` | `(0, w)` |
| `RIGHT` (`BOTTOM`) | 1 | `(1, -(P - x - w))` | `(0, w)` |
| `CENTER` | 0.5 | `(0.5, x + w/2 - P/2)` | `(0, w)` |
| `LEFT_RIGHT` (`TOP_BOTTOM`) | 0 | `(0, x)` | `(1, -(P - w))` |
| `SCALE` | 0 | `(x/P, 0)` | `(w/P, 0)` |

**Rotation.**
- `absoluteBoundingBox` surrounds the *rotated* node, so it is bigger than the node. Request `geometry=paths` to get the node's real `size` and `relativeTransform`; otherwise the converter solves the size from the box.
- Roblox rotates around the element's centre, so rotated nodes are anchored at 0.5, 0.5.
- `Rotation` is the negative of Figma's angle: Figma counts counter-clockwise, Roblox counts clockwise.
- The REST `rotation` field has no documented unit; observed exports look like radians **(unverified)**. `relativeTransform` removes the doubt.

---

## 4. Auto layout

- `layoutMode` `HORIZONTAL` or `VERTICAL` becomes a `UIListLayout`:
  - `FillDirection` to match;
  - `SortOrder = LayoutOrder`;
  - children numbered 10, 20, 30 in Figma order.
- `itemSpacing` becomes `UIListLayout.Padding`. The four `padding*` fields become a `UIPadding`.
- `primaryAxisAlignItems` `MIN`, `CENTER`, `MAX` set the main-axis alignment.
- `SPACE_BETWEEN` becomes `HorizontalFlex` or `VerticalFlex` set to `SpaceBetween`, with zero `Padding`.
- `counterAxisAlignItems` sets the cross alignment. `BASELINE` becomes `Center`.
- `layoutWrap` `WRAP` becomes `UIListLayout.Wraps`. There is one `Padding`, so keep `counterAxisSpacing` equal to `itemSpacing`.
- Child `layoutSizingHorizontal` and `layoutSizingVertical`:
  - `FIXED` is an Offset size;
  - `HUG` is `AutomaticSize` on that axis, starting from 0;
  - `FILL` on the main axis is a `UIFlexItem` with `FlexMode` `Fill`;
  - `FILL` on the cross axis is `UIFlexItem.ItemLineAlignment` `Stretch`.
- `layoutPositioning` `ABSOLUTE` children stay on the frame. The flowing children move into an inner `Flow` frame that holds the layout.
- `GRID` auto layout is placed absolutely, with a warning. Rebuild it with `UIGridLayout`.

---

## 5. Fills and gradients

- **`SOLID`** sets `BackgroundColor3`. Transparency is `1 - colour alpha x paint opacity x layer opacity`.
- **Multiple fills:** the top visible fill wins. Layer extra frames or export the node for the others.
- **`IMAGE`** gives an `ImageLabel`. The `scaleMode` maps as follows:
  - `FILL` to `Crop`;
  - `FIT` to `Fit`;
  - `TILE` to `Tile`, with `TileSize` set to the image size times `scalingFactor`;
  - `STRETCH` to `Stretch`. Crop the PNG instead of relying on `imageTransform`.
- **`GRADIENT_LINEAR`** gives a white background and a `UIGradient`:
  1. Convert the handles to pixels first. `gradientHandlePositions` are normalised to the box, and skipping this step gets every diagonal wrong on non-square boxes.
  2. `Rotation = atan2(dy, dx)` in degrees, y down. Roblox measures clockwise from left to right.
  3. Remap the stops. Roblox spreads the gradient between the box edges along that angle, while Figma pins it to the handles. Project the corners onto the axis and rescale each stop. This is exact at 0, 90, 180 and 270 degrees and close at other angles **(compare screenshots)**.
  4. A `ColorSequence` holds 2 to 20 keypoints and must start at 0 and end at 1. The `UIGradient` page recommends 6 or fewer. Stop alpha becomes `UIGradient.Transparency`.
- **`GRADIENT_RADIAL`** becomes `UIGradient.Type` `Elliptical`:
  - its radii are half the width and height, which matches Figma's default radial;
  - `Offset` moves the centre and `Scale` grows the radii;
  - `Radial` uses (width + height) / 4 and ignores `Rotation`.
- **`GRADIENT_ANGULAR`** becomes `Conical`, which sweeps clockwise and uses `Rotation` as its start angle. **`GRADIENT_DIAMOND`** becomes `Elliptical`.
- The `UIGradient.Type` property is flagged not browsable on its engine page, so set it inside `pcall`. The gradient falls back to `Linear` where the property is unavailable.

```lua
--!strict
-- Figma linear gradient handles (normalised 0..1) -> UIGradient.Rotation in degrees.
local function figmaGradientRotation(start: Vector2, finish: Vector2, boxSize: Vector2): number
	local delta = (finish - start) * boxSize -- to pixels first; a box is rarely square
	if delta.Magnitude < 1e-6 then
		return 0
	end
	return math.deg(math.atan2(delta.Y, delta.X)) -- y-down, so clockwise is positive
end

-- (0, 0) -> (1, 1) on a 200 x 100 box is about 26.57 degrees, not 45
print(figmaGradientRotation(Vector2.zero, Vector2.one, Vector2.new(200, 100)))
```

---

## 6. Strokes, corners and effects

| Figma | Roblox |
|---|---|
| `strokes` + `strokeWeight` | `UIStroke` with `Color`, `Thickness`, `Transparency` |
| `strokeAlign` `INSIDE` / `CENTER` / `OUTSIDE` | `UIStroke.BorderStrokePosition` `Inner` / `Center` / `Outer`, with `ApplyStrokeMode` `Border` |
| Stroke on text | `UIStroke` with `ApplyStrokeMode` `Contextual`, which outlines the glyphs |
| `strokeJoin` | `UIStroke.LineJoinMode` `Miter` / `Bevel` / `Round` |
| `individualStrokeWeights`, `strokeDashes` | Divider frames for single sides, or an exported outline image |
| `cornerRadius` | `UICorner.CornerRadius` in Offset. Half the short side or more becomes `UDim.new(0.5, 0)`, a pill at any size. |
| `rectangleCornerRadii`, mixed | Per-corner `UICorner.TopLeftRadius`, `TopRightRadius`, `BottomRightRadius`, `BottomLeftRadius` (beta on the engine page). Or round every corner and cover the square side with a same-colour strip. |
| `DROP_SHADOW` | A transparent slot frame holds a 9-slice "Shadow" `ImageLabel` and the node. The shadow is offset by `offset`, grown by `radius + spread`, and tinted with `ImageColor3` and `ImageTransparency`. |
| `INNER_SHADOW` | An `Inner` `UIStroke` with some transparency, or a gradient overlay |
| `LAYER_BLUR`, `BACKGROUND_BLUR`, blend modes, masks | Bake into an image. A modal over the world can use a `BlurEffect` in `Lighting` for the scene behind it. |

Layer `opacity` multiplies into the node's own transparencies. To fade a whole group as one, use a `CanvasGroup` and its `GroupTransparency`. Each one costs a render texture, so add them only where a group really fades.

`clipsContent` becomes `ClipsDescendants`, which clips to the rectangle, not the rounded corner. When children reach a rounded corner, clip with a `CanvasGroup` that carries the same `UICorner`, or round the child too.

---

## 7. Text

| Figma `TypeStyle` | Roblox |
|---|---|
| `fontFamily` | `FontFace = Font.new("rbxasset://fonts/families/<Family>.json", weight, style)`. Families Roblox lacks map to a close one with a warning: Inter to Builder Sans, Poppins to Montserrat. |
| `fontWeight` | `Enum.FontWeight`: 100 `Thin`, 200 `ExtraLight`, 300 `Light`, 400 `Regular`, 500 `Medium`, 600 `SemiBold`, 700 `Bold`, 800 `ExtraBold`, 900 `Heavy`. The weight snaps to the nearest face the family ships; Builder Sans tops out at 800. |
| `fontSize` | `TextSize` at the reference resolution |
| `textAlignHorizontal` / `textAlignVertical` | `TextXAlignment` / `TextYAlignment` (`JUSTIFIED` becomes `Left`) |
| `lineHeightPx`, `lineHeightPercentFontSize` | `LineHeight` as a ratio of the font size, kept inside the documented 1.0 to 3.0 |
| `letterSpacing` | Keep default tracking; bake display lettering into an image if the spacing matters |
| `textCase` | Upper, lower and title case applied to the string; small caps use RichText `<sc>` |
| `textDecoration` | RichText `<u>` and `<s>` |
| `characterStyleOverrides` + `styleOverrideTable` | `RichText = true`, with `<font color size weight family>` runs and escaped text |
| `textAutoResize` | `WIDTH_AND_HEIGHT` is `AutomaticSize` XY; `HEIGHT` is wrapped with `AutomaticSize` Y; `NONE` is wrapped in a fixed box |
| `textTruncation` `ENDING` | `TextTruncate.AtEnd` |

`TextScaled` is not used. Fixed sizes under one device scale keep a type scale consistent, and `TextScaled` cannot be combined with `AutomaticSize`.

---

## 8. Order, visibility, variants, images

- **Order.** Figma `children` run bottom to top. With `ZIndexBehavior.Sibling`, each child gets `ZIndex` 1, 2, 3 in that order, reversed when `itemReverseZIndex` is set.
- **Visibility.** `visible: false` becomes `Visible = false`. The instance is still built, which suits hidden states and alternate pages.
- **Variants.** A `State` variant set becomes one component function whose state machine sets `Default`, `Hover`, `Pressed` and `Disabled`. Gamepad selection uses its own ring in `SelectionImageObject`. Pops tween a separate `Motion` `UIScale`, never the `Fit` one.
- **Images.** Image nodes get `Image = ""` and a `REPLACE_ME` comment naming the PNG. The manifest lists the export scale, which is 2x, lowered so the long side stays at or under 1024 px.
- **9-slice.** A `9s_name__N` layer exports a small source. Its `SliceCenter` is the inset times the export scale, and `SliceScale` is the inverse scale, so the corners draw at design size.

---

## Common mistakes

- Using normalised gradient handles directly: every diagonal gradient points the wrong way.
- Reading the size of a rotated node from `absoluteBoundingBox`.
- Treating `strokeAlign` as always centred: inside strokes eat into the box, outside strokes add to it.
- One `CornerRadius` for a header that has only its top corners rounded.
- Copying Figma `fontSize` 12 body text: it draws at about 4 px on a small phone.
- Mapping Hug to a fixed size, so translated text overflows.
- Expecting blur, inner shadow or blend modes to appear in game without baking them.
- Setting `UIGradient.Type` without a fallback in places where the property is unavailable.

## Checklist

- [ ] Sizes in Offset at the reference resolution, with one `Fit` `UIScale` per branch.
- [ ] Constraints converted to `AnchorPoint`, Position and Size per the table.
- [ ] Auto layout mapped to `UIListLayout`, `UIPadding`, `UIFlexItem` and `AutomaticSize`.
- [ ] Gradients: handles converted to pixels, stops remapped, 20 keypoints or fewer.
- [ ] Strokes carry `BorderStrokePosition`; text strokes use `Contextual`.
- [ ] Mixed corners, shadows and blurs handled with the stated workaround.
- [ ] Fonts are built-in families with snapped weights; `LineHeight` within 1 to 3.
- [ ] Images are placeholders with a manifest; no invented ids.

<!-- related:start -->
## Related
[[Debugging UI Layout and Input]] · [[UI Design Systems]] · [[Settings Menu Design for Roblox - Layout, Controls and Motion]] · [[Minimap and World Map UI - Projection, Rotation and Fog of War]] · [[Safe Areas and Insets]] · [[Accessibility]] · [[Virtualized Lists and Large Inventories]] · [[Localization]] · [[World-Space UI - BillboardGui and SurfaceGui]]
<!-- related:end -->
