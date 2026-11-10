# Wayfinder (local tracker)

Planning maps live here as plain Markdown, so the effort needs no external issue tracker.

## Layout

```
wayfinder/
└── <map-slug>/
    ├── map.md          # the map: destination, notes, decisions index, fog, out of scope
    ├── tickets/        # one file per ticket: NN-<slug>.md
    └── research/       # findings written by research tickets
```

## Ticket frontmatter

```yaml
---
id: 03                       # stable identity; never reused
title: Ayah reference grammar
labels: [wayfinder:prototype] # one of research | prototype | grilling | task
status: open                  # open | closed
assignee:                     # empty = unclaimed; set your name to claim BEFORE working
blocked_by: [01]              # ticket ids; unblocked when all listed tickets are closed
---
```

- **Frontier** = tickets with `status: open`, empty `assignee`, and every `blocked_by` ticket closed.
- **Resolve** a ticket by appending a `## Resolution` section, setting `status: closed`, and adding a one-line pointer to the map's *Decisions so far*.
- Refer to tickets by **title** (linked), never by bare id.

Quick frontier query:

```sh
grep -l 'status: open' docs/wayfinder/*/tickets/*.md | xargs grep -L 'assignee: .\+'
```
(then check each file's `blocked_by` against closed tickets)
