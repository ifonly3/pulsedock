# App Store Localization Inventory

Generated on 2026-06-27 from the current `codex/app-store-polish` worktree after the current app/widget and SharedMetrics localization implementation. The Swift-source Han audit is now clean: `scripts/audit-localization.sh` exits `0` and reports no Chinese text remaining in Swift sources.

## Regeneration Commands

```bash
mkdir -p .build
scripts/audit-localization.sh 2> .build/localization-audit.txt
```

Expected current result: exit `0`.

The audit uses `rg` when available and falls back to a portable `find` + Perl Swift-source scan when `rg` is unavailable.

File-level aggregation:

```bash
rg --with-filename -n --pcre2 '\p{Script=Han}' Sources/PulseDockApp Sources/PulseDockWidget Sources/SharedMetrics --glob '*.swift' \
  | awk -F: '{ count[$1]++; if (!($1 in first) || $2 < first[$1]) first[$1]=$2; if ($2 > last[$1]) last[$1]=$2 } END { total=0; for (file in count) total+=count[file]; print "TOTAL\t" total; for (file in count) print count[file] "\t" first[file] "\t" last[file] "\t" file }' \
  | sort -nr
```

## Current Totals

The audit is line-based, not unique-string based. Final extraction should deduplicate localization keys, but the matching-line count is still useful for scheduling and review sizing.

Overall Swift Han-character matching lines: **0**.

| File | Matching lines | First | Last | Owner / category | Recommended batch |
| --- | ---: | ---: | ---: | --- | --- |
| None | 0 | - | - | Swift-source audit is clean | No remaining Swift extraction batch |

Source-area totals:

| Area | Matching lines |
| --- | ---: |
| `Sources/PulseDockApp` | 0 |
| `Sources/SharedMetrics` | 0 |
| `Sources/PulseDockWidget` | 0 |

## Completed Dashboard Slices

The previous `DashboardView.swift` findings are now behind localization resources. No dashboard slice currently reports Swift Han-character matches.

| Dashboard slice | Matching lines | Line range |
| --- | ---: | --- |
| Power page | 0 | - |
| History/alerts page | 0 | - |
| Shared dashboard/widget preview components | 0 | - |
| Helper text/functions | 0 | - |
| GPU/display page | 0 | - |
| Charts/status components | 0 | - |
| Settings/table components | 0 | - |

## Risk And Sequence

1. **Swift source audit is currently clear.** `Sources/PulseDockApp`, `Sources/PulseDockWidget`, and `Sources/SharedMetrics` all audit at zero Han-character matches.
2. **SharedMetrics remains compatibility-sensitive.** Keep Codable keys, decode aliases, stored JSON field names, and state/data identifiers unchanged in later cleanup.
3. **Xcode localization resources are included.** The project generator now declares `development_region = en`, `known_regions = [en, zh-Hans, Base]`, and includes app/widget `.xcstrings`, shared `SharedMetrics.strings`, and app/widget InfoPlist `.strings` resources.
4. **Screenshots remain the visible release gate.** The existing Chinese screenshot set is preserved under `docs/app-store/screenshots/zh-Hans/`. English screenshots under `docs/app-store/screenshots/en/` are still pending, and default screenshot validation should fail until the five English PNGs exist.

Suggested Track 1 implementation batches:

| Batch | Scope | Current count |
| --- | --- | ---: |
| 1A | Remaining `MetricSnapshot.swift` derived display strings | 0 |
| 1B | `DashboardView.swift` remaining page/component migration | 0 |
