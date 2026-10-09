# E2 — standalone MT5 strategy EAs (research branch)

**Branch `research/bund-system6-unified-inputs` is isolated from `main`.** The standalone E2 journal desktop/web application has been removed on this branch. MT5 CSV exports remain in the EAs for backtest and independent analysis.

## Strategy sources

| Directory | EA | Status |
|---|---|---|
| `strategies/GoldSessionFade/` | `XAU_Session_Fade.mq5` | Existing strategy, rules unchanged |
| `strategies/CompressionBreakout/` | `Compression_Breakout_Long.mq5` | Existing strategy, rules unchanged |
| `strategies/EURJPYGotobi/` | `EURJPY_Gotobi.mq5` | Existing strategy, rules unchanged |
| `strategies/NQOpeningRange/` | `NQ_Opening_Range.mq5` | Existing System 5 research, rules unchanged |
| `strategies/BundDonchian/` | `Bund_Donchian_Breakout.mq5` | **New System 6 research candidate; not backtested/validated** |
| `strategies/EMAPullback/` | `EMA_Pullback_Long.mq5` | **Retained as legacy source**, not recommended for portfolio allocation |

EMA source is deliberately retained for historical reproducibility and because the Compression EA shares its MQL clock/state headers. Removing it outright would risk changing Compression behavior. **Do not attach EMA to the portfolio if retiring it.**

## Unified input dashboards

All EAs use grouped inputs for risk, strategy rules, execution safety, broker clock and reporting. Historical server UTC offsets are entered in **hours** rather than seconds/minutes:

- **Gold:** `InpBrokerUTCOffsetHours` (manual fixed-offset mode). Broker time profile file mode remains supported and unchanged.
- **Compression / legacy EMA:** `InpBrokerWinterUTCOffsetHours`, plus the existing fixed/US/EU broker clock mode. Summer is computed by the existing DST logic.
- **Gotobi:** `InpBrokerWinterUTCOffsetHours`, plus the existing fixed/EU/US DST selection.
- **NQ and Bund:** `InpServerUTCOffsetWinterHours` and `InpServerUTCOffsetSummerHours`, plus DST mode and verified-clock toggle.

**Migration:** old `.set` files and MT5 chart input snapshots containing `InpBrokerWinterUtcOffsetSeconds`, `InpBrokerWinterUTCMinutes`, or `InpBrokerUtcOffsetSeconds` **do not map to the renamed inputs**. Manually convert (seconds / 3600, minutes / 60) and verify the new fields before any testing/live use. Example: old 7200 seconds or 120 minutes becomes **2 hours**. The bundled Gotobi preset was migrated. The underlying offset values used by strategy code are mathematically unchanged when equivalent values are entered.

**Important:** input regrouping/renaming has not been validated by a native MT5 compiler or trade-by-trade historical comparison. Existing strategy rule constants and defaults were deliberately preserved, but a guarantee of identical execution cannot be made until that comparison passes.

## Backtesting System 6

Follow [Bund Donchian research setup and MT5 steps](strategies/BundDonchian/README.md). This 20/10 H1 Donchian breakout with a 2×ATR protective stop is an **independent hypothesis**, not the original publisher's verified rules. No backtest performance is claimed.

## Installation

Copy the **whole `strategies` tree** into `MQL5/Experts/E2/`, keeping shared dependencies. Open each `.mq5` in MetaEditor, press **F7**, and confirm zero errors. MT5 source packages do not include EX5 binaries. The Bund and NQ research systems default to **entries disabled**.

Exports are still available under **Terminal/Common/Files/E2/** by strategy. See [CSV export layout](docs/CSV_EXPORTS.md). The journal UI, launcher, packaging workflow and journal-only tests have been removed; trading, recovery, strategy exports and analysis scripts are independent of the journal UI.

## Regression checks

GitHub Actions runs portable strategy and reporting tests. These do **not** substitute for native MetaEditor compilation, broker-specific real-tick backtests or live forward testing. Preserve the current production branch/binaries until tests demonstrate equivalent trade behavior.
