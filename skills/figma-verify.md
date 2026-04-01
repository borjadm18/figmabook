# figma-verify

Verifies fidelity, runs auto-fixes, and blocks advancement until all Critical issues are resolved.

**Trigger:** Invoked by figma-to-storybook orchestrator with current layer:
`atoms` | `molecules` | `organisms` | `behaviour` | `pages`
**Input:** `.figma-migration.json` with `progress.{layer}.done[]` populated.
**Output:** Fidelity report appended to `docs/migration-report.md`. Reports completion to orchestrator.

---

## Fidelity Score Formula

For each component:
```
fidelity% = (correctly_represented_fields / total_applicable_fields) × 100
```

- `total_applicable_fields` = count of manifest token fields that have a Tailwind mapping in the Translation Rules table.
- `correctly_represented_fields` = count of those fields whose Tailwind class in the generated JSX matches the manifest value within tolerance:
  - Colors, fonts, border-radius, padding: exact match.
  - Spacing (gap, itemSpacing): ±0.5px tolerance.
- **Excluded from both numerator and denominator:**
  - `n/a` fields (`textCase: ORIGINAL`, `textAlignHorizontal: LEFT`) — intentionally emit no class.
  - Non-Figma additions marked with `{/* ✦ NOT IN FIGMA */}` comment.
