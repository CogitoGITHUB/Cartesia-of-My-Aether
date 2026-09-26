# AGENT.md — Operating guide for this Emacs configuration

**Read this before touching anything.** It exists because the setup has rules
that are not visible from any single file, and several of them are silent when
violated.

Companion document: `CAESTRIA AGENT INTEGRATION INTO ATLAS` is the *Atlas API
contract* (how to call the Atlas, what agents may not do). This file is the
*Emacs build* (how the loader works, how to add a unit, how to test). They do not
overlap.

---

## 1. Orientation

Everything lives under one git repo:

```
/data/data/com.termux/files/home/Cartesia-of-My-Aether/     <- vault root, has .git
```

| Path | What it is |
|---|---|
| `universe/` | the knowledge manifold, mirrored from physical scale down (universe → galaxy → solar-system → earth → … → linux) |
| `…/linux/text-editors/emacs/Manifolding-Emacs/` | the Emacs config source. Everything below this is Emacs. |
| `Manifolding-Emacs/Manifolding-Emacs-Foundation` | Org source, tangled at every boot into `early-init.el` + `foundation-init.el` |
| `Manifolding-Emacs/manifolding-emacs` | **the loader** (3176 lines) — discovery, ordering, extraction, compilation, caching, doctor |
| `Manifolding-Emacs/emacs-manifoldings/` | the unit tree: ~400 files, ~300 tagged units |
| `admin/` | session + layout state, excluded from unit discovery (see §8) |
| `WIP/` | raw captures. Never read, never walked, by anything. |
| `emacs-mechanism/` | blueprint/metadata for the mechanism system |
| `~/.config/emacs/init.el` | static seed. Locates the Foundation, tangles it, loads `foundation-init.el`. |
| `~/.config/emacs/*.el` | **build artifacts.** Never edit. See §7. |

Environment: Termux inside a proot Ubuntu, Emacs 30.2, TTY only (no GUI), phone
screen. `~` is `/root`, which is the same tree as
`/data/data/com.termux/files/home`.

### Boot chain

```
init.el
  → tangles Manifolding-Emacs-Foundation (Org)
      → early-init.el          (palette, GC, message filters — pre-init)
      → foundation-init.el     (straight → org → leaf → loader)
          → tangles manifolding-emacs
              → discovers + orders + compiles every tagged unit
                  → your config
```

`foundation-init.el` ends by calling `manifolding-emacs-boot`. The loader is
the only thing that knows how a unit becomes code.

---

## 2. The loader's rules — these are the non-negotiables

All of this is from `manifolding-emacs`, and all of it is **silent** when you
break it.

### A file is a unit only if all of these hold

1. **Its basename contains no dot.** The walk enforces "extensionless" on the
   basename (`:1285-1286`). `dired` loads. `dired.org` and `dired.el` are
   **silently discarded before the file is read**. If a unit goes missing after
   you touch it, check this first.
2. **It is not under `.git/`, `admin/`, or `WIP/`** (`:1275-1279`).
3. **It has a level-1 Org heading tagged `:EMACS_MECHANISM:`**
   (`manifolding-emacs--scan-file-tagged-units`, `:844-850`).

Nothing else. There is no per-module directory requirement — see §6.

### The heading is the name

The unit's `:title` is **the level-1 heading text with its tags stripped**
(`:866-870`). Not `#+title:`. The heading *is* the identity.

### The drawer is read for exactly three keys

The property drawer must sit on the line **immediately** after the heading
(`:875` — prose between the heading and the drawer silently detaches it, and
the package is then never built). The scanner reads:

- `:ID:` — identity, and the cache key
- `:MM_PARENT:` — the parent's **`:ID:`**, *not* its title and *not* its path
  (`:1219`)
- `:MM_ORDER:` — a float, sorts siblings

Nothing else. `:CATEGORY:` is read by **nothing**.

### Ordering has two classes, and only one is path-independent

- **Chained** (has `:MM_PARENT:` or `:MM_ORDER:`) — parents first via a
  cycle-guarded walk, siblings by `:MM_ORDER:`. **Path-independent.**
- **Chainless** (neither) — appended after the chain, **sorted by file path,
  then line** (`:1192-1199`). 120 units are chainless. **Moving one changes its
  load position.**

