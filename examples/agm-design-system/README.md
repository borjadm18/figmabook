# AGM Design System — Example Migration

A real migration of the AGM Design System from Figma to Storybook, produced using the figma-to-storybook skill suite.

**Figma file ID:** r42MHxXYkMWRiuaVs6PoHu
**Components migrated:** 14 (4 atoms, 5 molecules, 5 organisms)
**Stack:** React 19 + TypeScript + Tailwind CSS 4 + Storybook 10 + Vitest

## Components

**Atoms:** Button, Input, Link, Tag

**Molecules:** Accordion, Card, Dropdown, Stepper, Tabs

**Organisms:** CTA, Footer, HeroBanner, Modal, Testimonials

## What was generated

- `src/components/` — 14 components, each with `.tsx` + `.stories.tsx` + `.test.tsx`
- `tailwind.config.ts` — Design tokens from Figma (colors, spacing, typography, shadows)
- `src/tokens/index.ts` — JS token constants
- `src/lib/utils.ts` — `cn()` helper (clsx + tailwind-merge)
- `docs/migration-report.md` — Fidelity scores per component

## Source project

The full generated output lives at:
`C:/Users/novic/OneDrive/Escritorio/Figmabook/design-system`

75 tests passing. Storybook running on port 6006.
