# Lazy Loading + Boot Performance Plan — AIU Cyberdeck (Termux / proot-Ubuntu)

**Status:** plan only. Rev 2 — corrects rev 1's factual errors, folds in reviewer findings + measurements.
**Audience:** reviewing AI. Verify the claims in Part 1 before trusting the phasing in Part 4.

---

## PART 1 — CONTEXT (corrected; rev-1 errors flagged)

### 1.1 Environment

- proot-Ubuntu 26.04 inside Termux (Android). Phone, ~7.5 GB RAM, TTY only, phone flash storage.
- `$HOME` = `/root/home/shape` (not `/data/data/com.termux/files/home`).
- Editor: **neomacs 0.0.19**, `emacs-version` = **31.1**. GNU emacs 30.2 also installed, not the target.
- Login shell: Nushell (`/usr/local/bin/nu`).

### 1.2 Boot chain (verified)

```
init.el → tangle AIU-Frame.org → early-init.el + foundation-init.el
  foundation-init.el:
    1. straight bootstrap              → mark "straight-ready"
    2. org from straight
    3. leaf + leaf-keywords            → mark "core-ready"
    4. tangle + load cyberdeck-emacs.el → mark "loader-loaded"
    5. cyberdeck-emacs-boot            → mark "boot-end"
```

### 1.3 Repository

`/root/home/shape/Subnet/universe/galaxy/solar-system/planets/earth/computer-science/operating-systems/linux/text-editors/neomacs/Cyberdeck-Emacs/`

- `cyberdeck` — THE LOADER, an Org file, `#+auto_tangle: t`,
  `:header-args:emacs-lisp: :tangle ~/.config/emacs/cyberdeck-emacs.el`.
  Edit the Org source, never the tangled `.el`.
- `emacs-cyberdeck/` — 379 units.

### 1.4 Unit rules (verified)

A file is a unit iff: basename has **no dot** (dotted files are discarded before reading, loader `:1285`); not under `.git/` `admin/` `WIP/`; has a level-1 heading tagged `:EMACS_MECHANISM:`.

