# Figma to Roblox property mapping

The contract for `tools/figma_to_roblox.py` and for hand builds from the Figma MCP. The vault note
`LihFolk Vault V2/05 UI and UX/Figma Property Mapping for Roblox UI.md` is the readable version; keep the two in step.

**Sources (checked 2026-10-29).**
- Figma REST field names and enum values:
  - https://developers.figma.com/docs/rest-api/file-node-types/ (FRAME, TEXT, VECTOR, ELLIPSE, INSTANCE, COMPONENT_SET)
  - https://developers.figma.com/docs/rest-api/file-property-types/ (Paint, ColorStop, Color, Effect, TypeStyle, LayoutConstraint, Rectangle)
  - https://developers.figma.com/docs/rest-api/files/ (global node properties: id, name, visible, type, rotation, boundVariables)
  - https://developers.figma.com/docs/rest-api/file-endpoints/ (`GET /v1/files/:key/nodes`, `GET /v1/images/:key`)
  - https://developers.figma.com/docs/rest-api/personal-access-tokens/ (the `X-Figma-Token` header)
- Roblox class, property and enum names: `LihFolk Vault V2/_tools/roblox_api.json` (every name in this file is in it).
- Roblox behaviour quoted below: create.roblox.com engine reference pages for `UIGradient`, `UICorner`, `UIStroke`, `TextLabel`, `ColorSequence` and `GradientType`.

Items marked **(unverified)** were not confirmed by an official page. The converter carries a flag or a warning for each.

## 0. The house sizing choice

**Offset at the design reference resolution, plus one `UIScale` named `Fit` on the root.**
- Every size and position is copied from Figma in pixels, at the frame's reference resolution (1920 x 1080 by default).
- One `UIScale` named `Fit` on the root scales the whole tree. Its value is `min(area.X / 1920, area.Y / 1080)`, clamped:
  - The floor is `12 / smallest authored TextSize`, so no text draws under 12 px.
  - The ceiling is 1.4.
  - A panel never grows past what fits inside the safe area minus a 16 px margin. When the fit and the text floor conflict, the fit wins and the screen needs a phone arrangement.

Why Offset and not Scale:
- **The vault says so.** `Layout - Scale Offset and Constraints` (section 4) and `lihfolk-ui` ("design units, not pixels") both use this pattern: author panels at one design resolution in Offset, with one clamped device `UIScale`.
- **Scale on both axes breaks.** Square icons stretch, and 1 px strokes turn into 0.6 px or 1.4 px.
- **Offset keeps proportions.** A `UIScale` multiplies sizes, `UIStroke` thickness and `UICorner` radius together, so everything stays in proportion.

Scale is still used where Figma itself says "proportional":
- the `SCALE` constraint;
- `LEFT_RIGHT` and `TOP_BOTTOM` stretch, written as Scale 1 plus a negative Offset;
- full-screen roots in `--screen` mode.

The purple settings reference note warns against "pixel-perfect Offset sizes". That means Offset with no scaler, which this choice does not use.

Screen frames (HUDs, `--screen`):
- The root is `UDim2.fromScale(1, 1)`.
- Each top-level child is anchored to its own constraint edge and gets its own `Fit` `UIScale`. A `UIScale` grows a child from its `AnchorPoint`, so edge-pinned HUD parts stay pinned.

## 1. Node types

