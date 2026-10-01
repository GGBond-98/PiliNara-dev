# Merge resolution policy — PiliNara ← PiliPlus/ohos

The working tree at `D:\workspace\pilinara-ohos\PiliNara` is mid-`git merge` of
`ohosref/ohos` (the HarmonyOS-enabled PiliPlus branch, at `D:\workspace\PiliPlus`
branch `ohos`) into **PiliNara** `main`.

- Merge base: `32538c4d705c9f5c74747cd00bacdd061d4aed99`
- OURS  = PiliNara, pre-merge — read with `git show HEAD:<path>` (or
  `git show main:<path>`), or from the pristine copy `D:\workspace\PiliNara`
- THEIRS = PiliPlus ohos — read with `git show ohosref/ohos:<path>`, or from
  `D:\workspace\PiliPlus`
- BASE  = `git show 32538c4d7:<path>`

Helper to print just the conflicted hunks:
`pwsh -File tool_merge/showconf.ps1 <path>`

## The one rule

**This product is PiliNara.** Nara's product decisions, features, refactors,
branding and dependency choices WIN. The ohos side contributes *only*
HarmonyOS platform enablement. Never regress a Nara feature in order to make
ohos code fit — instead weave the ohos platform check into Nara's code.

`lib/harmony_adapt/` and `lib/media_kit_adapt/` already exist in the working
tree (they landed cleanly from the ohos side) and are the intended surface for
platform glue. `OS` comes from `package:os_type` (gap: Nara does not depend on
it yet — see pubspec policy below).

## Take OURS when the conflict is

- **Identity/branding**: `PiliNara` name, `com.example.pilinara`-style ids,
  GitHub URLs, release/update check endpoints, `Starfallan/PiliNara`.
  Only exception: the **HarmonyOS** bundle name must become
  `com.dev4harmony.pilinara` (required deliverable), and the Linux `.desktop`
  filename becomes `com.dev4harmony.pilinara.desktop`.
- A Nara-only feature, setting, UI change, refactor or dependency.
- Upstream PiliPlus code that Nara deliberately changed.

## Take THEIRS when the conflict is

- Pure HarmonyOS platform glue: imports of `package:PiliNara/harmony_adapt/*`
  or `package:PiliNara/media_kit_adapt/*`, `OS.isHarmony`, `Platform.isOhos`,
  `HarmonyChannel.*`, cutout / safe-area / decoration-bar handling,
  cross-device continuation, ohos permission or plugin call sites,
  ohos-specific `MediaQuery`/gesture corrections.
- ohos CI workflows, `.vscode` ohos tasks, `ohos/` DevEco project files.
- Additive ohos pubspec entries (ohos plugin forks, local path shims).

## Merge BOTH (very common)

When each side changed a *different concern* in the same region — e.g. Nara
added a bug fix in a function and ohos wrapped that function with a platform
guard, or ohos changed the wrapper while Nara changed the body. Keep Nara's
logic **and** apply the ohos guard/wrapper/listener. When in doubt, do this
rather than picking a side.

Concretely, a hunk whose THEIRS side is a rewritten function prologue
(`ListenableBuilder`, `_scaledBuilder`, an extra `if (OS.isHarmony)` branch)
and whose OURS side is a body change almost always means: adopt THEIRS'
structure and re-apply OURS' body change inside it.

## pubspec policy (Nara base + additive ohos)

Start from Nara's `pubspec.yaml` and add ONLY what HarmonyOS needs:

- `material_ui:` / `cupertino_ui:` as **path** deps on `packages/material_ui`
  and `packages/cupertino_ui` (local shims back to SDK built-ins, because the
  HarmonyOS Flutter SDK is 3.44.9 while Nara targets 3.47 where these became
  standalone pub packages). Keep the explanatory comment.
- `os_type: ^0.2.2` (provides `OS.isHarmony`)
- `connectivity_plus_ohos` (git `HelloZeroNick/connectivity_plus_ohos`, main)
- `saver_gallery: ^4.1.2`
- any other dep the ohos side added that is genuinely required by imported
  ohos code — verify by grepping the resolved sources, do not add speculatively.
- `environment: sdk` must accept the installed SDK; Nara's `flutter: 3.47.2`
  exact pin must be relaxed to `>=3.44.9` (installed OHOS SDK is 3.44.9).

Do **not** drop Nara-only dependencies. Do **not** wholesale-adopt PiliPlus'
dependency list.

## Never

- leave `<<<<<<<` / `=======` / `>>>>>>>` markers behind
- drop a Nara feature to make ohos code fit
- add unnecessary dependencies
- reformat or reorder unrelated code
- run any state-changing git command (`add`, `commit`, `checkout`, `stash`,
  `merge --abort`, …). Read-only git (`show`, `log`, `diff`, `status`) is fine.
  The orchestrator stages and commits.

## Done means

The file parses as valid Dart and contains no conflict markers, and the merge
kept both Nara's behaviour and the ohos platform support.
