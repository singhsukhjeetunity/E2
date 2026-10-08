# E2 — Gotobi fourth-system source release

Adds EURJPY Gotobi v1.14 alongside the three existing EAs. Selected defaults and supplied preset: 50-pip stop, 15:55 UTC entry, following-day 00:55 UTC exit, 200-pip safety TP, 0.23% equity risk, fixed cash disabled. Magic 420603, CSV enabled, Friday flattening enabled. Existing trio code and risk settings are unchanged.

Download **E2-Gotobi-v1.14-source.zip** below. It contains the EA and headers, a preset, and the installation guide. Copy its MQL5 contents into the trading terminal's data folder, compile with F7 in MetaEditor, attach to EURJPY M1, load the preset and verify the broker-clock inputs. The preset leaves clock verification false until configured. No compiled EX5 is included.

Detailed guide: `docs/GOTOBI_INSTALL.md` in the repository, or `INSTALL.md` in the zip. Trade CSVs import into the existing journal. Standalone modeled drawdown is not the combined E2 drawdown. Source costs and calendar limitations are documented in the guide. Portable strategy and journal regressions are checked; native compilation and broker execution still require the installation check.
