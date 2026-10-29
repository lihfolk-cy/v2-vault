---
tags: [economy, simulation, python, agent-based, balancing, testing, design, math]
---
# Simulating an Economy Before Launch

<!-- tldr:start -->
> [!tldr] TL;DR
> - Avoid: Trusting absolute numbers -> Use the model for comparisons only
> - Avoid: Average player only -> Archetypes with session distributions
> - Avoid: No churn feedback -> Stuck-dependent churn
> - Archetypes with shares, sessions per day and session length distributions.
> - Explicit spending policy, simple enough to explain.
> - Churn that depends on being stuck.
>
> Cost: TL;DR ~130 tok · whole note ~6.8k tok. Read more: ## 3. The script · ## 5. Testing two changes · ## Common mistakes · ## Checklist
<!-- tldr:end -->

Spreadsheets model the average player. [[Balancing with Spreadsheets and Data]] shows how to lay out a balance sheet, and [[Economy Inflation Sinks and Faucets Math]] section 7 has a twenty-line Luau loop that computes gate times for three multipliers. Both are the right first tools. This note goes the next step: an **agent-based simulation** with a population of different players who join over time, play sessions of random length, spend by simple rules, roll for items, get stuck and quit. It catches problems that averages cannot: who holds the money, which archetype finishes your content in a week, how a sink you add changes item supply, and what a one-number config change does to churn.

The full simulation is below, in Python (standard library only), and it runs. Every number quoted from it in this note was produced by running it with the seed shown.

Source labels: **Roblox docs (as of October 2026)**, **measured in the reference project**, **rule of thumb**, and **simulated** for numbers produced by the script below.

---

## 1. Why agents, not averages

A spreadsheet row says "zone 5 takes 61 minutes". Real players differ in four ways that change the answer:

1. **Session length and frequency.** A casual player with one 12-minute session a day needs five days for a 61-minute gate. A grinder does it in one sitting. The same price is a gentle goal for one and a wall for the other.
2. **Spending behaviour.** Some save for the gate; some spend on rolls first. Rolling "too much" can stall progress, and that is visible only if you model the choice.
3. **Join date.** On day 30, your player base is a mix of people who joined on day 1 and on day 29. Aggregate metrics depend on that mix ([[Economy Telemetry and Balancing Live]] section 2).
4. **Churn feedback.** Players who are stuck quit more. That changes who is left, which changes every metric you will later read from live data.

An agent-based simulation represents each player as a small record with a state and a policy, steps time forward, and records metrics the same way your live telemetry will. It is not a prediction of reality. It is a way to find out **what your own numbers imply** before players do.

### What a simulation is good for, and what it is not

| Good for | Not good for |
|---|---|
| Relative comparisons: config A versus config B on the same seeds | Absolute predictions ("we will have 4,000 DAU") |
| Finding structural problems: walls, runaways, missing sinks | Fun, feel, social dynamics |
| Checking item supply from drop tables and luck | Exploits and dupes (they are not in your model) |
| Regression testing config changes in CI | Anything you did not model |

Rule of thumb: trust the direction and rough size of a difference between two runs; do not trust any single absolute number.

---

## 2. The model

The simulated game is a generic zone-and-upgrade game with rolls, close to many Roblox simulators and RNG games:

- **Ten zones.** Income per minute grows by 2.6x per zone; the gate out of a zone costs `3,000 * 3.0^zone`. So `p / g = 3.0 / 2.6 ≈ 1.15`: each zone takes about 15% longer than the last, before upgrades ([[Economy Inflation Sinks and Faucets Math]] section 1).
- **One upgrade track** per zone: +4% income per level (additive), cost `150 * 1.15^level` scaled by zone income. Players buy a level only if it pays back within 60 minutes ([[Pricing Curves and Upgrade Costs]] section 3).
- **Rolls.** Five rarities with weights 600, 300, 90, 9 and 1 (Mythic is 1 in 1,000), hard pity on Mythic at 800 rolls. A roll costs half a minute of the player's base income. Players set aside 25% of income for rolls ([[Drop Tables Rarity and Pity Systems]]).
- **Archetypes.** Casual (55%, 0.8 sessions a day, 12 minutes mean), regular (30%, 1.5, 25), grinder (12%, 2.5, 55), payer (3%, 2.0, 35, with a 2x income multiplier standing in for passes). Session length is exponentially distributed around the mean, which gives the long tail of very long sessions real games have.
- **Churn.** Every player has an 8% chance a day of quitting, plus 10% more on days they end "stuck": more than 60 minutes of play from the next gate.
- **Population.** 400 new players a day for 30 days.