`:MM_PARENT: none` is the explicit "I am a root". A parent that does not
resolve, a cycle, and a duplicate `:ID:` are each reported at boot — watch for
those three lines, they are the loader telling you a move went wrong.

### `#+`-level file keywords

| Keyword | Live? | Why |
|---|---|---|
| `#+auto_tangle: t` | **yes** — 2 files only | the Foundation and the loader are the only org-babel-tangled files |
| `:header-args:` drawer property | **yes** — same 2 files | their tangle targets |
| `#+title:` | display only | `manifolding-emacs-file-title` (`:929`) uses it for the splash, falling back to the basename. **Its docstring literally says "Display only".** |
| `#+filetags:` | dead | no reader anywhere in the vault |
| `#+property:` | dead **and misleading** | lexical binding is the single global `manifolding-emacs-lexical-binding` defcustom (`:1529`), written into the `.el` cookie at `:1930`. There is no per-file control. |

`#+title:`, `#+filetags:` and `#+property:` were stripped from all of
`universe/` (458 lines, 333 files) on 2026-09-26. Root-level files were
deliberately **not** touched, because that sweep was scoped to `universe/`.

---

## 3. Writing a unit

```org
* Human Readable Name :EMACS_MECHANISM:
:PROPERTIES:
:ID:       <uuid — check it is unused before using it>
:MM_PARENT: none
:MM_ORDER:  80.5
:END:

Prose here is not loaded. Only #+begin_src blocks are.

#+begin_src emacs-lisp
(defun thing () "docstring." 42)
#+end_src
```

- Copy an existing unit's header block; the drawer is not optional in practice.
- `:MM_ORDER:` is a float and **must** be unique — collisions are not
  diagnosed, they just make order arbitrary. Check with
  `rg -o ':MM_ORDER:[ \t]+N' universe/ | sort | uniq -d`.
- Prefer `:MM_PARENT: <parent uuid>` over a bare float when you want to be
  sure of landing after something specific.

### The lisp-2 trap, which I hit three times in one session

Inside a quasiquote, `,x` and `',x` are **not** interchangeable:

- `,cache` — splices the symbol as a *variable reference*. Right in `(defvar
  ,cache …)`, which is naming a variable.
- `',name` — splices the *symbol as a datum*. Right for a list key that `assq`
  will look up.
