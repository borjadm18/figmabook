# figma-comments

Extracts Figma comment threads, maps them to components and pages, enriches generated files with JSDoc, and produces a design decisions log.

**Trigger:** Invoked by figma-to-storybook orchestrator when phase=COMMENTS.
**Input:** `.figma-migration.json` with all layers and pages done. All component `.tsx` files generated.
**Output:** JSDoc added to each `.tsx` file, `docs/design-decisions.md`, updated `docs/migration-report.md`.

---

## Why this matters

Figma comments contain the full back-and-forth between designers and clients — decisions made, alternatives rejected, open questions. Without them, a developer touching a component months later has no idea *why* it was built a certain way. This skill captures that context and embeds it into the codebase permanently.

---

## Data extraction

Comments always use the Figma REST API regardless of MCP mode, because the MCP server does not expose a comments endpoint.

**REST API call:**
```
GET https://api.figma.com/v1/files/{figmaFileId}/comments
X-Figma-Token: {token}
```

**MCP mode (no PAT available):**
If `config.mcp_mode: true` and no PAT was collected during INIT, prompt:
```
figma-comments needs a Figma Personal Access Token to read comment threads.
This is separate from your OAuth session and requires read-only file access.

Enter your Personal Access Token (figd_...) or press Enter to skip:
```
- If token provided: use it for this call only. Do NOT write it to the state file.
- If skipped: write `docs/design-decisions.md` with a note explaining why comments are empty. Continue to DONE.

---

## Comment thread structure

The API returns flat comments. Reconstruct threads by grouping:
- `parent_id === null` → root comment (thread opener)
- `parent_id === "{id}"` → reply to that root comment

Each thread has:
```json
{
  "id": "123",
  "message": "The button should be orange on hover",
  "client_meta": { "node_id": "510:401" },
  "resolved_at": "2024-01-20T14:00:00Z",
  "user": { "handle": "Designer A" },
  "created_at": "2024-01-15T10:30:00Z",
  "reactions": []
}
```

Key fields:
- `client_meta.node_id` → the Figma node the thread is anchored to
- `resolved_at` → `null` = open thread, timestamp = resolved
- `parent_id` → `null` = root comment, otherwise a reply

---

## Mapping threads to components

For each thread, map `client_meta.node_id` to a component or page:

1. **Direct match:** `node_id` matches a `nodeId` in `manifest.atoms[]`, `manifest.molecules[]`, `manifest.organisms[]`, or `manifest.pages[]` → map to that component/page.
2. **Child node:** `node_id` does not directly match any manifest entry. Walk up: the comment is on a child node inside a component frame. Map to the nearest ancestor component in the manifest by prefix-matching node IDs (e.g. node `510:403` is inside component `510:401`).
3. **No match:** the thread is on a canvas element not in the manifest (e.g. a free-floating annotation frame). Map to a catch-all section: `## General / Canvas`.

Build a `threadMap`:
```
componentName → [{ threadId, messages: [{author, text, date}], resolved, nodeId }]
```

---

## Component file enrichment

For each component with at least one mapped thread:

1. Read the existing `{ComponentName}.tsx` file.
2. Locate the `export function {ComponentName}` line.
3. Prepend a JSDoc block immediately above it:

```tsx
/**
 * {ComponentName}
 *
 * @figma {manifest entry figmaUrl}
 *
 * ## Design decisions
 * {for each RESOLVED thread mapped to this component:}
 * - [{date}, resolved] {Author}: "{message}"
 *   {for each reply:} → {Author}: "{message}"
 *
 * ## Open threads
 * {for each UNRESOLVED thread:}
 * - [{date}] {Author}: "{message}"
 *   {for each reply:} → {Author}: "{message}"
 */
```

4. If there are **any unresolved threads**, also add a single-line comment immediately after the JSDoc (before the `export function` line):

```tsx
// ⚠ PENDING DISCUSSION — {N} open thread(s). See docs/design-decisions.md#{component-slug}
```

5. Write the file back. Do not modify any other part of the file.

If a component has no mapped threads: skip it. Do not add empty JSDoc.

---

## Output: docs/design-decisions.md

Create `docs/design-decisions.md`. One section per component or page that has threads, ordered by layer (atoms → molecules → organisms → pages → general).

```markdown
# Design Decisions Log
Generated: {date}
Source: Figma file {figmaFileId}

**{resolved} threads resolved · {open} threads open**

---

## {ComponentName} ({layer})

**Figma node:** [{nodeId}]({figmaUrl})

### ✅ {Thread subject — first 60 chars of root message} — {date}

**{Author}:** {full message}
**{Author}:** {reply}
**{Author}:** {reply}
*Resolved {resolved_at date}*

---

### ⚠ {Thread subject} — {date} · OPEN

**{Author}:** {full message}
**{Author}:** {reply}
*Not yet resolved — requires decision*

---

## General / Canvas

{threads not mapped to any component}
```

---

## Output: migration-report.md update

Append a new section to `docs/migration-report.md`:

```markdown
## Comment Thread Summary
Total threads:     {N}
Resolved:          {N}
Open (unresolved): {N}

### Components with open threads
| Component | Layer | Open threads | First message |
|---|---|---|---|
| Button | atom | 1 | "Mobile padding feels too tight" |
| Card | molecule | 2 | "Client wants shadow removed" |
```

If there are no open threads: write `All {N} threads resolved.` and skip the table.

---

## Progress tracking

After processing all threads, write to state file:
```json
"comments": {
  "total": N,
  "resolved": N,
  "open": N,
  "componentsWithOpenThreads": ["Button", "Card"]
}
```

Advance `phase` to `DONE`.

---

## Event capture

Append to `learnings[]` for each open thread that was mapped to a component:
```json
{
  "type": "open_thread",
  "signal": "comment:{ComponentName}:open",
  "label": "{first 60 chars of thread root message}",
  "before": "unresolved",
  "after": "flagged",
  "phase": "COMMENTS",
  "componentName": "{ComponentName}"
}
```

This allows future migrations to surface patterns in recurring open threads (e.g. "mobile padding always flagged").
