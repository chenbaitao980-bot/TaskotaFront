# Workflow Development Guidelines

> Code integrity standards enforced via **graphify query + codegraph trio** — replace blind grep/find with semantic and symbolic codebase navigation.

---

## Overview

This directory contains guidelines for safe, traceable code modification using graphify and codegraph tools. These rules prevent "dig straight in and hope" debugging and ensure every edit is preceded by proper impact analysis.

Project-level spec for all AI agents working in this repo.

---

## Pre-Development Checklist

Before writing any code (Phase 2.1), verify:

- [ ] **Tool priority enforced**: graphify/codegraph FIRST, grep/find LAST
- [ ] **graphify pre-flight**: `npx -y @nodesify/graphify query "<功能/模块/符号>"` — semantic search first
- [ ] **codegraph trio**: `query` → `impact` → `callers` — symbolic search second
- [ ] **grep only as last resort**: Only after graphify + codegraph both return no results
- [ ] **Data flow traced**: Full input → transform → output chain confirmed (not guessed from symptoms)
- [ ] **User confirmed the plan**: Semantic-translation options presented and confirmed before any edit/write

> **Hard rule**: If graphify + codegraph haven't been queried, you haven't done enough research to edit code safely.

---

## Quality Check

Before reporting completion (Phase 3.1), verify:

- [ ] **Post-edit graphify sync**: `npx -y @nodesify/graphify update .` — re-index with new symbols
- [ ] **ARCHITECTURE.md + CHANGELOG.md**: Updated with verified facts only
- [ ] **No blind catch blocks**: Every `catch` logs meaningful context
- [ ] **Blast radius controlled**: Changes are scoped; no "while we're here" refactors mixed into fixes
- [ ] **One change at a time**: Each commit/PR addresses one coherent change

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Code Intelligence Tool Rules](./codegraph-guidelines.md) | Tool priority, pre-edit sequence, post-edit sync | Active |

---

**Language**: English.
