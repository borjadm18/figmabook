# figma-component

Generates a TSX component, Storybook story, and Vitest test for each component in a given layer.

**Trigger:** Invoked by figma-to-storybook orchestrator with current layer: `atoms` | `molecules` | `organisms`.
**Input:** `.figma-migration.json` with `manifest.{layer}[]` populated and `progress.{layer}.pending[]` non-empty.
**Output:** For each component in pending[]: `{ComponentName}.tsx`, `{ComponentName}.stories.tsx`, `{ComponentName}.test.tsx`

---

## Component generation loop

For each component in `progress.{layer}.pending[]`:
1. Generate the 3 files (see templates below)
2. Move the component name from `progress.{layer}.pending[]` to `progress.{layer}.done[]`
3. Write the updated state to `.figma-migration.json`
4. Proceed to the next component

---

### Non-Figma Value Rule

Any Tailwind class in a generated file that does NOT correspond to a manifest field **MUST** be annotated with a JSX comment immediately before the element:

```tsx
{/* ✦ NOT IN FIGMA — {reason, e.g. "added for WCAG 2.1 keyboard focus (2.4.7)"} */}
<element
  className={cn(
    'existing-figma-classes',
    'focus-visible:outline-2 focus-visible:outline-offset-2', // non-figma addition
  )}
/>
```

Classes without this annotation and without a manifest source are fidelity errors. The Verification Engine flags them as 🟡 Important.

### Per-variant generation

`variants[]` in the manifest lists every variant from the Figma COMPONENT_SET. Generate a CSS modifier class for each variant. If a variant has different token values (different font-size, spacing, color), extract those values separately. No variant may be omitted.

---

## HTML Semantic Rules

Violations of these rules are **Critical** issues in VERIFY_LAYER. They must be corrected before advancing to the next layer.

#### Pattern #7 — Element nesting

| Figma node type | Required HTML element |
|---|---|
| Root frame / page section | `<section>` (with `aria-label`) or `<div>` |
| Primary heading text | `<h2>` or `<h3>` — never `<p>` for headings |
| Secondary / body text | `<p>` |
| Navigation group | `<nav><ul><li>` |
| Link in navigation (has href) | `<a>` — never `<button>` |
| Action that triggers JS (no href) | `<button type="button">` — never `<a>` |
| Image with meaning | `<img alt="{description}">` (non-empty alt) |
| Decorative image | `<img alt="">` |
| Quote / testimonial text | `<figure><blockquote>…</blockquote><figcaption>…</figcaption></figure>` (applied when `semanticType: testimonial`) |
| List of cards / tags | `<ul><li>` or `<ol><li>` |

#### Pattern #8 — React Fragment key

When mapping an array and returning multiple sibling elements, always use `React.Fragment` with an explicit `key`. The `<>` shorthand does not accept a `key` prop.

```jsx
import React from 'react'; // Required even with JSX transform

{items.map((item, i) => (
  <React.Fragment key={item.id ?? i}>
    <dt>{item.label}</dt>
    <dd>{item.value}</dd>
  </React.Fragment>
))}
```

#### Pattern #9 — Focus trap (applies when `semanticType: overlay`)

Any component with `semanticType: overlay` (modal, dialog, drawer, popover) **must** include both of these `useEffect` blocks. VERIFY_LAYER checks for the presence of both blocks and the `previousFocus.current?.focus()` restore.

```jsx
import { useEffect, useRef } from 'react';

const overlayRef    = useRef(null);
const previousFocus = useRef(null);

// Effect 1: move focus in on open, restore on close
useEffect(() => {
  if (isOpen) {
    previousFocus.current = document.activeElement;
    const first = overlayRef.current?.querySelector(
      'button,[href],input,select,textarea,[tabindex]:not([tabindex="-1"])'
    );
    first?.focus();
  } else {
    previousFocus.current?.focus();
  }
}, [isOpen]);

// Effect 2: Tab trap + Escape
useEffect(() => {
  if (!isOpen) return;
  const onKey = (e) => {
    if (e.key === 'Escape') { onClose(); return; }
    if (e.key !== 'Tab') return;
    const focusable = Array.from(
      overlayRef.current?.querySelectorAll(
        'button,[href],input,select,textarea,[tabindex]:not([tabindex="-1"])'
      ) ?? []
    );
    if (!focusable.length) { e.preventDefault(); return; }
    const first = focusable[0], last = focusable[focusable.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  };
  document.addEventListener('keydown', onKey);
  return () => document.removeEventListener('keydown', onKey);
}, [isOpen, onClose]);
```