Every one of those numbers is a guess you should replace with your own. The archetype shares and session lengths are the most important and the least known before launch; once live, take them from your analytics ([[Analytics and Funnels]]).

---

## 3. The script

Save as `econ_sim.py` and run with Python 3.9 or newer. A single run takes about ten seconds on a desktop; a five-seed comparison takes about a minute.

```python
"""Agent-based economy simulation for a zone-and-upgrade game with rolls.

Standard library only. Run:
  python econ_sim.py                                  baseline, day by day
  python econ_sim.py --set gate_growth=3.2            compare baseline vs a change (5 seeds)
  python econ_sim.py --set final_roll_share=0.8 --set days=30
"""
import argparse
import random
import statistics
from dataclasses import dataclass, field

# ---------------------------------------------------------------- config
# Everything a designer would tune lives here, mirroring the game's config module.
CONFIG = {
    "days": 30,
    "new_players_per_day": 400,
    "zones": 10,
    "income_base": 100.0,      # coins per minute in zone 0 at upgrade level 0
    "income_growth": 2.6,      # income multiplier per zone
    "gate_base": 3000.0,       # price of the gate out of zone 0
    "gate_growth": 3.0,        # price multiplier per gate
    "upgrade_base": 150.0,     # first upgrade price in a zone
    "upgrade_growth": 1.15,    # price multiplier per upgrade level
    "upgrade_bonus": 0.04,     # +4% income per upgrade level (additive)
    "roll_cost_share": 0.5,    # a roll costs this many minutes of current base income
    "roll_budget_share": 0.25, # players put this share of income aside for rolls
    "final_roll_share": 0.25,  # same, once in the final zone (raise it to model an endgame sink)
    "upgrade_payback_max": 60, # buy an upgrade only if it pays for itself within this many minutes
    # rarity ladder: (name, weight); weights sum to 1000, so Mythic is 1 in 1000
    "rarities": [("Common", 600), ("Rare", 300), ("Epic", 90), ("Legendary", 9), ("Mythic", 1)],
    "pity_mythic": 800,        # hard pity on the top tier, in rolls
    "archetypes": {            # share, sessions/day, minutes/session mean, payer multiplier
        "casual":  (0.55, 0.8, 12, 1.0),
        "regular": (0.30, 1.5, 25, 1.0),
        "grinder": (0.12, 2.5, 55, 1.0),
        "payer":   (0.03, 2.0, 35, 2.0),
    },
    "stuck_minutes": 60,       # if the next goal is further than this, churn risk rises
    "base_churn": 0.08,        # daily chance to quit, before frustration
    "stuck_churn": 0.10,       # extra daily chance to quit while stuck
}


@dataclass
class Player:
    pid: int
    kind: str
    sessions: float
    minutes: float
    mult: float
    joined: int
    zone: int = 0
    upgrades: int = 0
    coins: float = 0.0
    pity: int = 0
    roll_budget: float = 0.0
    items: dict = field(default_factory=dict)
    active: bool = True
    spent: float = 0.0


def income_per_min(cfg, p: Player) -> float:
    return cfg["income_base"] * cfg["income_growth"] ** p.zone * (1 + cfg["upgrade_bonus"] * p.upgrades) * p.mult


def gate_price(cfg, zone: int) -> float:
    return cfg["gate_base"] * cfg["gate_growth"] ** zone


def upgrade_price(cfg, p: Player) -> float:
    return cfg["upgrade_base"] * cfg["income_growth"] ** p.zone * cfg["upgrade_growth"] ** p.upgrades


def roll(cfg, p: Player, rng: random.Random, totals: dict) -> None:
    rar = cfg["rarities"]
    if p.pity >= cfg["pity_mythic"] - 1:
        name = rar[-1][0]
    else:
        pick = rng.random() * sum(w for _, w in rar)
        name = rar[-1][0]
        for n, w in rar:
            pick -= w
            if pick < 0:
                name = n
                break
    p.pity = 0 if name == rar[-1][0] else p.pity + 1
    p.items[name] = p.items.get(name, 0) + 1
    totals[name] = totals.get(name, 0) + 1


def play_minute(cfg, p: Player, rng: random.Random, flows: dict, totals: dict) -> None:
    gain = income_per_min(cfg, p) * rng.uniform(0.8, 1.2)
    p.coins += gain
    flows["faucet"] += gain
    at_end = p.zone >= cfg["zones"] - 1
    p.roll_budget += gain * cfg["final_roll_share" if at_end else "roll_budget_share"]
    # Spending policy: gate first, then an upgrade if it pays back fast enough, then rolls
    # from the roll budget (a player-chosen share of income, so rolling never stalls the gate).
    if p.zone < cfg["zones"] - 1 and p.coins >= gate_price(cfg, p.zone):
        cost = gate_price(cfg, p.zone)
        p.coins -= cost; p.spent += cost; flows["sink_gate"] += cost
        p.zone += 1
        return
    up = upgrade_price(cfg, p)
    payback = up / (income_per_min(cfg, p) * cfg["upgrade_bonus"] / (1 + cfg["upgrade_bonus"] * p.upgrades))
    if p.coins >= up and payback <= cfg["upgrade_payback_max"]:
        p.coins -= up; p.spent += up; flows["sink_upgrade"] += up
        p.upgrades += 1
        return
    roll_cost = income_per_min(cfg, p) / p.mult * cfg["roll_cost_share"]
    while p.roll_budget >= roll_cost and p.coins >= roll_cost:
        p.roll_budget -= roll_cost
        p.coins -= roll_cost; p.spent += roll_cost; flows["sink_roll"] += roll_cost
        roll(cfg, p, rng, totals)


def minutes_to_next_goal(cfg, p: Player) -> float:
    if p.zone >= cfg["zones"] - 1:
        return 0.0
    need = max(0.0, gate_price(cfg, p.zone) - p.coins)
    return need / income_per_min(cfg, p)


def gini(values) -> float:
    xs = sorted(v for v in values if v >= 0)
    n = len(xs)
    if n == 0 or sum(xs) == 0:
        return 0.0
    cum = sum((i + 1) * x for i, x in enumerate(xs))
    return (2 * cum) / (n * sum(xs)) - (n + 1) / n


def run(cfg, seed: int = 7, verbose: bool = True):
    rng = random.Random(seed)
    players: list[Player] = []
    totals: dict = {}
    pid = 0
    report = []
    kinds = list(cfg["archetypes"].items())
    for day in range(cfg["days"]):
        for _ in range(cfg["new_players_per_day"]):
            r, acc = rng.random(), 0.0
            for name, (share, sess, mins, mult) in kinds:
                acc += share
                if r <= acc:
                    break
            players.append(Player(pid, name, sess, mins, mult, day))
            pid += 1
        flows = {"faucet": 0.0, "sink_gate": 0.0, "sink_upgrade": 0.0, "sink_roll": 0.0}
        stuck = 0
        dau = 0
        for p in players:
            if not p.active:
                continue
            n_sessions = int(p.sessions) + (1 if rng.random() < p.sessions % 1 else 0)
            if n_sessions:
                dau += 1
            for _ in range(n_sessions):
                length = max(3, int(rng.expovariate(1 / p.minutes)))
                for _ in range(length):
                    play_minute(cfg, p, rng, flows, totals)
            is_stuck = minutes_to_next_goal(cfg, p) > cfg["stuck_minutes"]
            stuck += is_stuck
            if rng.random() < cfg["base_churn"] + (cfg["stuck_churn"] if is_stuck else 0):
                p.active = False
        active = [p for p in players if p.active]
        held = [p.coins / max(income_per_min(cfg, p) * 60, 1e-9) for p in active]
        sinks = flows["sink_gate"] + flows["sink_upgrade"] + flows["sink_roll"]
        fin = [p for p in active if p.zone >= cfg["zones"] - 1]
        row = {
            "day": day + 1,
            "dau": dau,
            "median_zone": statistics.median(p.zone for p in active) if active else 0,
            "hours_held_med": statistics.median(held) if held else 0,
            "sink_faucet": sinks / flows["faucet"] if flows["faucet"] else 0,
            "roll_share": flows["sink_roll"] / sinks if sinks else 0,
            "stuck_pct": 100 * stuck / max(dau, 1),
            "gini_wealth": gini(p.coins for p in active),
            "mythics": totals.get("Mythic", 0),
            "finisher_coin_share": (sum(p.coins for p in fin) / (sum(p.coins for p in active) or 1)),
        }
        report.append(row)
    if verbose:
        print(f"{'day':>3} {'DAU':>6} {'zone':>5} {'hrsHeld':>8} {'S/F':>5} {'roll%':>6} {'stuck%':>7} {'gini':>5} {'mythic':>7}")
        for r in report:
            print(f"{r['day']:>3} {r['dau']:>6} {r['median_zone']:>5} {r['hours_held_med']:>8.2f} "
                  f"{r['sink_faucet']:>5.2f} {100*r['roll_share']:>6.1f} {r['stuck_pct']:>7.1f} "
                  f"{r['gini_wealth']:>5.2f} {r['mythics']:>7}")
        done = [p for p in players if p.zone >= cfg["zones"] - 1]
        print(f"players reached final zone: {len(done)} of {len(players)}")
        live = [p for p in players if p.active]
        held_total = sum(p.coins for p in live) or 1
        fin = [p for p in live if p.zone >= cfg["zones"] - 1]
        print(f"active finishers: {len(fin)} of {len(live)}, holding "
              f"{100 * sum(p.coins for p in fin) / held_total:.1f}% of all coins")
        for kind in cfg["archetypes"]:
            ks = [p for p in players if p.kind == kind]
            print(f"  {kind:8} n={len(ks):5} median zone={statistics.median(p.zone for p in ks)} "
                  f"still active={sum(p.active for p in ks)}")
    return report


def compare(cfg, change: dict, seeds=range(5)):
    """Run baseline and changed config on the same seeds and compare day-30 metrics."""
    base_rows, new_rows = [], []
    changed = {**cfg, **change}
    for s in seeds:
        base_rows.append(run(cfg, s, verbose=False)[-1])
        new_rows.append(run(changed, s, verbose=False)[-1])
    print(f"change: {change}")
    for key in ("dau", "median_zone", "hours_held_med", "sink_faucet", "stuck_pct", "mythics",
                "finisher_coin_share"):
        b = statistics.mean(r[key] for r in base_rows)
        n = statistics.mean(r[key] for r in new_rows)
        pct = 100 * (n - b) / b if b else 0
        print(f"  {key:15} base={b:10.2f} new={n:10.2f} ({pct:+.1f}%)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                    help="numeric config override; with any --set, runs a baseline comparison")
    args = ap.parse_args()
    change = {}
    for item in args.set:
        key, value = item.split("=", 1)
        if key not in CONFIG:
            raise SystemExit(f"unknown config key: {key}")
        change[key] = type(CONFIG[key])(float(value)) if isinstance(CONFIG[key], int) else float(value)
    if change:
        compare(CONFIG, change)
    else:
        run(CONFIG)
```

