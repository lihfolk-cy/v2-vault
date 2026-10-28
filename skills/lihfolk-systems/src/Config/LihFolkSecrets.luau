--!strict
-- LihFolk Systems: server-only config (EXAMPLE VALUES - replace with yours)
-- Install: ServerStorage/LihFolkSecrets (ModuleScript)
-- ServerStorage never replicates, so clients cannot read these codes.

local Secrets = {}

-- Codes are written normalised: A-Z and 0-9 only, 3-24 characters.
-- Times are unix seconds (UTC). DateTime.fromUniversalTime(y, m, d).UnixTimestamp helps.
Secrets.Codes = {
	codes = {
		RELEASE = { reward = { kind = "currency", currency = "Coins", amount = 500 } },
		SPOOKY2026 = {
			reward = { kind = "item", item = "SpeedPotion", count = 3 },
			startsAt = 1793491200, -- 2026-11-01 00:00 UTC
			expiresAt = 1794096000, -- 2026-11-08 00:00 UTC
		},
	},
	maxMisses = 5,
	missWindowSeconds = 120,
	lockoutSeconds = 300,
}

return Secrets
