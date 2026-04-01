# figma-extract

Handles authentication, data extraction from Figma, and component classification.

**Trigger:** Invoked by figma-to-storybook orchestrator when phase=EXTRACT.
**Input:** `.figma-migration.json` with phase=EXTRACT and config populated.
**Output:** `.figma-migration.json` with manifest[] fully populated and phase advanced to TOKENS (via orchestrator).

---

## PHASE: INIT

**Authentication mode detection:**
Before collecting config, check if the Figma MCP is available (`mcp__figma__whoami` tool exists and returns a user).
- **MCP available** → use `mcp_mode: true`. No Personal Access Token required. Skip token prompt entirely. Display: "Figma MCP detected — using OAuth session."
- **MCP unavailable** → use `mcp_mode: false`. Prompt for Personal Access Token as below.

Collect configuration values from the developer. Ask for them one at a time or as a grouped prompt:

| Input | Required when | Expected format |
|---|---|---|
| Figma Personal Access Token | `mcp_mode: false` | `figd_...` (from Figma → Settings → Personal access tokens) |
| Figma File ID or URL | always | File ID: string between `/design/` and `/` in the URL. Or paste the full Figma URL — the ID will be parsed automatically. |
| Language | always | `javascript` / `typescript` |
| Testing framework | always | `vitest` / `jest` |

Note: Styling system is always Tailwind. It is not prompted — it is written as a fixed constant (`"tailwind"`) in the state file.

**Token/session validation (before writing state file):**
- `mcp_mode: false` → Call `GET https://api.figma.com/v1/me` with header `X-Figma-Token: {token}`. HTTP 200 → proceed. HTTP 401/403 → report "Invalid or expired Figma token." Re-prompt. Do NOT write the state file.
- `mcp_mode: true` → Call `mcp__figma__whoami`. If it returns a user object → proceed. If it fails → report "Figma MCP session expired. Re-authenticate via `mcp__figma__authenticate`." Do NOT write the state file.

Add `mcp_mode` boolean to the state file `config` object.

**Injection layer (before writing state file):**

Read both learning files (treat absent or malformed as `{ "entries": [] }` — see LEARNING SYSTEM: Storage for malformed/version-mismatch handling):
1. Read `~/.claude/figma-to-storybook-learnings.json` (global).
2. Read `.figma-learnings.json` (project).
3. Merge into `activeRules` in memory — project entries override global on `signal` conflict. This is intentional for the `"verify:"` namespace: a project `verify_auto_fix` rule supersedes a global `verify_escalation` rule for the same checkId. `"classify:"` and `"figma:"` signals cannot collide cross-type.
4. `activeRules` is memory-only — do NOT write it to the state file. Rebuild from JSON files at every INIT.
5. If at least one rule loaded, display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ACTIVE LEARNINGS — {post-merge total} rules loaded
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Global:  {raw global count} rules  (from 2+ projects)
  Project: {raw project count} rules  (this project only)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If both files empty or absent: display nothing (no "0 rules loaded" noise).

**How activeRules extend each phase:**
- `classification_override` rules → CLASSIFY: prepend as additional rows to classification heuristics (applied before built-in rules)
- `translation_gap` rules → ATOMS / MOLECULES / ORGANISMS phases: append as additional rows to Translation Table in GENERATE_COMPONENT sub-steps within those phases
- `verify_escalation` rules → VERIFY_LAYER: add signal to always-escalate list (`correction` field unused — signal alone identifies the check)
- `verify_auto_fix` rules (project file `frequency` ≥ 3, regardless of `promotedToRule`) → VERIFY_LAYER: add signal to auto-fix list; if also on always-escalate, remove from there first. Threshold evaluated against project file frequency only.

**Write state file** (only after token validation passes):

```json
{
  "version": "1.0.0",
  "phase": "EXTRACT",
  "errorPhase": null,
  "errorMessage": null,
  "retryCount": 0,
  "figmaFileId": "<user-provided>",
  "config": {
    "styling": "tailwind",
    "language": "<javascript|typescript>",
    "testing": "<vitest|jest>",
    "mcp_mode": "<true|false>",
    "tokenThreshold": 3
  },
  "manifest": {
    "atoms": [],
    "molecules": [],
    "organisms": [],
    "pages": [],
    "variableDefs": {}
  },
  "progress": {
    "atoms":      { "done": [], "pending": [] },
    "molecules":  { "done": [], "pending": [] },
    "organisms":  { "done": [], "pending": [] },
    "behaviours": { "done": [], "pending": [] },
    "pages":      { "done": [], "pending": [] }
  },
  "extractionProgress": {
    "pages": [], "completedPages": [], "pendingPages": []
  },
  "learnings": []
}
```

Add `.figma-migration.json` and `.figma-learnings.json` to `.gitignore` if not already present.

Advance `phase` to `EXTRACT` and proceed immediately.

---

## PHASE: EXTRACT

**Extraction strategy — choose based on `config.mcp_mode`:**

