---
tags: [resources, links, official-docs, type/reference, area/scripting, level/beginner, api/HttpService, api/BindableEvent]
---
# Official Docs - Scripting and Luau

The language and engine references for writing code: the Luau site and RFCs, the Creator Hub scripting guides, the engine API reference and Open Cloud. Part of the [[Resource Library Start Here]].

Every link below goes to a first-party source: the Roblox Creator Hub, official Roblox announcements, the Luau project or the Blender manual. 144 links.

## Client-server and security model

### Client-server runtime
- https://create.roblox.com/docs/projects/client-server
- https://create.roblox.com/docs/scripting/networking/client-server-model

### Official security docs
- https://create.roblox.com/docs/scripting/security/security-tactics
- https://create.roblox.com/docs/scripting/security/defensive-design
- https://create.roblox.com/docs/scripting/security/client-server-boundary
- https://create.roblox.com/docs/scripting/security/access-control
- https://create.roblox.com/docs/scripting/security/server-side-detection
- https://create.roblox.com/docs/cloud-services/secrets

### Rate limiting remotes
- https://create.roblox.com/docs/chat/examples/rate-limit-public-text-inputs

## Coroutines, task library and async

### task library
- https://create.roblox.com/docs/scripting/scheduler
- https://create.roblox.com/docs/reference/engine/libraries/task
- https://create.roblox.com/docs/reference/engine/classes/TaskScheduler
- https://devforum.roblox.com/t/task-library-now-available/1387845

### Coroutines
- https://create.roblox.com/docs/reference/engine/libraries/coroutine

### Yielding functions
- https://devforum.roblox.com/t/changes-to-coroutine-yield/156496

### RunService loops (Heartbeat, RenderStepped)
- https://create.roblox.com/docs/reference/engine/classes/RunService

### Cancelling threads
- https://create.roblox.com/docs/reference/engine/libraries/task#cancel

## Error handling and debugging

### Error & log APIs
- https://create.roblox.com/docs/reference/engine/classes/ScriptContext
- https://create.roblox.com/docs/reference/engine/classes/LogService
- https://create.roblox.com/docs/reference/engine/libraries/debug
- https://create.roblox.com/docs/reference/engine/globals/LuaGlobals

### Reading error messages & stack traces
- https://create.roblox.com/docs/production/analytics/error-report
- https://devforum.roblox.com/t/announcing-studio-deep-links-on-stack-traces-for-server-logs/4953062

## Events, signals and connections

### Events
- https://create.roblox.com/docs/scripting/events
- https://create.roblox.com/docs/scripting/events/deferred
- https://create.roblox.com/docs/reference/engine/datatypes/RBXScriptSignal

### Property changed signals
- https://create.roblox.com/docs/reference/engine/classes/Object

### Custom events with BindableEvents
- https://create.roblox.com/docs/scripting/events/bindable

### Deferred vs immediate events
- https://devforum.roblox.com/t/beta-deferred-lua-event-handling/1240569
- https://devforum.roblox.com/t/deferred-engine-events-rollout-update/2723113

## Luau language

### Type system & modes
- https://luau.org/typecheck
- https://luau.org/types/
- https://luau.org/types/basic-types/
- https://luau.org/getting-started
- https://create.roblox.com/docs/luau/type-checking
- https://devforum.roblox.com/t/luau-type-checking-release/878947
- https://luau-lang.org/typecheck

### Generics & type packs
- https://luau.org/types/generics
- https://luau.org/typecheck/generics
- https://devforum.roblox.com/t/luau-recap-november-2021/1574544
- https://luau.org/news/2021-11-29-luau-recap-november-2021/

### Type functions & RFCs
- https://rfcs.luau.org/
- https://rfcs.luau-lang.org
- https://rfcs.luau.org/support-for-generic-function-types-in-user-defined-type-functions.html
- https://github.com/luau-lang/rfcs
- https://github.com/luau-lang/luau

### Language reference
- https://create.roblox.com/docs/luau
- https://create.roblox.com/docs/luau/functions
- https://create.roblox.com/docs/luau/metatables
- https://create.roblox.com/docs/luau/native-code-gen
- https://luau.org/syntax
- https://luau.org/library
- https://luau.org/performance
- https://luau.org/lint
- https://luau.org/sandbox
- https://roblox.github.io/lua-style-guide/

### Variables, scope & locals
- https://create.roblox.com/docs/luau/scope
- https://create.roblox.com/docs/luau/variables

### Tables & arrays
- https://create.roblox.com/docs/luau/tables
- https://create.roblox.com/docs/tutorials/fundamentals/coding-5/landing

### Dictionaries & iteration
- https://create.roblox.com/docs/tutorials/fundamentals/coding-5/intro-to-dictionaries

### String manipulation & interpolation
- https://rfcs.luau.org/syntax-string-interpolation.html
- https://create.roblox.com/docs/luau/strings
- https://devforum.roblox.com/t/string-interpolation-available-for-studio/2127058
- https://luau.org/news/2023-02-02-luau-string-interpolation/

### Buffers
- https://create.roblox.com/docs/reference/engine/libraries/buffer
- https://devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894

### if-expressions & compound operators
- https://create.roblox.com/docs/luau/operators
- https://rfcs.luau.org/syntax-compound-assignment.html

### Luau vs Lua 5.1 differences
- https://devforum.roblox.com/t/luau-recap-june-2020
- https://luau.org/compatibility

## OOP and module design

### Module APIs & encapsulation
- https://create.roblox.com/docs/scripting/module

## Open Cloud and external APIs