| Figma `type` | Roblox class | Notes |
|---|---|---|
| `FRAME`, `COMPONENT`, `COMPONENT_SET`, `SECTION` | `Frame` | `ScrollingFrame` when the name starts `scroll_` |
| `GROUP` | `Frame` (transparent) | Children keep absolute placement inside its box |
| `RECTANGLE` | `Frame` | `ImageLabel` when it has an `IMAGE` fill |
| `ELLIPSE` | `Frame` + `UICorner` `UDim.new(0.5, 0)` | A circle when width equals height. Otherwise it is drawn as a pill, so export unequal ellipses and `arcData` arcs as images. |
| `TEXT` | `TextLabel` (`TextButton` for `btn_`) | See section 9 |
| `VECTOR`, `BOOLEAN_OPERATION`, `STAR`, `LINE`, `REGULAR_POLYGON` | `ImageLabel` placeholder | Exported as PNG; `Image = ""` with a `REPLACE_ME` comment |
| `INSTANCE` | Same as its frame type | `componentId` and `VARIANT` `componentProperties` become attributes (`FigmaComponentId`, `Variant_<Prop>`) |
| any node named `img_...` | `ImageLabel` | The whole subtree is flattened into one exported PNG |
| any node named `9s_...` | `ImageLabel`, `ScaleType.Slice` | See section 12 |
| any node named `btn_...` | `TextButton` (or `ImageButton` with an image) | `AutoButtonColor = false`, `Text = ""` on frame buttons |
| any node named `skip_...` | not generated | For annotations and redlines |

## 2. Geometry: `absoluteBoundingBox` to `Position` and `Size`

- Child position = child `absoluteBoundingBox.x/y` minus parent `absoluteBoundingBox.x/y`.
- Size = `width` and `height` in Offset.
- **Rotated nodes:** `absoluteBoundingBox` is the axis-aligned box *around* the rotated node, so it is larger than the node.
  - The converter uses the node `size` (returned with `geometry=paths`) when present.
  - Otherwise it solves the unrotated size from the box and the angle. Near 45 degrees it assumes a square and warns.
- **Rotation:**
  - Roblox rotates about the element's centre, so rotated nodes get `AnchorPoint (0.5, 0.5)` at the same visual centre.
  - `GuiObject.Rotation = -figmaDegrees`: Figma counts counter-clockwise as positive (plugin API docs), and Roblox counts clockwise as positive.
  - The angle comes from `relativeTransform` when present: `atan2(-m10, m00)` (Figma plugin API definition).
  - Without `relativeTransform` it comes from the REST `rotation` field. The REST docs give no unit. Responses seen on Figma's forum look like radians **(unverified)**. Use `--rotation-units deg` if your export disagrees.
- `ClipsDescendants` clips to the element's rectangle. Rotated content is not clipped reliably (see `ScreenGui Fundamentals`).

## 3. Constraints to `AnchorPoint`, `Position` and `Size`

`constraints.horizontal` is one of `LEFT`, `RIGHT`, `CENTER`, `LEFT_RIGHT`, `SCALE`. `constraints.vertical` is one of `TOP`, `BOTTOM`, `CENTER`, `TOP_BOTTOM`, `SCALE`.

In the table, `x` and `w` are the child's position and width in the parent and `P` is the parent width. The vertical axis works the same way.

| Constraint | `AnchorPoint` | `Position` | `Size` |
|---|---|---|---|
| `LEFT` / `TOP` | 0 | `(0, x)` | `(0, w)` |
| `RIGHT` / `BOTTOM` | 1 | `(1, -(P - x - w))` | `(0, w)` |
| `CENTER` | 0.5 | `(0.5, x + w/2 - P/2)` | `(0, w)` |
| `LEFT_RIGHT` / `TOP_BOTTOM` | 0 | `(0, x)` | `(1, -(P - w))` |
| `SCALE` | 0 | `(x/P, 0)` | `(w/P, 0)` |

The root of a panel is always centred: `AnchorPoint (0.5, 0.5)`, `Position (0.5, 0, 0.5, 0)`.

## 4. Auto layout

