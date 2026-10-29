---
tags: [reference, engine, collectionservice, api/CollectionService, type/reference, area/scripting, level/intermediate, api/GetInstanceAddedSignal]
---

# CollectionService - Engine Reference Card

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: connecting only `GetInstanceAddedSignal`.
> - Avoid: skipping cleanup on removal. Symptom: connections and tables leak after tagged objects are destroyed; disconnect in the...
> - Avoid: mixing client and server tagging on one instance.
> - Each tag system handles existing instances, new instances and removed instances.
> - Per-instance state is keyed by the instance and cleared on removal.
> - Gameplay-relevant tags are applied on the server.
>
> Cost: TL;DR ~150 tok · whole note ~1.2k tok. Read more: ## Members that matter · ## Limits and defaults · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Groups instances by string tags (and, newer, by live queries) so one script can drive many objects; see [[CollectionService]], [[CollectionService Patterns]] and [[Instances Attributes and Tags]].

## Members that matter

| Member | Kind | Type or signature | Default | Server/client notes | Yields? |
|---|---|---|---|---|---|
| AddTag | method | `(instance: Instance, tag: string) -> ()` | - | Both; no-op if already tagged; fires the added signal | no |
| RemoveTag | method | `(instance: Instance, tag: string) -> ()` | - | Both; fires the removed signal | no |
| HasTag | method | `(instance: Instance, tag: string) -> boolean` | - | Both | no |
| GetTags | method | `(instance: Instance) -> {string}` | - | Both; use HasTag for a single check | no |
| GetTagged | method | `(tag: string) -> {Instance}` | - | Both; snapshot, no guaranteed order | no |
| GetAllTags | method | `() -> {string}` | - | Both; tags currently in use in the DataModel | no |
| GetInstanceAddedSignal | method | `(tag: string) -> RBXScriptSignal` | - | Fires on tag add or when a tagged instance enters the DataModel | no |
| GetInstanceRemovedSignal | method | `(tag: string) -> RBXScriptSignal` | - | Fires on tag removal or when a tagged instance leaves the DataModel | no |
| TagAdded | event | `(tag: string)` | - | Tag goes from unused to used | - |
| TagRemoved | event | `(tag: string)` | - | Tag goes from used to unused | - |
| CreateCollection | method | `(query: string, root: Instance?) -> Collection` | root = nil | Live query set with OnAdded / OnRemoved callbacks | no |
| GetCollections | method | `(instance: Instance) -> {Collection}` | - | Reverse lookup; scans active collections | no |
| Instance:AddTag / HasTag / RemoveTag / GetTags | method | same as above, called on the instance | - | Convenience forms of the service calls | no |

Retired names and their replacements:
- `GetCollection(className)` -> `GetTagged(tag)`.
- `ItemAdded` / `ItemRemoved` -> `GetInstanceAddedSignal(tag)` / `GetInstanceRemovedSignal(tag)`.

## Limits and defaults

- Tags are plain strings; an instance can hold several, and all of them replicate together as one set.
- `GetTagged` and `GetAllTags` return arrays without a guaranteed order.
- The added signal does not fire for instances that already carried the tag before you connected, so pair it with one `GetTagged` pass.
- `CreateCollection` queries use the selector syntax shared with `Instance:QueryDescendants()`: `ClassName`, `#Name`, `.Tag`, `[Property = value]`, `[$Attribute]`, `>` and `>>`, `:has()` and `:not()`.
- A collection stays alive until `Collection:Destroy()` or until its root is destroyed; its callbacks are queued, not run synchronously.

## Replication and authority

- Tags set on the server replicate to clients and are saved with the place.
- Client-added tags stay local, and the next server tag change on that instance overwrites the whole tag set, dropping them.
- With streaming enabled, an instance that streams back in is re-synced from the server, so client tag edits on it can vanish.
- Treat tags as markers for behavior, not as trusted per-player state; clients can tag their own copies freely.

## Common mistakes

- Avoid: connecting only `GetInstanceAddedSignal`. Symptom: objects tagged before the script ran never get their behavior; loop `GetTagged` once as well.
- Avoid: skipping cleanup on removal. Symptom: connections and tables leak after tagged objects are destroyed; disconnect in the removed signal.
- Avoid: mixing client and server tagging on one instance. Symptom: client tags disappear the moment the server edits tags.
- Avoid: new code on `GetCollection` or `ItemAdded`. Symptom: deprecated APIs that only cover a few legacy classes.
- Avoid: calling `GetTags` just to check one tag. Symptom: extra table work every call; `HasTag` is the direct check.

## Checklist

- Each tag system handles existing instances, new instances and removed instances.
- Per-instance state is keyed by the instance and cleared on removal.
- Gameplay-relevant tags are applied on the server.
- Tag names live in one shared constants module.

Source: https://create.roblox.com/docs/reference/engine/classes/CollectionService and https://create.roblox.com/docs/studio/properties#instance-tags - verified 2026-10-29

<!-- related:start -->
## Related
[[Instance - Engine Reference Card]] · [[Animator - Engine Reference Card]] · [[RemoteEvent - Engine Reference Card]] · [[MessagingService - Engine Reference Card]] · [[Player - Engine Reference Card]] · [[Events Signals and Connections]] · [[Replication Rules]]
<!-- related:end -->