### MCP mode (`config.mcp_mode: true`)

1. Call `mcp__figma__get_metadata` with `fileKey` to get file structure and the top-level page list.
2. For each `COMPONENT` or `COMPONENT_SET` node found, call `mcp__figma__get_design_context` with `nodeId` and `fileKey`. Map returned hints to manifest fields using this table:

| MCP output | Manifest field |
|---|---|
| variables color values | `fills[].hex` |
| variables spacing values | `paddingTop/Right/Bottom/Left`, `itemSpacing` |
| variables typography | `fontFamily`, `fontSize`, `lineHeightPx` |
| code hint `isAutoLayout` | `isAutoLayout` |
| code hint `layoutMode` | `isAutoLayout: layoutMode !== "NONE"` |
| code hint `effects` | `effects[]` |

3. Call `mcp__figma__get_variable_defs` with `fileKey` to extract all design tokens. Store variable definitions in `manifest.variableDefs` for use by the figma-tokens skill.
4. Note: MCP does not expose `blendMode` at fill level directly. If generated code contains `mix-blend-mode`, set `fills[N].blendMode` to that value in the manifest; otherwise default to `NORMAL`.
5. If a Figma URL is provided instead of a bare nodeId, parse the `node-id` query param and convert `-` to `:` before calling MCP tools.

### REST API mode (`config.mcp_mode: false`)

**Standard extraction:**
```
GET https://api.figma.com/v1/files/{figmaFileId}
X-Figma-Token: {token from INIT}
```

**Large-file handling:** If HTTP 413 or response >50 MB:
1. Call `GET /v1/files/{fileId}?depth=1` to get the top-level page list.
2. For each page, call `GET /v1/files/{fileId}/nodes?ids={pageNodeId}` to walk the tree.
3. After each successful page, update `extractionProgress.completedPages` in the state file so retries resume from the last completed page.

**For every node of type `COMPONENT` or `COMPONENT_SET`**, extract and write a manifest entry:

```json
{
  "name": "Button",
  "nodeId": "510:401",
  "type": "COMPONENT_SET",
  "figmaUrl": "https://www.figma.com/design/{fileId}/?node-id=510-401",
  "semanticType": "default",
  "layer": null,
  "variants": ["primary/small", "primary/regular", "primary/big", "primary/plus"],
  "booleanProps": ["showIcon"],
  "instanceSwaps": ["iconSlot"],
  "tokens": {
    "fontFamily": "Source Sans 3",
    "fontSize": 16,
    "lineHeightPx": 24,
    "letterSpacing": 0.8,
    "textCase": "SMALL_CAPS_FORCED",
    "textAlignHorizontal": "CENTER",
    "fontWeight": 700,
    "fills": [{ "hex": "#FF6900", "opacity": 1, "blendMode": "NORMAL" }],
    "strokes": [{ "hex": "#000000", "weight": 1, "align": "INSIDE" }],
    "cornerRadius": 3,
    "paddingTop": 8, "paddingRight": 22, "paddingBottom": 8, "paddingLeft": 22,
    "itemSpacing": 8,
    "isAutoLayout": true,
    "layoutGrow": 0,
    "counterAxisAlignItems": "CENTER",
    "primaryAxisAlignItems": "CENTER",
    "effects": [{ "type": "DROP_SHADOW", "offsetX": 0, "offsetY": 0, "blur": 4, "spread": 0, "color": "rgba(0,0,0,0.25)" }],
    "opacity": 1
  }
}
```

**Critical extractions — these are the most common sources of fidelity errors:**
- `isAutoLayout`: read from `layoutMode` on the node. If `layoutMode === "NONE"`, the node uses absolute positioning. Gap must be calculated as `xChild2 - xChild1 - widthChild1`, not from `itemSpacing`.
- `blendMode`: read from `fills[N].blendMode`, NOT from `fills[N].color.a`. These are different values.
- Padding: extract all 4 individually (`paddingTop`, `paddingRight`, `paddingBottom`, `paddingLeft`). Do not shorthand them during extraction.
- `textCase`: read from `style.textCase` on the text node child, not from the frame.
- `textAlignHorizontal`: read from `style.textAlignHorizontal` on the text node child.
- Colors: always use `fills[N].color` from the API response converted to hex. **Never** copy hex values from the Figma visual inspector (it rounds).
- `effects[N].spread`: read from `effects[N].radius` in Figma API (the `spread` field in the manifest corresponds to `radius` in the API response).

### Page frame extraction (all modes)

After extracting COMPONENT/COMPONENT_SET nodes, also extract top-level FRAME nodes (direct children of Figma page canvases):
- MCP mode: identify from the `get_metadata` response — frames at depth=1 of each page.
- REST mode: nodes of type `FRAME` that are direct children of `document.children[N].children`.

For each top-level frame, add an entry to `manifest.pages[]`:

