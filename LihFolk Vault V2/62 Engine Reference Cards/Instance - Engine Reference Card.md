---
tags: [reference, engine, instance, api/Instance, type/reference, area/scripting, level/intermediate]
---

# Instance - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: indexing children directly in LocalScripts.
> - Avoid: keeping references after Destroy.
> - Avoid: parenting first, then setting many properties.
> - Parent new instances last.
> - Use WaitForChild with a timeout where absence is possible.
> - Clean up with Destroy and clear references; hook Destroying for teardown.
>
> Cost: TL;DR ~120 tok · whole note ~1.3k tok. Read more: ## Members that matter · ## Replication and authority · ## Common mistakes · ## Checklist
<!-- tldr:end -->

The base class of every object in the data model, providing hierarchy, lifecycle, attributes and tags; see [[Instance]], [[WaitForChild]], [[Destroying]] and [[CollectionService]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| Name | prop | string | - | Max 100 characters | No |
| Parent | prop | Instance | nil for Instance.new | Locked after Destroy | No |
| Archivable | prop | boolean | - | false makes Clone return nil | No |
| ClassName | prop | string | - | Read only; exact class without inheritance | No |
| Clone | method | () -> Instance | - | Copy has Parent nil; skips non-Archivable descendants | No |
| Destroy | method | () -> () | - | Parent nil, Parent locked, connections dropped, recursive | No |
| ClearAllChildren | method | () -> () | - | Destroys all children | No |
| FindFirstChild | method | (name: string, recursive: boolean = false) -> Instance? | - | nil when missing | No |
| FindFirstChildOfClass / FindFirstChildWhichIsA | method | (className: string, ...) -> Instance? | - | Exact class vs IsA match | No |
| FindFirstAncestor / FindFirstAncestorWhichIsA | method | (name or className) -> Instance? | - | Walk upward | No |
| FindFirstDescendant | method | (name: string) -> Instance? | - | Search all descendants | No |
| WaitForChild | method | (childName: string, timeOut: number?) -> Instance? | - | Key for client code; nil after a timeout | Yes |
| GetChildren / GetDescendants | method | () -> {Instance} | - | Snapshot arrays | No |
| IsA | method | (className: string) -> boolean | - | Respects inheritance | No |
| IsDescendantOf | method | (ancestor: Instance) -> boolean | - | Cannot test removal by passing nil | No |
| SetAttribute / GetAttribute | method | (name, value) -> () / (name) -> Variant | - | nil removes an attribute | No |
| GetAttributeChangedSignal | method | (attribute: string) -> RBXScriptSignal | - | One attribute | No |
| GetPropertyChangedSignal | method | (property: string) -> RBXScriptSignal | - | One property | No |
| AddTag / RemoveTag / HasTag / GetTags | method | (tag: string) | - | Server tag changes overwrite client-added tags | No |
| QueryDescendants | method | (selector: string) -> Instances | - | Selector-based search | No |
| ChildAdded / DescendantAdded | event | (child) / (descendant) | - | Hierarchy watchers | - |
| AttributeChanged | event | (attribute: string) | - | Any attribute, including removal | - |
| Destroying | event | () | - | Fires as Destroy runs; after a yield the instance is already parented to nil | - |
| AncestryChanged | event | (child, parent) | - | Use Destroying to detect Destroy | - |
| Remove | method | () -> () | - | Deprecated: use Destroy | No |

## Limits and defaults

- Name: at most 100 characters.
- Attribute names: up to 100 characters; letters and digits plus periods, hyphens, slashes and underscores; no spaces; the RBX prefix is reserved.
- Setting an attribute to an unsupported type throws an error.
- WaitForChild with no timeout prints a possible-infinite-yield warning after 5 seconds.

## Replication and authority

- A server-created instance replicates once it is parented under something that replicates, so set properties first and Parent last.
- Replication order from server to client is not guaranteed; client code should use WaitForChild.
- With streaming on, distant parts may not exist on the client at all.
- Tags replicate as a set: a server tag change overwrites tags a client added locally.

## Common mistakes

- Avoid: indexing children directly in LocalScripts. Symptom: intermittent nil errors on join; use WaitForChild.
- Avoid: keeping references after Destroy. Symptom: leaked memory and stale reads; set variables to nil.
- Avoid: parenting first, then setting many properties. Symptom: extra replication traffic; parent last.
- Avoid: attribute names with spaces or an RBX prefix. Symptom: SetAttribute errors.
- Avoid: Clone on a non-Archivable instance. Symptom: it returns nil.
- Avoid: the deprecated Remove method. Symptom: deprecation warnings; Destroy cleans up properly.

## Checklist

- [ ] Parent new instances last.
- [ ] Use WaitForChild with a timeout where absence is possible.
- [ ] Clean up with Destroy and clear references; hook Destroying for teardown.
- [ ] Prefer GetPropertyChangedSignal and GetAttributeChangedSignal over Changed with name checks.

Source: https://create.roblox.com/docs/reference/engine/classes/Instance, https://create.roblox.com/docs/reference/engine/classes/Object (verified 2026-10-29)

<!-- related:start -->
## Related
[[Instances Attributes and Tags]] · [[CollectionService - Engine Reference Card]] · [[BasePart - Engine Reference Card]] · [[Animator - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[Humanoid - Engine Reference Card]] · [[Model - Engine Reference Card]] · [[ParticleEmitter - Engine Reference Card]] · [[Players - Engine Reference Card]]
<!-- related:end -->