- Unit title = level-1 heading text, tags stripped (`:866`).
- Property drawer on the **line immediately after** the heading (`:875`), else silently detached.
- Drawer read for exactly three keys: `:ID:`, `:MM_PARENT:`, `:MM_ORDER:`. `:CATEGORY:` read by nothing.
- Chained units (`:MM_PARENT:`/`:MM_ORDER:`): parents first, siblings by float `:MM_ORDER:`.
- Chainless: sorted by path. (I converted all 130 to explicit `:MM_ORDER:` 9000+ so path moves don't reorder.)

### 1.5 Parts, tiers, cache

`--extract-parts` (`:1727`) → ordered `(:kind part|:package :body S)`.
`--unit-load` (`:2160`) → `loaded` (parts-hash hit, just `load` .elc) / `compiled` / `eval` (fallback).

Cache in `~/.config/emacs/.local/cache/module-el/`. Cache key (`:1817`) =
`sha256(salt + package-method + file-truename + unit-start-line)`.
Discovery index `~/.config/emacs/.local/cache/discovery-index.el`.

### 1.6 Package method

`cyberdeck-emacs-package-method` = `leaf` (`:46`).
**Already-existing lazy mechanism:** `cyberdeck-emacs-leaf-force-require` (`:79`), default `'auto` —
appends `:require t` only when the package has no deferring keyword
(`:bind :bind* :hook :mode :interpreter :magic :magic-fallback :commands :after`) and no explicit `:require`.
Docstring: *"unconditionally forcing `:require t` silently defeats `:leaf-defer` for every single package."*
The loader documents `:leaf-defer` at `:58`.

### 1.7 CORRECTION — leaf declarations DO load

Rev 1 claimed the 15 `(leaf …)` files had dotted basenames and therefore never loaded. **That was wrong.** All 15 have extensionless basenames, so all 15 are units and all 15 load at boot:

```
building-things/universal-launcher            files/…/files/emacs-mechanism-module
daily-editing/dmacro                          files/…/biomechanical-input-interface/cores/key-selection
files/org-fancy-priorities                    files/…/aiu-frame/inline-hashtag
reaching-outward/emacs-everywhere             shaping-the-tool/leaf
the-screen/center-lock                        the-screen/move-text
the-screen/pulsar                             the-screen/switch-window
under-the-hood/debug-adapter-protocol         under-the-hood/desktop-session-persistence
under-the-hood/flycheck
```

Only ~3 use `:require t`; the rest rely on `auto` + their own deferring keywords. So lazy-package
wiring exists and is mostly already honoured. **Phase B's expected payoff is small.**

### 1.8 CORRECTION — the 133 straight packages

Not declared in the tree. `foundation-init.el:70-75` puts **every directory** in
`~/.config/emacs/straight/build/` on `load-path` (133 dirs today), left over from earlier straight runs.
Consequence: every `require`/`load` probes those dirs in order; each probe is a syscall under proot.
This is a cheap suspect (reviewer point 3).

---

## PART 2 — MEASUREMENTS

### 2.1 Tier counts (warm boot, zero edits)

```
367 loaded      11 compiled      0 eval
sum: 747.1 s over 379 units
```

**No interpreted fallback.** Bytecode marker in `.elc` is `0x1f` = Emacs 31; loader is 31.1 →
reviewer point 4 (bytecode version mismatch) is **ruled out**.

### 2.2 Boot-end, warm, zero edits

```
foundation-start    0.00 s
straight-ready     21.03 s
core-ready         26.84 s
loader-loaded      28.48 s
boot-end         1220.34 s
GC                  0.6 s
```

Unit loop accounts for 747 s. **Unaccounted: ~445 s** (straight 21 s + discovery + tangle + post-boot).
Being measured with `SPLIT-MARK` timestamps — results below.

### 2.3 Unit time distribution (warm)

```
  <0.2 s:  17 units
  0.2–1 s: 224 units
  1–3 s:    76 units
  >3 s:     62 units
```

Of the 62 units over 3 s: **24 are parked manual/prose units costing ~280 s (37% of all unit time).**

Slowest 10 (all `loaded` — cache hit, yet slow):
```
34.4s  the-screen/display/06-screen
26.0s  files/org-manual/04-export
22.9s  under-the-hood/elisp/00-types-a
20.8s  under-the-hood/dealing-with-trouble
20.0s  the-screen/display/05-minibuffer
17.8s  reaching-outward/calculator/06-programming
13.7s  under-the-hood/getting-help
12.8s  under-the-hood/elisp/05-programs
12.5s  building-things/maintaining-large-programs
11.9s  shaping-the-tool/customization
```

---

## PART 3 — OPEN ITEMS (must close before ranking phases)

**O1. Is the ~280 s check overhead or real load work?**
A cached `.elc` `load` should be milliseconds. 12 s each means either heavy top-level work at load,
or the per-unit timer includes hash/stat/truename. **In progress:** `:around` advice on
`cyberdeck-emacs--unit-load` measuring the check window separately and recording `.elc` size next to
seconds. If check overhead dominates → Phase D outranks everything.

**O2. Where do the ~445 s outside the unit loop go?**
**In progress:** `SPLIT-MARK` advice on `cyberdeck-emacs-boot`, `--index-save`,
`errors-save-log`, `--self-check`, `dashboard-open`, plus an `after-init` mark.

**O3. Warm boot-end number.** First zero-edit boot measured 1220 s (rev-1 run, post-migration).
The instrumented warm boot is still running; its `boot-end` will confirm whether a truly
no-change boot is faster.

**O4. Load-path probe cost.** Unmeasured. One-line experiment: restrict `foundation-init.el:70-75`
to dirs of actually-declared packages, re-time a warm boot.

---

## PART 4 — PHASES (provisional; final ranking waits on O1/O2)

Per reviewer: three tiers, and `manual` is distinct from `idle`.

| `:MM_LOAD:` | Meaning | Applies to | Est. saving |
|---|---|---|---|
| `boot` (default) | load during boot loop, as today | ~224 sub-second units + dashboard/modeline/keyboard/db/search | — |
| `idle` | compile at boot; **load in chunks from an idle timer**, preserving chain order | 155 units over 1 s that are real but non-urgent | TBD |
| `manual` | **never** load at boot; load on command or first visit | the 24 parked prose units | **up to ~280 s** |

Rationale for `idle` over autoload-cookies: units are loose top-level forms with load-time side
effects; auto-generated autoloads would be fragile. Chunked idle loading needs no new cookie machinery.

### Sequencing

0. **Close O1–O4.** No behaviour change. Rank everything on measured numbers.
1. **Phase M — parked manuals → `manual`.** Highest confidence win (~280 s). Touches only the
   24 prose units; no cross-unit dependencies (they are documentation). Needs:
   - new drawer key `:MM_LOAD:`, which means extending the drawer reader near loader `:875`
     (today it reads only `:ID:`/`:MM_PARENT:`/`:MM_ORDER:`).
   - default `boot` when absent → zero behaviour change until units opt in.
2. **Phase I — `idle` tier for the 155 slow-but-real units.** Needs the chunked idle loader +
   a way to load a unit on demand (`cyberdeck-emacs-compile-file`-style, already exists).
3. **Phase B — annotate remaining leaf blocks with deferring keywords.** Small (see §1.7).
4. **Phase D — fix I/O floor.** Depends on O1. Reviewer's suggestion: truename each *directory*
   once, memoized, append basename — instead of `file-truename` per file (measured ~0.17 s cold,
   72 internal stats each). Alternative: key the cache on vault-relative path and drop truename
   entirely, since only stability is required.
5. **Phase L — prune the 133-dir `load-path`** (O4). One line in `foundation-init.el`, but that file
   is a tangled artifact → edit `AIU-Frame.org`.

### Risks

- Deferred units are invisible to the loader's `--self-check` (`cyberdeck-emacs--self-check`)
  and to the boot-complete lifecycle (splash, dashboard open, modeline). Both need to treat
  `manual`/`idle` units as legitimately-absent.
- Load-order coupling: any unit registering hooks/keys/modes other units rely on must stay `boot`.
  Needs a scan of top-level `add-hook` / `define-key` / `global-*` forms.
- `:MM_LOAD: manual` on a unit with load-time side effects other units depend on = silent breakage.

---

## PART 5 — QUESTIONS FOR THE REVIEWER

1. Verify §1.4/§1.5/§1.6 against `cyberdeck` (I can't see it; you can).
2. §2.3 shows 24 parked prose units = ~280 s. Is `:MM_LOAD: manual` the right call for units that
   are *documentation of Emacs itself* — or should they simply be untagged (`:EMACS_MECHANISM:`
   is documented as aspirational: "it marks a file as a unit you intend to write")? Untagging
   would achieve the same result with zero loader change. **This may be the cheapest fix of all.**
3. Where exactly is the drawer reader, and what's the minimal patch to accept a 4th key
   without breaking the "exactly three keys" contract that AGENT.md documents?
4. Does dropping `file-truename` from the cache key (§4 Phase D) break anything that depends on
   symlink-independence? The vault has no symlinks (verified: `find -type l` → 0 outside .git).
5. Given §2.2, is ~445 s of non-unit boot plausibly `org-persist` / element-cache I/O from the
   dashboard agenda? (Fixed: `dashboard-agenda-files` = nil.) If not, what else runs post-compile?

Do not write code. Return a corrected plan with phases ranked by measured payoff, and flag
anything in Parts 1–2 still wrong.