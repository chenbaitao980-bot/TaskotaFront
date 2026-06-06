# Thinking Guides

> **Purpose**: Expand your thinking to catch things you might not have considered.

---

## Why Thinking Guides?

**Most bugs and tech debt come from "didn't think of that"**, not from lack of skill:

- Didn't think about what happens at layer boundaries → cross-layer bugs
- Didn't think about code patterns repeating → duplicated code everywhere
- Didn't think about edge cases → runtime errors
- Didn't think about future maintainers → unreadable code

These guides help you **ask the right questions before coding**.

---

## Available Guides

| Guide | Purpose | When to Use |
|-------|---------|-------------|
| [Code Reuse Thinking Guide](./code-reuse-thinking-guide.md) | Identify patterns and reduce duplication | When you notice repeated patterns |
| [Cross-Layer Thinking Guide](./cross-layer-thinking-guide.md) | Think through data flow across layers | Features spanning multiple layers |
| [Code Intelligence Tool Rules](../workflow/codegraph-guidelines.md) | graphify/codegraph priority, pre-edit sequence, post-edit sync | Before any code modification |

---

## Quick Reference: Thinking Triggers

### When to Think About Cross-Layer Issues

- [ ] Feature touches 3+ layers (API, Service, Component, Database)
- [ ] Data format changes between layers
- [ ] Multiple consumers need the same data
- [ ] You're not sure where to put some logic

→ Read [Cross-Layer Thinking Guide](./cross-layer-thinking-guide.md)

### When to Think About Tool Priority (graphify/codegraph before grep)

- [ ] You need to understand code before modifying it
- [ ] You're about to run `grep` / `find` for code search
- [ ] You need to trace a data flow across files/layers
- [ ] You want to know the impact radius of a change
- [ ] You're debugging without knowing where the root cause is

→ Read [Code Intelligence Tool Rules](../workflow/codegraph-guidelines.md)

---

### When to Think About Code Reuse

- [ ] You're writing similar code to something that exists
- [ ] You see the same pattern repeated 3+ times
- [ ] You're adding a new field to multiple places
- [ ] **You're modifying any constant or config**
- [ ] **You're creating a new utility/helper function** ← Search first!

→ Read [Code Reuse Thinking Guide](./code-reuse-thinking-guide.md)

---

## Pre-Modification Rule (CRITICAL)

> **Before changing ANY value, ALWAYS run graphify/codegraph first, grep last!**

```bash
# Step 1: Semantic search (graphify)
npx -y @nodesify/graphify query "<feature/module/symbol>"

# Step 2: Symbolic search (codegraph trio)
npx @colbymchenry/codegraph query "<symbol>"
npx @colbymchenry/codegraph impact "<symbol>"
npx @colbymchenry/codegraph callers "<symbol>"

# Step 3: Traditional search (last resort only)
grep -r "value_to_change" .
```

See full rules in the [Code Intelligence Tool Rules spec](../workflow/codegraph-guidelines.md).

---

## How to Use This Directory

1. **Before coding**: Skim the relevant thinking guide
2. **During coding**: If something feels repetitive or complex, check the guides
3. **After bugs**: Add new insights to the relevant guide (learn from mistakes)

---

## Contributing

Found a new "didn't think of that" moment? Add it to the relevant guide.

---

**Core Principle**: 30 minutes of thinking saves 3 hours of debugging.
