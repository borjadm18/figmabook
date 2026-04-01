# Contributing

Each skill is a single Markdown file in `skills/`. They are independent — you can improve one without touching the others.

## Skill structure

Every skill starts with a name and trigger comment:
```
# skill-name

**Trigger:** when this skill is invoked
```

Skills read and write `.figma-migration.json` in the working directory. The state file schema is defined in `figma-to-storybook.md` (the orchestrator). **Never change the schema without updating all skills that read that field.**

## To improve a skill

1. Edit the relevant `skills/*.md` file
2. Verify: all required sections are present (no TBD/TODO placeholder content)
3. Verify: the state file fields you read/write exist in the schema in `figma-to-storybook.md`
4. PR with a clear description of what changed and why

## Skills and their responsibilities

| Skill | Touches state fields | Generates files |
|---|---|---|
| figma-extract | manifest, extractionProgress | none |
| figma-tokens | — | tailwind.config.ts, src/tokens/ |
| figma-component | progress.atoms / molecules / organisms | src/components/**/* |
| figma-behaviour | progress.behaviours | src/components/**/* (hooks + updated stories) |
| figma-pages | progress.pages | src/pages/**/* |
| figma-verify | — (reads progress, writes fidelity to report) | docs/migration-report.md |
| figma-to-storybook | phase, all fields | package.json deps, config files |

## Running locally

Install skills from your local clone instead of the remote:
```bash
cp skills/*.md ~/.claude/skills/
```

Then test with `/figma-to-storybook` in a project with a Figma file.