### HttpService
- https://create.roblox.com/docs/cloud-services/http-service
- https://create.roblox.com/docs/reference/engine/classes/HttpService

### Open Cloud reference
- https://create.roblox.com/docs/open-cloud
- https://create.roblox.com/docs/reference/cloud
- https://create.roblox.com/docs/cloud/guides
- https://create.roblox.com/docs/cloud/reference/patterns
- https://create.roblox.com/docs/cloud/llms.txt
- https://create.roblox.com/docs/cloud/reference/features/luau-execution
- https://create.roblox.com/docs/cloud/guides/data-stores/request-handling
- https://create.roblox.com/docs/cloud/guides/data-stores/throttling

### In-engine Open Cloud
- https://create.roblox.com/docs/reference/engine/classes/OpenCloudService
- https://create.roblox.com/docs/reference/engine/classes/OpenCloudApiV1
- https://create.roblox.com/docs/cloud

### Auth & webhooks
- https://create.roblox.com/docs/cloud/auth/api-keys
- https://create.roblox.com/docs/cloud/auth/oauth2-overview
- https://create.roblox.com/docs/cloud/webhooks/webhook-notifications

### Secrets management
- https://create.roblox.com/docs/cloud-services/secrets
- https://create.roblox.com/docs/reference/engine/datatypes/Secret

### Data stores via Open Cloud
- https://create.roblox.com/docs/cloud/guides/data-stores
- https://devforum.roblox.com/t/data-stores-v2-open-cloud-apis-are-now-in-public-beta/3075752
- https://devforum.roblox.com/t/opencloud-ordered-datastores-public-beta/2269023
- https://devforum.roblox.com/t/announcing-datastore-apis-for-open-cloud/1736583
- https://create.roblox.com/docs/cloud/reference

### CI/CD with Open Cloud
- https://create.roblox.com/docs/cloud/open-cloud/usage-place-publishing

### Rate limits & errors
- https://create.roblox.com/docs/cloud/reference/rate-limits
- https://create.roblox.com/docs/cloud/open-cloud/open-cloud-error-handling

## Remote events and functions

### Core docs
- https://create.roblox.com/docs/scripting/events/remote
- https://create.roblox.com/docs/reference/engine/classes/RemoteEvent
- https://create.roblox.com/docs/reference/engine/classes/RemoteFunction
- https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent
- https://devforum.roblox.com/t/introducing-unreliableremoteevents/2724155

### Bindables
- https://create.roblox.com/docs/scripting/events/bindable
- https://create.roblox.com/docs/reference/engine/classes/BindableEvent
- https://create.roblox.com/docs/reference/engine/classes/BindableFunction

## Script types

### Script, LocalScript, ModuleScript
- https://create.roblox.com/docs/scripting/locations
- https://create.roblox.com/docs/reference/engine/enums/RunContext
- https://create.roblox.com/docs/scripting
- https://create.roblox.com/docs/scripting/module
- https://create.roblox.com/docs/reference/engine/classes/Script
- https://create.roblox.com/docs/reference/engine/classes/LocalScript
- https://create.roblox.com/docs/reference/engine/classes/ModuleScript

### Capabilities, sync & attributes
- https://create.roblox.com/docs/scripting/capabilities
- https://create.roblox.com/docs/scripting/sync
- https://create.roblox.com/docs/scripting/attributes

### Parallel Luau
- https://create.roblox.com/docs/scripting/multithreading
- https://create.roblox.com/docs/scripting/luau/parallel-luau
- https://devforum.roblox.com/t/parallel-luau-developer-preview/925304

### Project structure
- https://create.roblox.com/docs/resources/modules
- https://create.roblox.com/docs/resources/scripting-libraries

### Script execution order
- https://create.roblox.com/docs/reference/engine/classes/BaseScript

### require caching & cyclic requires
- https://create.roblox.com/docs/education/coding-6/intro-to-module-scripts

### Actors & parallel scripts
- https://create.roblox.com/docs/reference/engine/classes/Actor
- https://devforum.roblox.com/t/full-release-of-parallel-luau-v1/1836187

### Legacy vs RunContext scripts
- https://devforum.roblox.com/t/live-script-runcontext/1938784

## Services

### Service reference
- https://create.roblox.com/docs/scripting/services
- https://create.roblox.com/docs/reference/engine/classes/ServiceProvider
- https://create.roblox.com/docs/reference/engine/classes/Players
- https://create.roblox.com/docs/reference/engine/classes/RunService
- https://create.roblox.com/docs/reference/engine/classes/CollectionService
- https://create.roblox.com/docs/reference/engine/classes/ReplicatedStorage
- https://create.roblox.com/docs/reference/engine/classes/ServerScriptService
- https://create.roblox.com/docs/reference/engine/classes/ServerStorage
- https://create.roblox.com/docs/reference/engine

### Players & player lifecycle
- https://create.roblox.com/docs/reference/engine/classes/Player

### ReplicatedFirst & loading screens
- https://create.roblox.com/docs/reference/engine/classes/ReplicatedFirst
- https://create.roblox.com/docs/ui/customizing-loading-screens

### StarterGui, StarterPack, StarterPlayer
- https://create.roblox.com/docs/reference/engine/classes/StarterGui
- https://create.roblox.com/docs/players
- https://create.roblox.com/docs/projects/data-model

### ProximityPromptService
- https://create.roblox.com/docs/reference/engine/classes/ProximityPromptService

### Debris service
- https://create.roblox.com/docs/reference/engine/classes/Debris/MaxItems
- https://create.roblox.com/docs/reference/engine/classes/Debris