| Figma field | Roblox |
|---|---|
| `layoutMode` `HORIZONTAL` / `VERTICAL` | `UIListLayout.FillDirection` `Horizontal` / `Vertical`, `SortOrder = LayoutOrder`; children get `LayoutOrder` 10, 20, 30 in Figma order |
| `layoutMode` `GRID` | Absolute placement plus a warning; rebuild with `UIGridLayout` by hand |
| `itemSpacing` | `UIListLayout.Padding = UDim.new(0, itemSpacing)` |
| `paddingTop/Bottom/Left/Right` | `UIPadding.PaddingTop/Bottom/Left/Right` |
| `primaryAxisAlignItems` `MIN` / `CENTER` / `MAX` | Main-axis `HorizontalAlignment` (`Left`/`Center`/`Right`) or `VerticalAlignment` (`Top`/`Center`/`Bottom`) |
| `primaryAxisAlignItems` `SPACE_BETWEEN` | `UIListLayout.HorizontalFlex` (horizontal lists) or `VerticalFlex` (vertical lists) = `Enum.UIFlexAlignment.SpaceBetween`, `Padding` 0. Figma ignores `itemSpacing` in this mode. |
| `counterAxisAlignItems` `MIN` / `CENTER` / `MAX` | Cross-axis alignment |
| `counterAxisAlignItems` `BASELINE` | `Center` plus a warning |
| `layoutWrap` `WRAP` | `UIListLayout.Wraps = true`. One `Padding` serves both gaps, so a different `counterAxisSpacing` gets a warning. |
| child `layoutSizingHorizontal/Vertical` `FIXED` | Offset size |
| child sizing `HUG` | `AutomaticSize` on that axis, with the size on that axis set to 0 so the element can shrink as well as grow |
| child sizing `FILL` on the main axis | `UIFlexItem.FlexMode = Enum.UIFlexMode.Fill` |
| child sizing `FILL` on the cross axis | `UIFlexItem.ItemLineAlignment = Enum.ItemLineAlignment.Stretch` |
| legacy `layoutGrow` 1 / `layoutAlign` `STRETCH` | Read as `FILL` on the main / cross axis |
| child `layoutPositioning` `ABSOLUTE` | The flow children move into an inner `Flow` frame (it holds the `UIListLayout`), and the absolute child stays on the parent with constraint placement |
| frame's own `layoutSizingHorizontal/Vertical` `HUG` | `AutomaticSize` on the frame |
| `itemReverseZIndex` | `ZIndex` counts down instead of up |

## 5. Fills (`fills`: bottom to top; the converter uses the top visible paint)

| `Paint.type` | Roblox |
|---|---|
| `SOLID` | `BackgroundColor3` from `color` r, g, b (0..1 to 0..255). `BackgroundTransparency = 1 - color.a * paint.opacity * node.opacity`. |
| `GRADIENT_LINEAR` | `BackgroundColor3` white plus a `UIGradient`. See section 6. |
| `GRADIENT_RADIAL` | `UIGradient.Type = Enum.GradientType.Elliptical`. Its radii are half the width and height, which matches Figma's default radial. Centre shift goes to `Offset = (cx - 0.5, cy - 0.5)` and radius changes go to `Scale`. |
| `GRADIENT_ANGULAR` | `Enum.GradientType.Conical`; approximate, with a warning |
| `GRADIENT_DIAMOND` | `Elliptical`; approximate, with a warning |
| `IMAGE` | `ImageLabel`. `scaleMode`: `FILL` to `ScaleType.Crop`, `FIT` to `Fit`, `TILE` to `Tile` (set `TileSize` to the image size x `scalingFactor`), `STRETCH` to `Stretch` (`imageTransform` crops are ignored, so crop the PNG). |
| `EMOJI`, `VIDEO`, `PATTERN` | Export as an image |
| more than one visible fill | The top one is used. For the rest, layer extra frames or export the node as an image. |

`UIGradient.Type` is listed but marked not browsable on the engine page, so the converter sets it inside `pcall`. Where it is unavailable, the gradient draws as `Linear`. Per the `GradientType` page:
- `Radial` uses a radius of (width + height) / 4 and ignores `Rotation`.
- `Elliptical` uses half the width and half the height as its radii, and `Rotation` rotates the axes.
- `Conical` sweeps clockwise, and `Rotation` sets the starting angle.

