## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.

## Using the graph in this project (read this with the rules above)
- **Query first, then search.** For any question about how this plugin works, run `graphify query "<question>"` (or `graphify path "<A>" "<B>"`, `graphify explain "<concept>"`) BEFORE `grep`, `rg`, `find` or reading source files. Only then open or grep the specific files the answer points to. Put the same rule in every subagent prompt that explores the code.
- **Know the graph's blind spot.** graphify cannot parse `.qml`, and almost all of this plugin is QML (`Island.qml`, `State.qml`, `Theme.qml`, `Bar.qml`, `components/`, `widgets/`, `services/`). The graph currently covers only `deploy.py`, `widgets/Registry.js`, `components/Icons.js`, `assets/*.sh`, the two `manifest.json` files and the README (concepts from the README, not from the code). So a query that comes back empty or README-shaped does not mean the code has nothing: follow up with `grep` and `Read` on the QML files. The README's architecture sections are the best map of the QML; graph nodes such as `Island.qml` are README mentions.
- **Update after changing things.**
  - After editing code the graph can read (`.py`, `.js`, `.sh`, `.json`): run `graphify update .` (AST only, free).
  - After changing `README.md` (new sections, renamed concepts): run `/graphify . --update` so the README is re-extracted (this uses a model).
  - After editing only QML, `graphify update .` finds nothing to do; the graph is not stale because it never contained that code, but update the README section that describes the change so the graph's view of the project stays accurate.
- `graphify-out/` is generated; the manual `/graphify` run and `graphify update .` are the only things that rewrite it. Keep `deploy.py` and the QML test rig (`rig.qml`) workflow from the README unchanged.