### Design choices in the code

- **One minute is the time step.** Fine enough for gates and rolls, coarse enough to run 12,000 players for 30 days in seconds. Combat, kill timing and anything sub-minute is folded into "income per minute with ±20% noise".
- **Spending policy is explicit and simple.** Gate first, then an upgrade if it pays back within an hour, then rolls from a separate roll budget. Real players are messier, but a simple greedy policy is what guides and experienced players converge on, and a simple policy makes results explainable.
- **Rolls from a budget, not from all spare coins.** An earlier version of this script let players roll with any coins above a reserve. Non-paying players then stalled in zone 0 for the whole month, spending everything on rolls (simulated). That is a real design risk, not just a modelling bug: if rolls are the most exciting thing on screen and cost the same currency as progress, some players will roll their progress away. Games guard against it with separate roll currency, roll cost that scales slowly, or a nudge toward the gate.
- **Same seeds for comparisons.** `compare` runs baseline and change on seeds 0 to 4, so differences come from the change, not from luck ([[Probability and Statistics for Designers]]).
- **Metrics match live telemetry.** Hours of income held, sink to faucet ratio, stuck share and supply of the top item are the metrics in [[Economy Telemetry and Balancing Live]]. When the game is live, the same names on both sides make it possible to calibrate.

---

## 4. Reading the baseline

