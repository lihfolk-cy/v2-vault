---
tags: [core-concept, performance, memory, world-building]
---
# Instance Count

<!-- tldr:start -->
> [!tldr] TL;DR
> - Instances are cheap individually and expensive in bulk.
> - Invisible instances count. Welds, Attachments, empty Folders, disabled scripts, unused Values and hidden UI templates add up.
> - Copies multiply everything. A tree model with 30 parts placed 500 times is 15,000 instances.
> - Streaming reduces what the client holds, not what the server holds.
>
> Cost: TL;DR ~130 tok · whole note ~850 tok. Read more: ## Why it matters on Roblox · ## The nuance most people miss
<!-- tldr:end -->

**Instance count** is the number of objects in the DataModel: every Part, Attachment, Weld, Script, Sound, GuiObject, Value and Folder. Each one costs memory, adds to replication and join time, and is a candidate for engine work (property change tracking, physics, rendering, layout).

## Why it matters on Roblox

Instances are cheap individually and expensive in bulk. Large places with hundreds of thousands of instances join slowly, use more memory on phones (which then crash or get killed by the OS), and make every `GetDescendants` call slow. Cutting instances is often the single largest performance win available to an older project (measured in the reference project, which removed most of its instances with no visible change; see the case study below).

## The nuance most people miss

1. **Invisible instances count.** Welds, Attachments, empty Folders, disabled scripts, unused Values and hidden UI templates add up. A sword with 15 attachments and 12 welds is 27 instances before you see a single part.
2. **Copies multiply everything.** A tree model with 30 parts placed 500 times is 15,000 instances. Converting it to 2 MeshParts makes it 1,000.
3. **Streaming reduces what the client holds, not what the server holds.** The server still has everything in memory. See [[Streaming Radius]].
4. **Count is not the only cost: churn is.** Creating and destroying 200 parts a second (bullets, debris) costs more than 2,000 parts that sit still. That is what [[Object Pooling]] addresses.
5. **UI is instances too.** An inventory that builds 500 slot frames, each with 8 children, is 4,000 instances; a virtualized list shows 20 slots.

## Tiny example

```lua
-- Command bar: count instances by class to find the biggest buckets.
local counts = {}
for _, d in workspace:GetDescendants() do
	counts[d.ClassName] = (counts[d.ClassName] or 0) + 1
end
local list = {}
for class, n in counts do table.insert(list, { class, n }) end
table.sort(list, function(a, b) return a[2] > b[2] end)
for i = 1, math.min(10, #list) do print(list[i][1], list[i][2]) end
```

## Where this shows up

- [[Case Study - Instance Cleanup and Place Size]]: a real cleanup and its results.
- [[Case Study - Cutting a Million Instances]]: the animation-side version.
- [[Memory Budgets and Leaks]]: instance memory on phones.
- [[Developer Console and Stats]]: where to read counts live.
- [[Parts Unions and MeshParts]]: merging parts to cut counts.
- [[Virtualized Lists and Large Inventories]]: the UI fix.
- [[Case Study - Fast Join and Deferred Loading]]: join time and instance count.
- [[Foliage Props and Scatter]]: the biggest instance multiplier in most maps.
- [[Selection Editing and Bulk Tools]]: tools to find and remove waste.
- [[Hunting Memory Leaks Step by Step]]: instances that never get destroyed.
- [[Destruction and Fracture]]: debris as an instance spike.
- [[Tycoon Plots and Droppers End to End]]: dropped items as instance churn.

Related concepts: [[Draw Calls]], [[Frame Budget]], [[Object Pooling]], [[Streaming Radius]].

## Connected notes
<!-- auto-links:start -->
[[Triangle Budget]] · [[Skill - Roblox Performance Audit]] · [[Core Concepts Start Here]] · [[Art Budgets - Triangles Draw Calls Memory]] · [[Performance Fundamentals]] · [[Instances Attributes and Tags]]
<!-- auto-links:end -->
