# figma-to-storybook

Orchestrates the full Figma to Storybook migration. Sequences all skills, manages state, runs SETUP, and handles the learning system.

**Trigger:** User runs `/figma-to-storybook` in any project directory.

---

## Resumability

On every invocation, read `.figma-migration.json`:
- If file does not exist: start from INIT — invoke figma-extract
- If file exists: read `phase` field and resume from that phase

Print resume status before continuing:
```
Resuming: {phase} — {progress summary}
```

Progress summary format:
- During ATOMS/MOLECULES/ORGANISMS: "{layer}: {done.length}/{done.length+pending.length} done"
- During BEHAVIOUR: "behaviour: {done.length} hooks generated"
- During PAGES: "pages: {done.length}/{done.length+pending.length} done"

---

## State machine and skill invocation sequence

```
INIT / EXTRACT / CLASSIFY  ->  invoke figma-extract
TOKENS                     ->  invoke figma-tokens
SETUP                      ->  run SETUP inline (see below)
ATOMS                      ->  invoke figma-component [layer=atoms]
VERIFY_ATOMS               ->  invoke figma-verify [layer=atoms]
MOLECULES                  ->  invoke figma-component [layer=molecules]
VERIFY_MOLECULES           ->  invoke figma-verify [layer=molecules]
ORGANISMS                  ->  invoke figma-component [layer=organisms]
VERIFY_ORGANISMS           ->  invoke figma-verify [layer=organisms]
BEHAVIOUR                  ->  invoke figma-behaviour
VERIFY_BEHAVIOUR           ->  invoke figma-verify [layer=behaviour]
PAGES                      ->  invoke figma-pages
VERIFY_PAGES               ->  invoke figma-verify [layer=pages]
DONE                       ->  run DONE inline (see below)
ERROR                      ->  present error and options (see ERROR handling)
```

After each skill completes, advance `phase` to the next state and write `.figma-migration.json`.

---

## PHASE: SETUP (inline)

Check if `package.json` exists in the working directory:
- **Exists** -> existing project. Merge required dependencies only. On version conflict: show "Existing project has {pkg}@{existing}. This skill requires {pkg}@{required}. [U]pgrade / [K]eep existing / [S]kip?" Wait for developer choice.
- **Does not exist** -> new project. Run `npm init -y`.

Install dependencies:
```bash
npm install react react-dom clsx tailwind-merge
npm install -D vite @vitejs/plugin-react tailwindcss @tailwindcss/vite
npm install -D storybook @storybook/react-vite @storybook/addon-docs @storybook/addon-a11y @storybook/addon-viewport
npm install -D @storybook/addon-designs @chromatic-com/storybook
npm install -D vitest @vitest/ui jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom
```

If `config.language === "typescript"`:
```bash
npm install -D typescript @types/react @types/react-dom
```

Create config files (skip each if it already exists):

**vite.config.ts:**
```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { '@': '/src' } },
});
```

**.storybook/main.ts:**
```ts
import type { StorybookConfig } from '@storybook/react-vite';

const config: StorybookConfig = {
  stories: ['../src/**/*.stories.@(js|jsx|ts|tsx)'],
  addons: [
    '@storybook/addon-docs',
    '@storybook/addon-a11y',
    '@chromatic-com/storybook',
    '@storybook/addon-designs',
  ],
  framework: { name: '@storybook/react-vite', options: {} },
};
export default config;
```

**.storybook/preview.ts:**
```ts
import type { Preview } from '@storybook/react';
import { INITIAL_VIEWPORTS } from '@storybook/addon-viewport';

const preview: Preview = {
  parameters: {
    layout: 'centered',
    viewport: {
      viewports: INITIAL_VIEWPORTS,
    },
  },
};
export default preview;
```

**index.html:**
```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Design System</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**src/main.tsx:**
```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <div>Design System</div>
  </StrictMode>
);
```

Add to `.gitignore` if not present: `.figma-migration.json` and `.figma-learnings.json`

After SETUP completes, advance `phase` to `ATOMS`.

---

## ERROR handling

On unrecoverable failure in any skill, write to state file:
```json
{ "phase": "ERROR", "errorPhase": "{failed phase}", "errorMessage": "{description}", "retryCount": 1 }
```

On next invocation when `phase === "ERROR"`:
```
Migration stopped at {errorPhase}: {errorMessage}

Options:
  [R] Retry   — re-enter {errorPhase} from the beginning
  [S] Skip    — mark {errorPhase} as done and continue (warning: fidelity may be incomplete)
  [A] Abort   — stop migration (state file preserved for inspection)