Running `python econ_sim.py` (seed 7) prints a row per day; day 30 reads (simulated):

| Metric | Day 30 |
|---|---|
| DAU | 3,997 |
| Median zone of active players | 3 |
| Median hours of income held | 0.30 |
| Sink / faucet ratio | 0.29 |
| Rolls as share of all sinks | 85% |
| Stuck share | 2.0% |
| Gini of coin balances | 0.92 |
| Mythics in the game | 2,006 |

And the per-archetype summary: casual players' median zone is 1, regulars 4, grinders and payers 9 (the final zone). 1,497 of 12,000 players reached the final zone within the month. Of 4,184 still-active players, 665 are in the final zone, and **they hold 99.3% of all coins** in the game.

What that says about this design:

1. **There is no endgame sink.** A sink to faucet ratio of 0.29 in a game where most active players are still progressing is a red flag. The cause is visible in the finisher line: players who reach the last zone keep earning at the highest income in the game and have nothing to spend on except the 25% they put into rolls. Their median hours of income held is about 5.4 versus 0.24 for everyone else (simulated, measured from the same run). On live data this would show up as "hours held, final zone" climbing every week ([[Economy Inflation Sinks and Faucets Math]] section 4).
2. **Grinders finish the content in under a month.** At 2.5 sessions of 55 minutes a day, grinders reach zone 9 well inside 30 days. If your update cadence is monthly, your most engaged players run out of content before the next update. That is the most useful single sentence a pre-launch simulation can give a team ([[Event Calendars and Content Planning]]).
3. **Casual players barely progress.** A median of zone 1 after a month for 55% of players means most of your audience never sees most of your zones. Either the early curve is too steep for short sessions, or that is acceptable because they churn for other reasons anyway. The simulation cannot decide which; it tells you to look.
4. **The wealth Gini of 0.92 is mostly structural.** In an exponential game, a player one zone ahead earns 2.6 times more, so balances are naturally concentrated. Gini across the whole population is not an exploit signal here; Gini within a progress band would be ([[Economy Telemetry and Balancing Live]] section 2).