- **Structural rules (patterns #7, #8, #9) are NOT included in fidelity %. They are a separate blocking gate.**

Layer fidelity = average of component scores. Overall fidelity = average across all layers.

---

## Checklist Walk (Verification Mechanism)

For each component in the completed layer:

1. Build a checklist from the manifest: one item per applicable Translation Rules field.
2. Read the generated JSX files.
3. For each checklist item: search the JSX className props for the expected Tailwind class. Mark as **pass**, **fail**, or **n/a**.
4. Scan all JSX class values for entries with no manifest source. Flag any that lack a `{/* ✦ NOT IN FIGMA */}` comment.
5. Check structural rules:
   - Pattern #7: verify HTML element choices against the nesting table.
   - Pattern #8: if any `.map()` returns multiple siblings, verify `React.Fragment key` is used.
   - Pattern #9: if `semanticType === "overlay"`, verify both `useEffect` blocks and `previousFocus.current?.focus()` are present.
6. Compute fidelity score. Report.

### Tailwind class search table

| Manifest field | Search for in JSX className |
|---|---|
| `fills[].hex = #XXXXXX` matching token | `bg-{token}` or `text-{token}` |
| `fills[].hex = #XXXXXX` not in config | `bg-[#XXXXXX]` or `text-[#XXXXXX]` |
| `fontSize = N` matching token | `text-{token}` |
| `fontSize = N` not in config | `text-[{N}px]` |
| `fontWeight = 700` | `font-bold` |
| `fontWeight = 600` | `font-semibold` |
| `fontWeight = 400` | `font-normal` |
| `paddingLeft/Right equal` | `px-{token}` or `px-[{N}px]` |
| `paddingTop/Bottom equal` | `py-{token}` or `py-[{N}px]` |
| `itemSpacing` + `isAutoLayout:true` matching token | `gap-{token}` |
| `itemSpacing` + `isAutoLayout:true` not in config | `gap-[{N}px]` |
| `cornerRadius` matching token | `rounded-{token}` |
| `cornerRadius` not in config | `rounded-[{N}px]` |
| `effects[DROP_SHADOW]` matching token | `shadow-{token}` |
| `effects[DROP_SHADOW]` not in config | `shadow-[...]` |
| `opacity != 1` | `opacity-[{N}]` |
| `blendMode != NORMAL` | `mix-blend-{mode}` on element + `isolate` on parent |
| `textCase: SMALL_CAPS_FORCED` | `[font-variant-caps:small-caps]` |
| `textCase: UPPER` | `uppercase` |
| `textCase: LOWER` | `lowercase` |
| `textCase: TITLE` | `capitalize` |
| `textAlignHorizontal: CENTER` | `text-center` |
| `textAlignHorizontal: RIGHT` | `text-right` |
| `textAlignHorizontal: JUSTIFIED` | `text-justify` |

### Token consistency check (NEW — applies to component layers)

If a value uses an arbitrary class (e.g. `bg-[#FF6900]`) but the same value exists as a named token in `tailwind.config.ts` (e.g. `colors.primary = '#FF6900'`), flag as **Important**:

> "Consider using `bg-primary` instead of `bg-[#FF6900]` — token `colors.primary` exists in `tailwind.config.ts`"

This is never auto-fixed. The developer decides. Severity: 🟡 Important.

---

## Behaviour layer checklist (layer=behaviour)

For each component in `progress.behaviours.done[]`:

**todoOnly: false (hook generated):**
- `use{ComponentName}.ts` file exists in the component directory
- `{ComponentName}.tsx` imports the hook at the top of the file
- `{ComponentName}.tsx` calls the hook inside the component function
- `{ComponentName}.stories.tsx` has a `WithInteraction` exported story
- `{ComponentName}.test.tsx` has hook unit tests (open, close, toggle for isOpen; goTo/next/prev for activeIndex)

**todoOnly: true:**
- `{ComponentName}.tsx` has `// TODO (figma-behaviour):` comment(s)

No fidelity percentage for behaviour layer. Report as:
```
Behaviour: {N} hooks generated | {N} TODO-only (manual completion required)
```

---

## Pages layer checklist (layer=pages)

For each page in `progress.pages.done[]`:

| Check | Severity if missing |
|---|---|
| All `childOrganisms[]` imported in the story | Critical |
| `layout: 'fullscreen'` present (not `'centered'`) | Critical |
| Desktop, Tablet, Mobile viewport stories all present | Critical |
| Organism render order matches Figma Y order | Important |
| Inter-organism spacing classes match Figma gaps | Important |

Fidelity score for pages:
```
pages_fidelity% = (organisms correctly imported and rendered) / (total expected organisms) x 100
```

---

## Severity Levels

| Level | Condition | Action |
|---|---|---|
| Critical | Manifest value absent or wrong in code | Auto-fix if in list below; else block and request fix |
| Important | Code value with no manifest source; or token consistency warning | Ask: add comment, remove, or accept |
| Suggestion | Sub-pixel difference (<0.5px), code style, missing story variant | Log only — do not block |

**The skill does not advance to the next layer until all Critical issues are resolved.**

---

## Auto-Fix Categories (Tailwind)

**Always auto-fix (direct class substitution — no structural side effects):**
- Wrong hex color: replace `bg-[#WRONG]` with corrected value or named token class
- Missing `[font-variant-caps:small-caps]` for `textCase: SMALL_CAPS_FORCED`
- Missing `uppercase` / `lowercase` / `capitalize` for textCase UPPER/LOWER/TITLE
- Missing `text-center` / `text-right` / `text-justify` for textAlign
- Wrong padding class value (px-, py-, pt-, pr-, pb-, pl-)
- Missing gap class for isAutoLayout + itemSpacing
- Wrong font-size class
- Wrong font-weight class (font-bold, font-semibold, font-normal, font-light)
- Missing `opacity-[{N}]` when manifest opacity != 1
- Missing shadow class for DROP_SHADOW effect

**Always escalate to developer (never auto-fix):**
- `mix-blend-{mode}` + `isolate` — requires parent/child JSX restructuring
- Layout type mismatch (auto vs absolute) — may require JSX restructuring
- HTML element nesting errors (Pattern #7) — requires semantic judgment
- Missing focus trap (Pattern #9) — requires full useEffect template insertion
- Token consistency warnings — developer decides
- Values where manifest has multiple variants with different values for the same field

---

## Structural Issues Gate

Structural violations (patterns #7, #8, #9) are Critical issues that block advancement — tracked separately from the fidelity score. They appear in a "Structural Issues" section of the migration report, not in the fidelity percentage.

---

## Event Capture (write to `learnings[]` in real time)

Append events to `learnings[]` in the state file as each action occurs:

**`verify_auto_fix`** — write after fix is confirmed applied:
```json
{ "type": "verify_auto_fix", "signal": "verify:{checkId}", "label": "{description}", "before": "{what was wrong}", "after": "{applied fix}", "phase": "VERIFY_ATOMS|VERIFY_MOLECULES|VERIFY_ORGANISMS|VERIFY_BEHAVIOUR|VERIFY_PAGES", "componentName": "{name}" }
```

**`verify_escalation`** — write when escalating a Critical issue:
```json
{ "type": "verify_escalation", "signal": "verify:{checkId}", "label": "{description}", "before": "auto-fix attempted|direct escalation", "after": "escalated", "phase": "VERIFY_*", "componentName": "{name}" }
```

**`translation_gap`** — write when a Figma field has no Tailwind mapping and is added manually:
```json
{ "type": "translation_gap", "signal": "figma:{figmaField}:{figmaValue}", "label": "{description}", "before": "no mapping", "after": "{Tailwind class added}", "phase": "VERIFY_*", "componentName": "{name}" }
```

---

## Advancement

After all Critical and structural issues are resolved and Important issues are decided, report to orchestrator:

```
Layer {layer} complete.
Fidelity: {N}% | Critical: {N} auto-fixed | Escalated: {N} | Important: {N} decisions | Suggestions: {N} logged
```

Orchestrator advances phase:
- VERIFY_ATOMS -> MOLECULES
- VERIFY_MOLECULES -> ORGANISMS
- VERIFY_ORGANISMS -> BEHAVIOUR
- VERIFY_BEHAVIOUR -> PAGES
- VERIFY_PAGES -> DONE