- `add-hook` takes a variable's **name**, so it needs `',hook`. A bare `,hook`
  passes the variable's *value* — usually `nil` — and you get
  `Attempt to set a constant symbol: nil`.

The working reference for this idiom is
`manifolding-dashboard/engine/macros` (`manifolding-dashboard-define-widget`).
Copy from it; do not reason it out from scratch.

### Also

- Do **not** use a bare `cl-lib`/`seq` compatibility alias (`pushnew`,
  `position`, …). They resolve to nothing — or to something else — depending on
  what else is loaded. Use `member`/`length`, or the explicit `cl-`/`seq-`
  prefix.
- Never use `eval` on a list form to produce a mode-line value. Use a
  `lambda` (see `manifolding-modeline--segment-text` for the three shapes).

---

## 4. Module map

All paths relative to `Manifolding-Emacs/emacs-manifoldings/`.

| Directory | MM_ORDER lane | Role |
|---|---|---|
| `entering-the-machine/manifolding-dashboard/` | 78.3–78.5 | dashboard: `engine/`, `cores/` (vendored emacs-dashboard), `widgets/`, `banner/`, `faces`, `order` |
| `the-screen/modeline/` | 80.1–80.11 | multi-row mode line: `engine/`, `cores/stock`, `faces`, `widgets/`, `header` |
| `files/file-creation/manifolding-atlas/` | 100+ | the Atlas: `atlas-engine/`, `blueprints/`, plugins, and the note-taking system itself |
| `files/file-creation/manifolding-atlas/manifolding-keyboard/` | 2.x–4.x | modal key system: `engine/` (state machine, macros, scaffolding), `states/` (15), `leaders/` (19) |
| `the-screen/display/06-screen` | — | raw Emacs-manual prose, parked. Still holds display/windows/frames/Imenu/font-lock |
| `org-manual/*` | — | raw Emacs-manual prose, parked. Deliberately: the tag marks files *to be written* |

The manual-extract files are **intentional placeholders**, not broken config.
`:EMACS_MECHANISM:` is aspirational — it marks a file as a unit you intend to
write. The point of the project is to turn them into real config, carrying the
prose across as you go. Do not "fix" a parked unit.

---

## 5. Testing — this is the part that matters

**Do not reason about whether config works. Boot it.**

```sh
emacs --batch -Q \
  --load /root/.config/emacs/init.el \
  --load /tmp/kilo/probe.el
```

Takes **6–8 minutes**: reads ~400 files, compiles ~300 units. Run it in the
background, not in the foreground. Progress prints as
`N/300 · Compiling: <name> · E errors · W warnings` — watch the error counter,
and note *which unit* it moves on, because that is where a failure lives.

A full boot is clean at **89 packages ok, 1 error** (see §9). Any number above
that means you regressed something.

### Two ways to get results, and one that silently lies

**Good — load a real file.** Extract the unit's blocks to a `.el` and `load` it.
This is the loader's own path and it is the only one that is trustworthy:

```elisp
;; write each #+begin_src block to /tmp/kilo/units/<name>.el, then
(dolist (f '("macros" "setup" "stock" "doctor")) (load (expand-file-name
  (concat f ".el") "/tmp/kilo/units/") nil t))
```

**Bad — `eval` of a string.** On this Emacs 30.2 build, `(eval "(defvar xyz-abc
1)")` **defines nothing** and `(eval '(some-fn))` **returns the list
unevaluated**. It reports success and changes no state. I lost a long stretch of
debugging to this: an entire isolated test harness was measuring its own
harness and reporting phantom "void-function" errors that existed nowhere but in
the test. If a test tells you a symbol is void, check that you loaded a *file*.

**The real boot is authoritative.** When an isolated test and the boot disagree,
the boot is right.

### Fastest useful loop

1. Make the edit in `universe/`.
2. Read `/root/.config/emacs/manifolding-emacs-errors.log.el` after a boot:
   ```sh
   grep -o ':level [a-z]*' /root/.config/emacs/manifolding-emacs-errors.log.el | sort | uniq -c
   grep -o ':status [a-z-]*' /root/.config/emacs/manifolding-emacs-errors.log.el | sort | uniq -c
   ```
   `:status ok` count is the health metric. `:level part` entries carry the
   failing file, line, and package.
3. `M-x manifolding-dashboard-validate`, `M-x manifolding-keyboard-validate`,
   `M-x manifolding-modeline-audit` — the three gates, all of which return a
   list and should be empty.

---

## 6. Moving files between modules

**Safe.** Discovery is content-addressed, ordering is ID-addressed, and
cross-file references are by symbol. Moving a keyboard state, a leader, a
dashboard widget or a modeline widget will not break the boot or change its load
order.

Three exceptions, all real:

1. **Chainless units reorder by path.** Give anything you move an `:MM_ORDER:`.
   `leaders/tools` currently has none — that is the one to fix first.
2. **`manifolding-keyboard-validate` scans two hard-coded directories**
   (`manifolding-keyboard/engine/scaffolding:132-134`): `states/` and
   `leaders/`, non-recursively. Move a state out and the validator silently
   stops checking it. Silence there means "not looked at", not "fine". The
   dashboard's validator is registry-based and has no such problem.
3. **A dot in the new filename makes the file vanish.** §2A.1.

Scaffolders still *write* to fixed directories, so a reorganisation is not
self-maintaining until those are changed too.

---

## 7. Never edit these

`~/.config/emacs/early-init.el`, `~/.config/emacs/foundation-init.el`,
`~/.config/emacs/manifolding-emacs.el`, and anything the loader writes into its
cache. All are regenerated from `universe/` on every boot. Edit the **Org source
under `universe/`** or your change is gone.

One consequence worth internalising: **editing a macro does not invalidate its
users' caches.** The cache is keyed per unit on that unit's own content hash, so
fix a DSL in `engine/macros` and the widgets that *call* it keep their stale
compiled expansion. Bump `manifolding-emacs-cache-salt` or clear the cache when
you change how a macro expands.

---

## 8. What's in `admin/`

Excluded from unit discovery, which is what makes it the right home for
non-code state. Current layout:

```
admin/
  order/dashboard widgets        dashboard section order (read AND written at runtime)
  order/modeline widgets         modeline segment order
  order/headings blueprints drawer  the :DRAWER_BLUEPRINT: registry
  desktop/                       Emacs session desktop
  manifolding-atlas.db           Atlas database
```

The three order files are named for **what they order**, not after the module
that reads them, so `admin/order/modeline widgets` cannot be confused with the
modeline *code* in `emacs-manifoldings/the-screen/modeline/`. All three are
reached through one helper each, so a reader and a writer never diverge:
`manifolding-dashboard--order-file`, `manifolding-modeline--order-file`,
`my/manifolding-atlas--drawer-order-file` — all anchored on
`manifolding-emacs-vault-root`.

Filenames here contain **spaces** on purpose. They are safe: `admin/` is
excluded from unit discovery, so the loader never touches them, and they are
only ever reached by `expand-file-name` in the helpers above. Quoting matters
if you shell out: `ls "admin/order/dashboard widgets"`.

The order files and blueprints moved here on 2026-09-26. Before that,
`manifolding-dashboard--blueprints-dir` inferred the blueprint directory as *the
grandparent of whichever blueprint file a whole-vault walk returned first* — so
relocating one blueprint silently repointed every other widget's lookup. It is
now an explicit path from the Atlas:
`my/manifolding-atlas-dashboard-blueprints-dir`
(`atlas-engine/file-creation:4253`), and the dashboard delegates to it.

**Policy note:** `CAESTRIA AGENT INTEGRATION INTO ATLAS` says agents must never
edit anything under `admin/`. That rule was written when `admin/` held only the
database and `.known-keys`. Layout files now live there too, so the rule needs
updating — treat the order files and dashboard blueprints as source, and
everything else in `admin/` as generated.

---

## 9. Known issues

| What | State |
|---|---|
| `bufler` / `auto-workspace` void in `the-screen/buffer-management:86` | **Pre-existing.** The loaded bufler checkout's `bufler-defgroups` macro has no `auto-workspace` clause. The unit already carries an interlock (`my/bufler--macro-has-workspace-p`) that detects this and skips grouping setup instead of dying. Not caused by any recent work. Fix by updating the bufler checkout. |
| modeline left column | Segments are parsed but land in the right slot — `read-order` returns rows like `(1 nil (…))`. Suspect the `slot` computation or the side regex. Cosmetic: the bar renders, mirrored. |
| Atlas database | Needs PostgreSQL. On this device it reports `DOWN`, which is expected, not a fault. The Atlas DB probe is on the model's *slow* hook (every ~5 min) precisely so this is not a per-redisplay cost. |
| `manifolding-emacs-todo-file` | Points at `modules/TODO`, which does not exist. Only used by the interactive "file this boot error as a TODO" escape hatch. |
| `/root/modules` | Dangling symlink to `~/.config/emacs/modules/`, which does not exist. Nothing references it. |

## 10. Quick reference

```sh
VAULT=/data/data/com.termux/files/home/Cartesia-of-My-Aether
EMACS=$VAULT/universe/galaxy/solar-system/planets/earth/computer-science/operating-systems/linux/text-editors/emacs/Manifolding-Emacs

# health, after a boot
grep -o ':status [a-z-]*' ~/.config/emacs/manifolding-emacs-errors.log.el | sort | uniq -c

# duplicate MM_ORDER (should print nothing)
grep -oE ':MM_ORDER:[ \t]+[0-9.]+' -r $VAULT/universe/ | sort | uniq -d

# units the loader would discover
grep -rlE '^\* .*:EMACS_MECHANISM:' $VAULT/universe/ | wc -l

# git review
git -C $VAULT status --short
git -C $VAULT diff --stat
```

**`grep` gotcha that cost me time twice:** in a *basic* regex, `\+` means "one
or more of the previous", not a literal `+`. `grep -c '^#\+begin_src'` silently
matches nothing, because the line is `#+begin_src`. Use `rg`, or `[+]`, or a
plain `+` in BRE.