---

## 5. Testing two changes

### Change A: steeper gates

`python econ_sim.py --set gate_growth=3.2` (five seeds, day 30 averages, simulated):

| Metric | Baseline | Gate growth 3.2 | Change |
|---|---|---|---|
| DAU | 4,037 | 3,847 | -4.7% |
| Median zone | 3 | 2 | -1 zone |
| Stuck share | 1.6% | 6.8% | about 4x |
| Mythics | 2,073 | 1,878 | -9.4% |

Raising price growth per zone from 3.0 to 3.2 looks small: each gate is about 7% more expensive per zone than before. But `p / g` goes from 1.15 to 1.23, and by the later zones gates take far longer. Stuck share roughly quadruples, and because stuck players churn more, DAU falls by about 5% within a month. Fewer players also means fewer rolls and fewer Mythics. A designer tuning gate prices in a spreadsheet would see "zone 8 takes longer"; the simulation shows "you lose one player in twenty".

### Change B: an endgame sink through rolls

Model a reason for finishers to spend: an endgame roll pool they put 90% of income into. `python econ_sim.py --set final_roll_share=0.9` (simulated):

| Metric | Baseline | Final roll share 0.9 | Change |
|---|---|---|---|
| Sink / faucet | 0.30 | 0.90 | about 3x |
| Finisher share of all coins | 99% | 95% | small |
| Mythics | 2,073 | 4,896 | +136% |

The sink works for coins: the ratio climbs to 0.90. But **the sink is also an item faucet**: Mythic supply more than doubles, because finishers now roll at top-zone income. In a game where Mythics are tradeable, this "fix" for coin inflation is a crash in Mythic prices ([[Player-Driven Trading Economies]] section 5). The better design is an endgame sink that does not mint the same items: a separate endgame pool with its own top tier, cosmetic upgrades, a prestige reset ([[Rebirth and Prestige System End to End]]), or fusion that consumes Mythics. Finisher coin share barely moves because they still hold their accumulated stock; a sink only changes flows from now on.

That second-order effect is the main argument for simulating at all: every sink and faucet is connected to something else, and a single-currency spreadsheet cannot show it.

---

## 6. Calibrating against reality

Before launch, the numbers are guesses. After launch, make the simulation agree with reality before trusting it for decisions:

1. **Replace archetypes with measured ones.** Cluster real players by sessions per day and session length from your analytics. Four clusters is plenty.
2. **Replace churn with measured retention.** Fit `base_churn` so simulated D1, D7 and D30 retention roughly match your dashboard; fit `stuck_churn` so the drop at your worst gate matches its funnel.
3. **Replay a known week.** Run the simulation with last month's config and compare time to afford per zone and sink to faucet with live telemetry. If they differ by more than about 25% (rule of thumb), find out why before using the model for the next change.
4. **Keep the config shared.** The simulation should read the same config file the game uses (exported to JSON from the spreadsheet pipeline, [[Data and Config Pipeline - Spreadsheets to Game]]), so a price changed in the game is automatically changed in the model.

**Measured in the reference project:** a difficulty pass changed cash income by a large factor (cash x0.55) while one system, the forge, stayed priced against the old income model. A simulation that reads all systems' prices from the same config would have flagged the forge track's payback as wildly out of line with the rest on the first run ([[Pricing Curves and Upgrade Costs]] section 5).