---

## File Templates

Output directory per component:
```
src/components/{layer}/{ComponentName}/
  ├── {ComponentName}.tsx
  ├── {ComponentName}.stories.tsx
  └── {ComponentName}.test.tsx
```

### TSX Component template (TypeScript + Tailwind)

```tsx
import { cn } from '@/lib/utils';

interface {ComponentName}Props {
  variant?: {variants as TypeScript union type, e.g. 'primary' | 'secondary' | 'large'};
  // One prop per booleanProps[] entry: propName?: boolean;
  // One prop per instanceSwaps[] entry: propName?: React.ReactNode;
  className?: string;
}

export function {ComponentName}({
  variant = '{first variant from manifest.variants[]}',
  className,
  // other destructured props
}: {ComponentName}Props) {
  return (
    <{semantic HTML element per Pattern #7}
      className={cn(
        // Figma: nodeId={nodeId} | semanticType={semanticType}
        '{base Tailwind classes from manifest tokens — see Tailwind Translation Rules below}',
        {
          '{variant-specific classes}': variant === '{variantName}',
          // one entry per variant
        },
        className
      )}
    >
      {/* content */}
    </{semantic HTML element}>
  );
}
```

### Tailwind Translation Rules

Map each manifest field to a Tailwind class using these rules (REQUIRED — every applicable rule must be applied):

| Manifest field | Tailwind class | Notes |
|---|---|---|
| `fills[].hex` matching `tailwind.config.ts` color | `bg-{token}` or `text-{token}` | Use named token |
| `fills[].hex` NOT in `tailwind.config.ts` | `bg-[#XXXXXX]` | Arbitrary value |
| `fontSize` matching `tailwind.config.ts` fontSize key | `text-{token}` | Use named token |
| `fontSize` NOT in config | `text-[{N}px]` | Arbitrary value |
| `lineHeightPx` (standalone, not bundled in fontSize token) | `leading-[{N}px]` | Arbitrary |
| `fontWeight: 700` | `font-bold` | |
| `fontWeight: 600` | `font-semibold` | |
| `fontWeight: 400` | `font-normal` | |
| `fontWeight: 300` | `font-light` | |
| `letterSpacing` | `tracking-[{value}em]` | Convert px to em: value/fontSize |
| `paddingTop/Right/Bottom/Left` (equal all sides) | `p-{token}` or `p-[{N}px]` | |
| `paddingTop/Right/Bottom/Left` (equal top+bottom, left+right) | `px-[{N}px] py-[{N}px]` | |
| `paddingTop/Right/Bottom/Left` (all different) | `pt-[{N}px] pr-[{N}px] pb-[{N}px] pl-[{N}px]` | |
| `itemSpacing` + `isAutoLayout: true` matching spacing token | `gap-{token}` | Use named token |
| `itemSpacing` + `isAutoLayout: true` NOT in token | `gap-[{N}px]` | Arbitrary |
| `isAutoLayout: false` — calculate gap from child positions | `gap-[{calculated}px]` | xChild2 - xChild1 - widthChild1 |
| `cornerRadius` matching `tailwind.config.ts` borderRadius | `rounded-{token}` | |
| `cornerRadius` NOT in config | `rounded-[{N}px]` | Arbitrary |
| `effects[DROP_SHADOW]` matching boxShadow token | `shadow-{token}` | |
| `effects[DROP_SHADOW]` NOT in config | `shadow-[{offsetX}px_{offsetY}px_{blur}px_{spread}px_{rgba}]` | Arbitrary |
| `opacity ≠ 1` | `opacity-[{N}]` | e.g. `opacity-[0.5]` |
| `blendMode ≠ NORMAL` | `mix-blend-{mode}` on element + `isolate` on parent | e.g. `mix-blend-multiply` |
| `textCase: SMALL_CAPS_FORCED` | `[font-variant-caps:small-caps]` | Arbitrary property |
| `textCase: UPPER` | `uppercase` | |
| `textCase: LOWER` | `lowercase` | |
| `textCase: TITLE` | `capitalize` | |
| `textCase: ORIGINAL` | (nothing) | Browser default |
| `textAlignHorizontal: CENTER` | `text-center` | |
| `textAlignHorizontal: RIGHT` | `text-right` | |
| `textAlignHorizontal: JUSTIFIED` | `text-justify` | |
| `textAlignHorizontal: LEFT` | (nothing) | Browser default |
| `layoutGrow: 1` on child node | `flex-1` on that child element | |
| `isAutoLayout: true` with `counterAxisAlignItems: CENTER` | `items-center` | |
| `isAutoLayout: true` with `primaryAxisAlignItems: CENTER` | `justify-center` | |
| `strokes[N].hex` matching `tailwind.config.ts` color | `border border-{token}` | Apply to root element |
| `strokes[N].hex` NOT in config | `border border-[#{hex}]` | Arbitrary color |
| `strokes[N].weight: 1` | `border` (Tailwind default 1px) | Combined with color class |
| `strokes[N].weight: 2` | `border-2` | |
| `strokes[N].weight` other value | `border-[{N}px]` | Arbitrary width |
| `strokes[N].align: INSIDE` | `box-border` | Border-box sizing |