## 6. Linear gradient maths

1. **Convert the handles to pixels.** `gradientHandlePositions[0]` and `[1]` are the start (stop 0) and end (stop 1), in normalised box space (0..1). Multiply them by the node's width and height first. Using the normalised values directly gets every diagonal wrong on non-square boxes.
2. **Rotation.** `UIGradient.Rotation = atan2(dy, dx)` in degrees, in y-down pixel space. Roblox measures `Rotation` clockwise from left to right, and y-down makes clockwise positive. Examples: top to bottom is 90; (0,0) to (1,1) in a 200 x 100 box is 26.565.
3. **Remap the stops.** Roblox spreads the sequence between the element's edges along the rotated axis, while Figma pins it to the handles.
   - Project the four box corners onto the axis to get `tmin` and `tmax`.
   - Map each stop at `position * handleLength` to `time = (t - tmin) / (tmax - tmin)`.
   - Clamp to 0..1 and add keys at 0 and 1 by sampling the edge colours.

   The corner projection matches Roblox exactly at 0, 90, 180 and 270 degrees. At other angles it is the documented "snap to the edges" behaviour as best understood **(unverified at odd angles; compare screenshots)**.
4. **Limits.**
   - A `ColorSequence` needs 2 to 20 keypoints, with the first at time 0 and the last at time 1 (ColorSequence docs). The converter resamples above 20.
   - The `UIGradient` page recommends 6 colour stops or fewer.
   - Stop alpha goes into `UIGradient.Transparency` as a `NumberSequence` of `1 - a`.

## 7. Opacity, visibility, order

- Node `opacity` multiplies into that node's own `BackgroundTransparency`, `TextTransparency` and `ImageTransparency`.
- A whole group fading together needs a `CanvasGroup` with `GroupTransparency`. The converter warns rather than adding one, because each `CanvasGroup` costs a render texture.
- `visible: false` becomes `Visible = false`. The instance is still built, which suits hidden states.
- Z-order: Figma `children` run bottom to top. Each sibling gets `ZIndex = index + 1` (the house uses `ZIndexBehavior.Sibling`). In auto layout, `LayoutOrder = (index + 1) * 10`.
- `blendMode` other than `PASS_THROUGH` or `NORMAL`, and `isMask`: there is no UI blend mode, so bake these into an image. For masks, `ClipsDescendants` or a `CanvasGroup` covers rectangles and rounded rectangles.

## 8. Strokes, corners, effects

| Figma | Roblox |
|---|---|
| `strokes` (top `SOLID`) + `strokeWeight` | `UIStroke`: `Color`, `Thickness`, `Transparency = 1 - a * opacity` |
| `strokeAlign` `INSIDE` / `CENTER` / `OUTSIDE` | `UIStroke.BorderStrokePosition` `Inner` / `Center` / `Outer`, with `ApplyStrokeMode = Border` on frames |
| stroke on `TEXT` | `UIStroke` with `ApplyStrokeMode = Contextual` (a glyph outline) |
| `strokeJoin` `MITER` / `BEVEL` / `ROUND` | `UIStroke.LineJoinMode` `Miter` / `Bevel` / `Round` |
| gradient stroke | First stop colour plus a warning. You can add a `UIGradient` under the `UIStroke` by hand **(unverified, check in Studio)**. |
| `individualStrokeWeights`, `strokeDashes` | `UIStroke` is uniform and solid. Use thin divider frames for single sides, or export the outline. |
| `cornerRadius` | `UICorner.CornerRadius = UDim.new(0, r)`. If `r >= min(w, h) / 2` it becomes `UDim.new(0.5, 0)` (a pill that stays round at any size). |
| `rectangleCornerRadii` [tl, tr, br, bl], mixed | Default: the largest radius on `CornerRadius`, plus a warning. With `--per-corner`: `UICorner.TopLeftRadius`, `TopRightRadius`, `BottomRightRadius`, `BottomLeftRadius` (UDim). The engine page marks these beta ("New UI Capabilities"); writing `CornerRadius` overwrites all four. Another workaround: round all corners, then cover the square side with a child strip the same colour. |
| `cornerSmoothing` | Plain radius |
| `DROP_SHADOW` | A transparent slot frame takes the node's place. Inside it go a 9-slice `ImageLabel` "Shadow" (`ZIndex` 1) and the node at `fromScale(1, 1)` (`ZIndex` 2). The shadow is offset by `offset`, grown by `radius + spread` on every side, tinted with `ImageColor3 = color` and `ImageTransparency = 1 - a`. The texture is one white soft shadow per corner radius and blur, listed in the manifest. |
| `INNER_SHADOW` | An `Inner` `UIStroke` with transparency, or a gradient overlay frame |
| `LAYER_BLUR`, `BACKGROUND_BLUR`, `TEXTURE`, `NOISE` | Bake into an exported image (`img_` prefix). For a modal over the 3D world, a `BlurEffect` in `Lighting` blurs the whole scene. |

