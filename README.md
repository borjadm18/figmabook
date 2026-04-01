# figma-to-storybook

Migrate any Figma design file to a fully documented Storybook component library — with maximum fidelity.

Built as a suite of [Claude Code](https://claude.ai/code) skills.

## What it does

- Extracts every component, token, and page from your Figma file
- Generates React + TypeScript + Tailwind CSS components
- Creates Storybook stories with Figma design links
- Adds Vitest tests for every component
- Generates custom hooks from Figma prototype interactions
- Composes full-page Storybook stories from your Figma page frames
- Verifies fidelity and auto-fixes common issues
- Produces a migration report with fidelity scores

## Requirements

- [Claude Code](https://claude.ai/code) installed
- A Figma account with access to the file you want to migrate
- Node.js 18+

## Install

**Mac / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/borjadm18/figmabook/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/borjadm18/figmabook/main/install.ps1 | iex
```

## Usage

1. Open Claude Code in any project directory
2. Type `/figma-to-storybook`
3. Follow the prompts (Figma file URL, language, test framework)

The migration is resumable — if it stops, just run `/figma-to-storybook` again.

## What gets generated

```
src/
├── components/
│   ├── atoms/       Button, Input, Tag...
│   ├── molecules/   Card, Accordion, Tabs...
│   └── organisms/   HeroBanner, Footer, Modal...
├── pages/           LandingPage, AboutPage... (Storybook stories)
├── tokens/          index.ts (color, spacing, typography constants)
└── lib/utils.ts     cn() helper (clsx + tailwind-merge)
tailwind.config.ts   Design tokens as Tailwind theme extensions
docs/
└── migration-report.md   Fidelity scores per component
```

## Example

See [`examples/`](examples/) for a sample migration.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