```

After 3 retries on the same phase: surface to developer and wait. Do not auto-skip.

Retry policy:
- figma-extract: retry API call up to 3x; on HTTP 413 switch to paginated extraction
- figma-tokens: re-read manifest and regenerate files
- figma-component: skip `progress.{layer}.done[]`; retry only `pending[]`
- figma-behaviour: skip components already in `behaviours.done[]`
- figma-pages: skip pages already in `pages.done[]`
- figma-verify: re-read generated files and re-run checklist

---

## PHASE: DONE (inline)

Generate `docs/migration-report.md`:

```markdown
# Migration Report — {ProjectName}
Generated: {date}

## Fidelity Summary (token fidelity — structural issues tracked separately)
# Bar: 12 chars wide. Filled char = 1/12 of 100% (~8.3%). Empty char = unfilled.
Atoms      {N}/{N}  {bar}  {XX}% avg
Molecules  {N}/{N}  {bar}  {XX}% avg
Organisms  {N}/{N}  {bar}  {XX}% avg
Pages      {N}/{N}  {bar}  {XX}% avg

Overall: ~{XX}%
Target:  >=93% (first pass), >=98% (after VERIFY)

## Behaviour Summary
Hooks generated:                {N}
TODO-only (manual completion):  {N}
| Component | Hook type | Status |
|---|---|---|
| Button    | useModal  | generated |
| Carousel  | useAutoAdvance | TODO: add business logic |

## Structural Issues (patterns #7, #8, #9 — resolved before this report)
| Component | Pattern | Issue | Resolution |
|---|---|---|---|
| (empty if none) | | | |

## Token Issues Resolved
Critical:    {N} auto-fixed
Important:   {N} developer decisions
Suggestions: {N} logged

## Non-Figma Additions
| Component | Class / Property | Justification |
|---|---|---|
| Button | focus-visible:outline | WCAG 2.1 keyboard focus (2.4.7) |

## Component Index
| Component | Layer | Figma node | Fidelity | Notes |
|---|---|---|---|---|
| Button    | atom     | 510:401 | 100% | |
| Card      | molecule | 521:88  | 87% warning | blendMode escalated |
```

Components below 90% fidelity are marked with a warning in the Component Index.

Commit `docs/migration-report.md`. Set `phase` to `DONE` in the state file.

Print summary:
```
Migration complete!
Fidelity: ~XX% overall (atoms: XX%, molecules: XX%, organisms: XX%, pages: XX%)
Report: docs/migration-report.md
```

**Learning system — proposal engine:**

After printing the summary, check `learnings[]` in the state file.

If `learnings[]` is empty: migration complete. Skip the proposal engine.

If `learnings[]` is non-empty, run these steps:

1. Group events by `(type, signal)` — NOT by signal alone. Count frequency per group within this migration.

2. For each group, check against existing entries in both JSON learning files to determine if this is new or a frequency increment:
   - Global file: `~/.claude/figma-to-storybook-learnings.json`
   - Project file: `.figma-learnings.json`

3. Promotion check: for each project-file entry to be updated, check if it now meets the global threshold (cumulative frequency >= 5 AND projects >= 2 in the global file for that `(type, signal)`). If yes: mark as global promotion candidate, set `promotedToRule: true` on the project entry.

4. Assign confidence per group:
   - frequency = 1, not seen before -> MEDIUM
   - frequency = 2 -> MEDIUM-HIGH
   - frequency >= 3 OR seen in prior run -> HIGH
   - global promotion candidate (>=5 across >=2 projects) -> HIGH + "global candidate" label

5. Render proposal block:
```
=====================================
  WHAT I LEARNED — {N} proposals
=====================================

[1] CLASSIFICATION RULE (project)
    Signal: classify:Card:semanticType
    Learned: default -> card  (applied 3x this migration)
    -> Confidence: HIGH

[2] TRANSLATION GAP (project)
    Property: blendMode MULTIPLY
    Mapping: -> mix-blend-multiply
    -> Confidence: MEDIUM (1 occurrence)

[3] AUTO-FIX PROMOTION (global candidate)
    Pattern: verify:text-align-center
    Seen in: 2 projects, 6x total
    -> Confidence: HIGH — ready for global rule

Apply these learnings?
  [A] All  [1,2] Select  [N] None
=====================================
```

6. Wait for developer input:
   - `A` -> apply all
   - Comma-separated numbers (e.g. `1,3`) -> apply only listed. If out of range: re-prompt.
   - `N` -> discard all, write nothing
   - Other -> re-prompt

7. For each approved proposal:
   - Always upsert into project file (`.figma-learnings.json`)
   - Upsert into global file only if `promotedToRule: true`
   - Read-then-write: read current `frequency`, increment by occurrences in this batch. Safe for re-application after interruption.
   - Never modify any skill file.

8. Clear `learnings[]`: set to `[]` in state file and write immediately. Only after complete developer response.

9. Migration is complete.

---

## Fidelity targets

- First pass: >=93% per layer
- After VERIFY auto-fixes: >=98% per layer
- Below 90%: component marked with warning in report