## 9. Text (`TEXT.style`, a `TypeStyle`)

| Figma | Roblox |
|---|---|
| `characters` | `Text` (Lua-escaped) |
| `fontFamily` | `FontFace = Font.new("rbxasset://fonts/families/<Stem>.json", weight, style)`. The families below are built in; others map to a near look, with a warning. You can also upload the family as a font asset. |
| `fontWeight` 100..900 | `Enum.FontWeight` `Thin` 100, `ExtraLight` 200, `Light` 300, `Regular` 400, `Medium` 500, `SemiBold` 600, `Bold` 700, `ExtraBold` 800, `Heavy` 900. The value snaps to the nearest weight the family ships (ties go heavier), with a warning when it moves more than 50. |
| `italic` | `Enum.FontStyle.Italic` (only some families ship italics) |
| `fontSize` | `TextSize` at the reference resolution. Roblox `TextSize` is the line height in offsets; it matches Figma's px size closely, so compare screenshots. |
| `textAlignHorizontal` `LEFT` / `CENTER` / `RIGHT` / `JUSTIFIED` | `TextXAlignment` `Left` / `Center` / `Right` / `Left` (no justify) |
| `textAlignVertical` `TOP` / `CENTER` / `BOTTOM` | `TextYAlignment` `Top` / `Center` / `Bottom` |
| `lineHeightUnit` `PIXELS` + `lineHeightPx` | `LineHeight = lineHeightPx / fontSize`, clamped to the documented 1.0..3.0 |
| `lineHeightUnit` `FONT_SIZE_%` + `lineHeightPercentFontSize` | `LineHeight = percent / 100`, clamped |
| `lineHeightUnit` `INTRINSIC_%` (auto) | Default `LineHeight` 1 |
| `letterSpacing` | No tracking property on `TextLabel`: keep default tracking, or bake display lettering into an image |
| `textCase` `UPPER` / `LOWER` / `TITLE` | Transformed in the generated string. `SMALL_CAPS` uses the RichText `<sc>` tag. |
| `textDecoration` `UNDERLINE` / `STRIKETHROUGH` | RichText `<u>` / `<s>` |
| `characterStyleOverrides` + `styleOverrideTable` | `RichText = true`, with runs wrapped in `<font color size weight family>`, `<i>`, `<u>`, `<s>`. Text is escaped (`&lt;` and the others). |
| `textAutoResize` `WIDTH_AND_HEIGHT` | `AutomaticSize = XY`, no wrapping |
| `textAutoResize` `HEIGHT` | `TextWrapped = true`, `AutomaticSize = Y` |
| `textAutoResize` `NONE` | `TextWrapped = true`, fixed box |
| `textTruncation` `ENDING` (or `TRUNCATE`) | `TextTruncate = Enum.TextTruncate.AtEnd`; `maxLines` gets a warning (size the box instead) |
| gradient text fill | First stop colour plus a warning. A `UIGradient` under a `TextLabel` tints the glyphs. |