```json
{
  "name": "{node.name}",
  "nodeId": "{node.id}",
  "figmaUrl": "https://www.figma.com/design/{figmaFileId}/?node-id={node.id with : replacing -}",
  "childOrganisms": [],
  "viewport": {
    "width": "{node.absoluteBoundingBox.width}",
    "height": "{node.absoluteBoundingBox.height}"
  }
}
```

**After extraction:**
Write all component manifest entries into `manifest.atoms`, `manifest.molecules`, `manifest.organisms` in the state file with `layer: null` and `semanticType: "default"` (these are assigned during CLASSIFY). Write all page entries into `manifest.pages[]`. Advance `phase` to `CLASSIFY`.

---

## PHASE: CLASSIFY

**Step 1 — Auto-classify layer** using these heuristics:

| Signal | Layer |
|---|---|
| Node depth ≤ 2, no child COMPONENT references | `atom` |
| Node depth 3–4, references 1–3 atoms | `molecule` |
| Node depth ≥ 5, references molecules or 4+ atoms | `organism` |
| Full-width layout or multiple navigation elements | `organism` (overrides depth) |

**Conflict resolution (apply in this order — first matching rule wins):**
1. Explicit organism signals (full-width layout, navigation) always win over any depth signal.
2. Child COMPONENT reference count overrides node depth: a depth-2 node with 4+ atom references → molecule.
3. Node depth is the tiebreaker if rules 1–2 produce a tie.
4. If still ambiguous: assign the higher-complexity type (organism > molecule > atom) and mark `⚠ ambiguous` in the table.

**Step 2 — Assign semanticType** for each component:

| Detection signal | `semanticType` |
|---|---|
| Name contains "modal", "dialog", "drawer", "popover", "overlay", "lightbox" (case-insensitive) | `overlay` |
| Organism with full-width layout and link groups | `navigation` |
| Name contains "form" or has 3+ input children | `form` |
| Name contains "card" | `card` |
| Name contains "testimonial" or "quote" | `testimonial` |
| None of the above | `default` |

If a match is uncertain (name matches but visual inspection might differ), annotate with `⚠ auto-detected`.

**semanticType effects on generation and verification:**
- `overlay` → triggers Pattern #9 (focus trap) in GENERATE_COMPONENT and VERIFY_LAYER
- `testimonial` → triggers `<figure><blockquote><figcaption>` nesting rule
- `navigation` → triggers `<nav><ul><li>` nesting rule
- `card` → no additional structural rule; available for future use
- `form` → no additional rule beyond standard HTML nesting; all inputs must use `<label>` associations
- `default` → standard HTML nesting rules (Pattern #7) only

**Step 3 — Normalize component names** to valid JavaScript identifiers:
- Remove leading/trailing whitespace.
- Convert spaces and hyphens to PascalCase word boundaries (`my-button` → `MyButton`).
- Strip characters that are not alphanumeric or `_`.
- If the result starts with a digit, prepend `C` (`3D Icon` → `C3DIcon`).
- If two components produce the same identifier, append `_2`, `_3`, etc. and flag for developer review.

**Step 4 — Present the classification table** to the developer:

| Component (Figma name) | Identifier | Layer | semanticType | Confidence |
|---|---|---|---|---|
| Button | Button | atom | default | high |
| Modal | Modal | molecule | overlay ⚠ auto-detected | medium |
| ... | ... | ... | ... | ... |

Ask: "Does this classification look correct? You can override any layer or semanticType before we proceed. No files are created until you approve."

**Step 4b — Present detected pages:**
After the developer approves the component classification, also present:

```
Detected {N} page frame(s):
| Page name | Node ID | Viewport | Auto-detected organisms |
|---|---|---|---|
| Landing Page | 1:23 | 1440×900 | HeroBanner, CTA, Footer |
```

Ask: "Include these pages in the migration? Remove any you don't want. [Enter to keep all / type names to remove / N for none]"

For confirmed pages:
- Match organism names within that frame's descendants against the classified organisms list.
- Populate `childOrganisms[]` with matches.

For rejected pages:
- Remove the entry from `manifest.pages[]`.

After developer response: populate `progress.pages.pending[]` with the names of all confirmed pages.

**Step 5 — Write back to state file** after developer approval:
Update every manifest entry's `layer` and `semanticType` with the confirmed values. Populate `progress.atoms.pending`, `progress.molecules.pending`, `progress.organisms.pending` with the component names in each layer. Advance `phase` to `SETUP`.

**Step 6 — Capture classification overrides:**
For each component where the developer changed `layer` or `semanticType` from the auto-classified value:
- Append one event per changed field to `learnings[]` in the state file.
- Use `(type, signal)` schema from LEARNING SYSTEM: Event Types.
- Example for semanticType override on "Card": `{ "type": "classification_override", "signal": "classify:Card:semanticType", "label": "Card semanticType correction", "before": "default", "after": "card", "phase": "CLASSIFY", "componentName": "Card", ... }`
- If no overrides were made: append nothing.
