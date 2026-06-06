# Code Intelligence Tool Guidelines

> Replace blind `grep`/`find` with semantic (`graphify`) and symbolic (`codegraph`) codebase navigation — **trace first, search last**.

---

## 1. Tool Priority (Hard Order)

| Priority | Tool | When to Use | Fallback |
|----------|------|-------------|----------|
| 🥇 | `graphify query` | Semantic search: feature name, module name, error symptom | ⏭ Skip → next tool |
| 🥇 | `codegraph query / impact / callers` | Symbolic search: class/function/variable name | ⏭ Skip → next tool |
| 🥈 | `read <file>` | Read an already-located source file | — |
| 🥉 | `bash grep/find` | **Last resort** — only when graphify + codegraph both yield nothing | — |

### Rules

- **No grep before graphify/codegraph.** Every grep call must be preceded by a graphify query (semantic) AND a codegraph query (symbolic).
- **graphify query scope**: function/module/feature names and natural-language descriptions of the behavior you're looking for.
- **codegraph query scope**: exact symbol names (class names, function names, variable names).
- **codegraph trio** (always run all three when the symbol is found):
  1. `npx @colbymchenry/codegraph query "<symbol>"` — bulk source
  2. `npx @colbymchenry/codegraph impact "<symbol>"` — impact radius (warn user if HIGH/CRITICAL)
  3. `npx @colbymchenry/codegraph callers "<symbol>"` — callers at d=1

---

## 2. Pre-Edit Gate Sequence

Before calling `edit` or `write`, complete these steps in order:

### Step 1: Tool Availability Check

Report tool status with specific symbols queried:

```
[Tool Check]
  graphify query:       ✅ ("LoadTasks filter")
  codegraph query:      ✅ ("_onLoadTasks" -> task_bloc.dart:285)
  codegraph impact:     ❌ (symbol not indexed, skip)
  codegraph callers:    ❌ (symbol not indexed, skip)
  grep last resort:     ✅ (only if graphify+codegraph both failed)
```

- ✅ must include specific query terms/symbols
- ❌ must include the concrete reason
- **Only when ALL graphify+codegraph are ❌ → grep allowed**

### Step 2: Data Flow Trace

Map the full data chain in thinking:

```
[Data Flow Trace]
  Input: <event/data source>  ✓/✗
  Transform1: <fn A> → <fn B>  ✓/✗
  Transform2: <fn B> → <var C>  ✓/✗
  Output: <final dependency>  ✓/✗
```

All ✓ before determining edit point. No guessing root cause from symptoms.

### Step 3: User Confirmation Gate

Before any edit/write, present options as a lettered list (A/B/C...):

- Each option: description, scope of changes, risk level
- Mark ⭐ recommended combo + reason
- **STOP here. Wait for user to confirm a plan before proceeding.**
- **No exemption for "small changes" or "obvious fixes".**

### Step 4: graphify Query (Semantic)

```bash
npx -y @nodesify/graphify query "<feature/module/symbol>"
```

Must run before any grep/pure find.

### Step 5: codegraph Trio (Symbolic)

```bash
npx @colbymchenry/codegraph query "<symbol>"
npx @colbymchenry/codegraph impact "<symbol>"
npx @colbymchenry/codegraph callers "<symbol>"
```

**All three** must be attempted. Only if all return nothing → grep allowed.

### Step 6: Pre-Edit Self-Check

| Check | Description |
|-------|-------------|
| Root cause | What is the true root cause? |
| Call chain | Full call chain through the modification point |
| Logic distribution | Which files hold related logic? |
| Duplicate logic | Is there reusable/repeated code? |
| Files to change | Exact file list |
| Files NOT to touch | Explicit exclusion scope |
| Risk | Impact radius, rollback plan |
| Verification | How to verify correctness? |

After all steps complete, mark the gate as passed in thinking.

---

## 3. Edit-Time Constraints

- **One change at a time**: Change → verify → confirm → next
- **Simple solution first**: Direct fix before architectural refactor
- **Control blast radius**: Modify A without touching B
- **Every catch block must log**: No empty `catch (_) {}`
- **Broken → revert immediately**: `git stash` / `git checkout` and restart

---

## 4. Post-Edit Sync

After all edits are done:

```bash
npx -y @nodesify/graphify update .
```

Then update documentation:
- `ARCHITECTURE.md` — verified facts only
- `CHANGELOG.md` — verified facts only

**Post-edit self-check**:
- Duplicate logic? Temporary patches? Layer violations?
- Hidden fallbacks? Edge cases covered?
- Logging complete?

---

## 5. Reply Ending Format

Every response after a code change must end with:

```
Summary / Files / Tests / Risks / Next
```