---

## 7. From script to CI regression test

A simulation earns most of its value when it runs automatically.

- **Golden numbers.** Save day-30 metrics for the current config with fixed seeds. In CI, rerun with the new config and fail when a key metric moves more than a threshold (rule of thumb: 10% for sink to faucet and stuck share, 20% for top-item supply) without a comment in the change explaining it ([[Code Pipeline - Rojo Git and CI]]).
- **Speed.** Ten seconds per run is fine for CI. If the model grows, reduce `new_players_per_day` for CI runs; relative comparisons survive smaller populations reasonably well.
- **Port only if you must.** Keeping the model in Python makes it easy to analyse with notebooks and charts. If your team wants it in Luau so it can `require` the real config modules, run it under a standalone Luau runtime in CI rather than in Studio, and keep the structure of this script: config table, player records, policy function, daily metrics. The short Luau loop in [[Economy Inflation Sinks and Faucets Math]] section 7 is a starting point.

---

## 8. Extending the model

Add only what a decision needs. Useful extensions, in rough order of value:

| Extension | Adds | Decision it informs |
|---|---|---|
| Multiple upgrade tracks with greedy buying | Track competition | Whether every track gets bought ([[Pricing Curves and Upgrade Costs]] section 5) |
| Event currency with expiry | Time-limited faucets and conversions | Conversion rate and caps ([[Currency Architecture - Soft Hard and Event Currencies]]) |
| Real drop tables imported from config | Exact item supply per day | Supply of tradeable items |
| A simple market | Prices from supply and holders | Effect of luck events on item value |
| Rebirths | Long-term loops and multiplier growth | Rebirth cost scaling |
| Payers buying boosts at moments of friction | Realistic purchase timing | Whether walls are monetising or just churning |

What not to add: combat simulation, physics, social behaviour. They multiply complexity without improving economy decisions; abstract them into income noise and churn.

---

## 9. When not to simulate

- **Cosmetic-only economies** with flat prices and no progression gates. A price list is enough.
- **Tiny prototypes** whose numbers will change completely next week. Simulate when the structure is stable and you are tuning numbers.
- **When you will not act on the result.** If the launch date and prices are fixed regardless, spend the time on telemetry instead ([[Economy Telemetry and Balancing Live]]).

---

## Common mistakes

| Mistake | How you spot it | Fix |
|---|---|---|
| Trusting absolute numbers | Launch DAU nowhere near the model | Use the model for comparisons only |
| Average player only | Model says fine; casual players churn | Archetypes with session distributions |
| No churn feedback | Model never shows walls costing players | Stuck-dependent churn |
| Different seeds per comparison | Differences that flip between runs | Same seeds for baseline and change |
| Prices typed into the model by hand | Model and game disagree after a patch | Read the game's config |
| Testing a sink without its side effects | Coin problem fixed, item market crashes | Track every flow the sink touches |
| Never calibrating | Model and live telemetry diverge silently | Replay a known week |
| Modelling everything | A slow, unexplainable model | Add only what a decision needs |

## Checklist

- [ ] Archetypes with shares, sessions per day and session length distributions.
- [ ] Explicit spending policy, simple enough to explain.
- [ ] Churn that depends on being stuck.
- [ ] Metrics named and computed like the live telemetry.
- [ ] Comparisons on identical seeds; several seeds averaged.
- [ ] Endgame flows checked: who holds the money on day 30.
- [ ] Every proposed sink checked for what it mints.
- [ ] Config read from the same source as the game.
- [ ] Calibrated against live data after launch; golden-number test in CI.

## See also
[[Economy Design Start Here]] · [[Currency Architecture - Soft Hard and Event Currencies]] · [[Pricing Curves and Upgrade Costs]] · [[Drop Tables Rarity and Pity Systems]] · [[Player-Driven Trading Economies]] · [[Economy Telemetry and Balancing Live]] · [[Economy Inflation Sinks and Faucets Math]] · [[Balancing with Spreadsheets and Data]] · [[Probability and Statistics for Designers]] · [[Rarity Ladders and Drop Pacing Math]] · [[Data and Config Pipeline - Spreadsheets to Game]] · [[Genre Playbook - Simulators]]

## Connected notes
<!-- auto-links:start -->
[[Faucets and Sinks]] · [[Expected Value]] · [[Economies and Currencies]] · [[Progression and Pacing Design]] · [[Progression Levels and Unlocks]] · [[Variance]]
<!-- auto-links:end -->