Add a `{/* Figma: {field}={value} */}` comment above each group of arbitrary-value classes.

### Story template

```tsx
// {ComponentName}.stories.tsx
import type { Meta, StoryObj } from '@storybook/react';
import { {ComponentName} } from './{ComponentName}';

const meta: Meta<typeof {ComponentName}> = {
  title: '{Layer}/{ComponentName}',
  component: {ComponentName},
  parameters: {
    layout: 'centered',
    design: {
      type: 'figma',
      url: '{manifest entry figmaUrl — exact URL with node-id}',
    },
  },
  argTypes: {
    variant: {
      control: 'select',
      options: [{manifest.variants[] as string array}],
    },
    // One argType per booleanProps[] entry: { control: 'boolean' }
    // One argType per instanceSwaps[] entry: { control: 'text' }
  },
};
export default meta;

type Story = StoryObj<typeof {ComponentName}>;

// Always include Default story
export const Default: Story = {
  args: { variant: '{first variant from manifest.variants[]}' },
};

// One additional exported story per remaining variant
export const {PascalCase variant name}: Story = {
  args: { variant: '{variantName}' },
};
```

Every variant in `manifest.variants[]` **must** have a corresponding exported story. This is checked by figma-verify.

### Test template

```tsx
// {ComponentName}.test.tsx
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi } from 'vitest';
import { {ComponentName} } from './{ComponentName}';

describe('{ComponentName}', () => {
  it('renders without crashing', () => {
    render(<{ComponentName} />);
  });

  // One test per variant
  it('applies {variantName} variant classes', () => {
    const { container } = render(<{ComponentName} variant="{variantName}" />);
    expect(container.firstChild).toHaveClass('{primary Tailwind class for this variant from Translation Rules}');
  });

  // If semanticType === 'overlay': add focus trap tests
  it('traps focus when open', async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();
    render(<{ComponentName} isOpen={true} onClose={onClose} />);
    const focusable = document.querySelectorAll(
      'button,[href],input,select,textarea,[tabindex]:not([tabindex="-1"])'
    );
    expect(focusable.length).toBeGreaterThan(0);
    await user.keyboard('{Escape}');
    expect(onClose).toHaveBeenCalledOnce();
  });

  // If semanticType === 'overlay': test focus restore
  it('restores focus on close', async () => {
    const trigger = document.createElement('button');
    document.body.appendChild(trigger);
    trigger.focus();
    const { rerender } = render(<{ComponentName} isOpen={true} onClose={() => {}} />);
    rerender(<{ComponentName} isOpen={false} onClose={() => {}} />);
    expect(document.activeElement).toBe(trigger);
    document.body.removeChild(trigger);
  });
});
```
