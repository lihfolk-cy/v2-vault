--!nonstrict
-- LihFolk Systems: tiny TestEZ-compatible runner
-- Install: ServerScriptService/LihFolkTests/Runner (ModuleScript), with every
-- *.spec module in the same folder (Rojo maps Foo.spec.luau to "Foo.spec").
--
-- Run from the Studio command bar (edit mode is fine; specs only exercise pure
-- logic and never touch DataStores, MarketplaceService or PolicyService):
--   require(game.ServerScriptService.LihFolkTests.Runner)()
-- The command bar caches required modules: after editing a module, re-open
-- the place or clone the folder before running again.
--
-- The specs use the TestEZ subset describe / it / expect(...).to.equal /
-- .to.be.ok / .to.be.near / .to.throw / .to.be.a / .never, so they also run
-- unchanged under TestEZ's TestBootstrap.
-- Status: written for Studio, NOT yet run in Studio.

local function makeExpectation(value: any, negated: boolean)
	local e = {}
	local function check(condition: boolean, message: string)
		if negated then
			condition = not condition
			message = "NOT " .. message
		end
		if not condition then
			error(message, 3)
		end
	end
	e.to = e
	e.be = e
	e.been = e
	e.have = e
	function e.equal(expected: any)
		check(value == expected, `expected {tostring(expected)}, got {tostring(value)}`)
	end
	function e.ok()
		check(value ~= nil and value ~= false, `expected a truthy value, got {tostring(value)}`)
	end
	function e.near(expected: number, limit: number?)
		local tolerance = limit or 1e-7
		check(type(value) == "number" and math.abs(value - expected) <= tolerance, `expected {expected} +/- {tolerance}, got {tostring(value)}`)
	end
	function e.a(typeName: string)
		check(typeof(value) == typeName, `expected a {typeName}, got {typeof(value)}`)
	end
	e.an = e.a
	function e.throw(fragment: string?)
		local ok, err = pcall(value)
		local matches = not ok and (fragment == nil or string.find(tostring(err), fragment, 1, true) ~= nil)
		check(matches, `expected function to throw{if fragment then " '" .. fragment .. "'" else ""}`)
	end
	return setmetatable(e, {
		__index = function(_, key)
			if key == "never" then
				return makeExpectation(value, not negated)
			end
			error(`expect: unknown matcher '{tostring(key)}'`, 2)
		end,
	})
end

local function expect(value: any)
	return makeExpectation(value, false)
end

local function runSpec(module: ModuleScript, results: { any })
	local okRequire, specFn = pcall(require, module)
	if not okRequire or type(specFn) ~= "function" then
		table.insert(results, { name = module.Name .. " (load)", ok = false, err = tostring(specFn) })
		return
	end
	local path: { string } = { module.Name }
	local env = {}
	function env.describe(name: string, fn: () -> ())
		table.insert(path, name)
		local ok, err = pcall(fn)
		if not ok then
			table.insert(results, { name = table.concat(path, " > ") .. " (describe)", ok = false, err = tostring(err) })
		end
		table.remove(path)
	end
	function env.it(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		table.insert(results, { name = table.concat(path, " > ") .. " > " .. name, ok = ok, err = if ok then nil else tostring(err) })
	end
	env.expect = expect
	setmetatable(env, { __index = getfenv(specFn) })
	setfenv(specFn, env)
	local ok, err = pcall(specFn)
	if not ok then
		table.insert(results, { name = module.Name .. " (body)", ok = false, err = tostring(err) })
	end
end

return function(root: Instance?): (number, number)
	local folder = root or script.Parent
	local results = {}
	local specs = {}
	for _, child in folder:GetDescendants() do
		if child:IsA("ModuleScript") and string.sub(child.Name, -5) == ".spec" then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)
	for _, spec in specs do
		runSpec(spec, results)
	end
	local passed, failed = 0, 0
	for _, result in results do
		if result.ok then
			passed += 1
		else
			failed += 1
			warn(`[LihFolkTests] FAIL {result.name}: {result.err}`)
		end
	end
	print(`[LihFolkTests] {passed} passed, {failed} failed, {#specs} spec modules`)
	return passed, failed
end