`TextScaled` is never emitted. The vault rule is fixed sizes, a device `UIScale`, and no `TextScaled` with `AutomaticSize`.

Built-in families, read from a local Studio install's `content/fonts/families` on 2026-10-29 (weights shipped):
- Builder Sans 100, 300-800
- Builder Extended 300, 400, 600-800
- Builder Mono 300, 400, 700
- Montserrat 100-900 with italics
- Nunito 200-400, 600-900 with italics
- Roboto 100, 300, 400, 500, 700, 900 with italics
- Source Sans Pro 200, 300, 400, 600, 700, 900 with italics
- Fredoka One 400
- Luckiest Guy 400
- Bangers 400
- Oswald 200-700
- Titillium Web 200, 300, 400, 600, 700, 900 with italics
- Ubuntu 300, 400, 500, 700 with italics
- Press Start 2P 400
- the rest of the list is in `ROBLOX_FAMILIES` in the converter.

Substitutes used for families Roblox lacks:
- Inter and SF Pro to Builder Sans
- Poppins and Gotham to Montserrat
- Lato to Nunito
- Helvetica and Arial to Arimo
- Fredoka and Baloo 2 to Fredoka One

## 10. Containers and clipping

- `clipsContent` true with children becomes `ClipsDescendants = true`. It clips the **rectangle**, not the `UICorner` shape.
- When painted children reach rounded corners, use a `CanvasGroup` with the same `UICorner`, or give the child its own matching corners (`ScreenGui Fundamentals`, "pocket" bug).
- `scroll_` frames become a `ScrollingFrame` with `CanvasSize = UDim2.new()`, `AutomaticCanvasSize` on the layout axis, a matching `ScrollingDirection` and `ScrollBarThickness` 6.

## 11. Components and variants to states

- A component set with a `State` variant (`Default`, `Hover`, `Pressed`, `Disabled`, `Selected`) becomes **one** Luau component function with a state machine (see `examples/FigmaThemeTokens.luau`). It is not five instances.
- The converter writes `Variant_State` and the other `VARIANT` properties as attributes on the instance, so a controller knows which variant was placed.
- Mapping the states:
  - `Hover` is driven by `MouseEnter`/`MouseLeave` and also by `SelectionGained`/`SelectionLost`.
  - `Pressed` is driven by `InputBegan`/`InputEnded` (mouse, touch, `ButtonA`).
  - `Disabled` sets `Active = false` with the disabled swatch plus a word or icon.
  - Gamepad focus is a separate ring in `SelectionImageObject`. The design must draw it; the Hover look alone is not enough.
- Pops and presses tween a child `UIScale` named `Motion`, never the `Fit` scale.

## 12. Images, 9-slice, export

- Every image node goes into the manifest (`--manifest`) with its `id`, a file name, the design size, the export scale and the pixel size.
- Export scale is 2x, lowered so the long side stays at or under **1024 px**, Roblox's image size cap. The images endpoint accepts `scale` 0.01 to 4.
- Image fills: download the original image (`GET /v1/files/:key/images` lists a URL per `imageRef`) rather than a render of the frame.
- Vectors and `img_` nodes: render with `GET /v1/images/:key?ids=<id>&format=png&scale=<s>`, with a transparent background, trimmed of empty edges.
- `9s_name__N` sets a 9-slice inset of N design px. Export a small copy (2N + 8 px each way) at scale k. Then:
  - `SliceCenter = Rect(N*k, N*k, (size-N)*k, (size-N)*k)`;
  - `SliceScale = 1/k`, so the corners draw at design size.
- Placeholders are `Image = ""` with `-- REPLACE_ME: upload <file>`. Never paste an asset id you did not upload yourself.
