# figma-pages

Generates Storybook Page stories from top-level Figma page frames.

**Trigger:** Invoked by figma-to-storybook orchestrator when phase=PAGES.
**Input:** `.figma-migration.json` with `manifest.pages[]` populated and `progress.pages.pending[]` non-empty.
**Output:** `src/pages/{PageName}/{PageName}.stories.tsx` and `{PageName}.test.tsx` per page.

---

## Page generation loop

For each page in `progress.pages.pending[]`:
1. Generate the 2 files (see templates below)
2. Move the page name from `progress.pages.pending[]` to `progress.pages.done[]`
3. Write the updated state to `.figma-migration.json`
4. Proceed to the next page

---

## Organism order

The order of organisms in the story JSX **must** match top-to-bottom Y order from Figma.

Sort `manifest.pages[N].childOrganisms[]` by the Y coordinate (`absoluteBoundingBox.y`) of each organism's root node in the Figma frame. The organism with the lowest Y value renders first.

If Y coordinates are not available in the manifest: preserve the order as extracted in CLASSIFY (which follows DOM tree order, which is typically top-to-bottom).

---

## Prop values

Determine real content values for organism props:

- **MCP mode:** Call `mcp__figma__get_design_context` for the page frame nodeId. Extract text content values from the returned code hints (headings, body text, CTA labels, image alt text). Use these as prop values.
- **REST mode:** Use text node content from the manifest if captured during EXTRACT. If not available, use descriptive placeholder strings that match the content type and context:
  - Headings: `"Main headline text"` (not `"Lorem ipsum"`)
  - Body text: `"Supporting description text"`
  - CTA labels: `"Call to action"`
  - Image alt: `"Descriptive image alt text"`

---

## Inter-organism spacing

If there is vertical spacing between organism sections in the Figma frame (gap between `absoluteBoundingBox` of consecutive organisms):

1. Calculate: `gap = organism2.absoluteBoundingBox.y - (organism1.absoluteBoundingBox.y + organism1.absoluteBoundingBox.height)`
2. If gap matches a `tailwind.config.ts` `spacing` token value → use `mt-{token}` on the second organism element
3. If gap > 0 and NOT in config → use `mt-[{gap}px]` arbitrary class
4. If gap = 0 → no margin class (organisms are flush)

---

## Story template

```tsx
// {PageName}.stories.tsx
// Figma: nodeId={manifest.pages[N].nodeId} | {viewport.width}×{viewport.height}
import type { Meta, StoryObj } from '@storybook/react';
import { {Organism1} } from '@/components/organisms/{Organism1}/{Organism1}';
import { {Organism2} } from '@/components/organisms/{Organism2}/{Organism2}';
// One import per organism in childOrganisms[] — in Y order

// Inline page composition — no separate React component file
function {PageName}() {
  return (
    <div className="min-h-screen flex flex-col">
      <{Organism1}
        // Props with real content values from Figma (see Prop values section)
        // Example: heading="Main headline" ctaLabel="Get started"
      />
      <{Organism2} className="mt-{token or [Npx]}" />
      {/* Additional organisms in Y order */}
    </div>
  );
}

const meta: Meta = {
  title: 'Pages/{PageName}',
  parameters: {
    layout: 'fullscreen',
    design: {
      type: 'figma',
      url: '{manifest.pages[N].figmaUrl}',
    },
  },
};
export default meta;

type Story = StoryObj;

export const Desktop: Story = {
  render: () => <{PageName} />,
  parameters: {
    viewport: { defaultViewport: 'desktop' },
  },
};

export const Tablet: Story = {
  render: () => <{PageName} />,
  parameters: {
    viewport: { defaultViewport: 'tablet' },
  },
};

export const Mobile: Story = {
  render: () => <{PageName} />,
  parameters: {
    viewport: { defaultViewport: 'mobile1' },
  },
};
```

**Critical:** Always use `layout: 'fullscreen'` — never `'centered'` for page stories. Without `fullscreen`, Storybook centers the page content and breaks the layout.

---

## Test template

```tsx
// {PageName}.test.tsx
import { render } from '@testing-library/react';
import { Desktop } from './{PageName}.stories';

describe('{PageName}', () => {
  it('renders all organisms without crashing', () => {
    // @ts-expect-error — StoryObj render is callable
    render(Desktop.render());
  });

  // One test per organism to confirm it mounts
  // Replace '{landmark}' with the appropriate semantic HTML element or ARIA role
  // e.g. 'header', 'footer', 'main', 'nav', '[role="banner"]'
  it('renders {Organism1}', () => {
    // @ts-expect-error
    render(Desktop.render());
    expect(document.querySelector('{semantic landmark of Organism1}')).toBeInTheDocument();
  });
});
```

---

## Output directory structure

```
src/
└── pages/
    └── {PageName}/
        ├── {PageName}.stories.tsx
        └── {PageName}.test.tsx
```

Create the `src/pages/{PageName}/` directory if it does not exist.
