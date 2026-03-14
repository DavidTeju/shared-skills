---
name: svelte-best-practices
description: Svelte 5 best practices including runes ($state, $derived, $effect), dependency tracking patterns, ESLint configuration, and component patterns
user-invocable: false
---

# Svelte 5 Best Practices

Reference for Svelte 5 runes mode. Assumes familiarity with Svelte basics.

---

## Runes

### $state

- Only use `$state` for values that drive reactivity (effects, derived, template).
- `$state({...})` / `$state([...])` gives deep reactivity via proxies. Use `$state.raw` for large objects that only get reassigned (e.g., API responses) to avoid proxy overhead.

### $derived

Compute values from state with `$derived`, never with `$effect`:

```js
// Good
let square = $derived(num * num);

// Bad — don't use effects to compute values
let square;
$effect(() => { square = num * num; });
```

- `$derived` takes an expression. Use `$derived.by(() => ...)` for complex logic.
- Derived values are writable (assignable like `$state`), but re-evaluate when deps change.

### $props

Props can change at any time. Anything derived from props needs `$derived`:

```js
// Correct — updates when type changes
let color = $derived(type === 'danger' ? 'red' : 'green');

// Wrong — color is computed once and never updates
let color = type === 'danger' ? 'red' : 'green';
```

### $inspect.trace

Debug reactivity issues by adding `$inspect.trace(label)` as the first line in `$effect` or `$derived.by` to trace which dependencies triggered an update.

---

## $effect — Patterns and Pitfalls

**$effect is an escape hatch. Use it minimally.**

### When NOT to use $effect

| Instead of $effect... | Use this |
|---|---|
| Sync state to external lib (D3) | `{@attach ...}` |
| Respond to user interaction | Event handler or function binding |
| Compute a value from state | `$derived` |
| Debug reactive values | `$inspect` |
| Observe external data | `createSubscriber` |

Never wrap effect contents in `if (browser) {...}` — effects already skip SSR.

### Dependency Tracking

Svelte tracks dependencies by detecting which reactive values are **read** during effect execution. There are no explicit dependency arrays — [GitHub issues #9248 and #13207 requesting them were closed as "not planned"](https://github.com/sveltejs/svelte/issues/9248).

**Svelte reactivity only tracks its own primitives** (`$state`, `$derived`, `$props`). DOM properties like `scrollHeight`, `offsetWidth` are plain reads — NOT tracked. If you need to react to DOM changes caused by state changes, depend on the state, not the DOM property.

### void + untrack Pattern (Explicit Dependency Control)

When an effect needs specific triggers but its logic reads other reactive values or DOM properties, use `void` to declare dependencies and `untrack()` to isolate logic:

```svelte
<script>
  import { untrack } from 'svelte';

  let { messages, streamingText, pendingPermissions } = $props();
  let container;

  $effect.pre(() => {
    // Declare dependencies — void evaluates (registers with tracker) and discards
    void messages.length;
    void streamingText;
    void pendingPermissions;

    untrack(() => {
      // Logic reads DOM properties freely without registering them as deps
      const threshold = 200;
      if (container.scrollHeight - container.scrollTop < threshold) {
        container.scrollTo(0, container.scrollHeight);
      }
    });
  });
</script>
```

- The official docs show bare `messages.length;` statements in `$effect.pre` to declare dependencies.
- `void val;` is the **lint-safe** version — identical runtime behavior, no ESLint warnings (except `sonarjs/void-use`, see ESLint section).
- Svelte maintainer dummdidumm's endorsed pattern for explicit deps: read deps via a function, then `untrack(fn)` for logic.

### $effect.pre vs $effect

- `$effect.pre` runs **before** DOM updates (equivalent to `beforeUpdate`). Use for scroll management, DOM measurement before paint.
- `$effect` runs **after** DOM updates.

---

## Auto-resize Textarea (Ranked Approaches)

1. **`field-sizing: content`** — Pure CSS, no JS. ~80% browser support (not Firefox).
2. **`oninput` handler** — Idiomatic Svelte 5, no $effect. Only handles user input.
3. **`$effect` with natural read** — Needed when text changes programmatically.
4. **Hidden `<pre>` mirror** — Official Svelte playground approach, no JS height calc.
5. **Svelte action (`use:autosize`)** — Reusable across textareas.

---

## Events

```svelte
<!-- Standard -->
<button onclick={() => doThing()}>click</button>

<!-- Shorthand -->
<button {onclick}>click</button>

<!-- Spread -->
<button {...props}>click</button>

<!-- Window/document events — don't use onMount/$effect for these -->
<svelte:window onkeydown={handleKey} />
<svelte:document onvisibilitychange={handleVisibility} />
```

---

## Snippets

Reusable markup chunks, replacing slots:

```svelte
{#snippet greeting(name)}
  <p>hello {name}!</p>
{/snippet}

{@render greeting('world')}
```

- Top-level snippets work inside `<script>`.
- Stateless snippets work in `<script module>` and can be exported.

---

## Each Blocks

Always use keyed each blocks. Keys must uniquely identify items — never use indices:

```svelte
{#each items as item (item.id)}
  <Item {item} />
{/each}
```

Skip destructuring when mutating items (e.g., `bind:value={item.count}`).

---

## Styling

### JS Variables in CSS

```svelte
<div style:--columns={columns}>...</div>

<style>
  div { grid-template-columns: repeat(var(--columns), 1fr); }
</style>
```

### Styling Child Components

Prefer CSS custom properties. Fall back to `:global` only when necessary:

```svelte
<!-- Parent -->
<Child --color="red" />

<!-- Child -->
<style>
  h1 { color: var(--color); }
</style>
```

```svelte
<!-- Override when custom properties aren't an option -->
<div>
  <Child />
</div>

<style>
  div :global {
    h1 { color: red; }
  }
</style>
```

---

## Context

Prefer context over shared module state. Module-level state leaks between users during SSR.

Use `createContext` over `setContext`/`getContext` for type safety.

---

## ESLint Configuration for Svelte

### sonarjs/void-use

The `void` dependency pattern is canonical Svelte 5. Disable this rule for `.svelte` files:

```js
// eslint.config.js
{
  files: ['**/*.svelte'],
  rules: {
    'sonarjs/void-use': 'off',
  },
}
```

### import-x/no-unresolved

SvelteKit virtual modules need to be ignored:

```js
{
  rules: {
    'import-x/no-unresolved': ['error', {
      ignore: ['^\\$app/', '^\\$env/', '^\\$service-worker']
    }],
  },
}
```

### import-x/no-duplicates

Svelte re-exports from `svelte/transition`, `svelte/easing`, etc. may trigger false warnings. Suppress per-case if needed.

---

## Legacy Feature Replacements

| Legacy | Svelte 5 Replacement |
|---|---|
| `let count = 0` (implicit reactivity) | `$state` |
| `$:` statements | `$derived` / `$effect` |
| `export let` / `$$props` / `$$restProps` | `$props` |
| `on:click={...}` | `onclick={...}` |
| `<slot>` / `$$slots` / `<svelte:fragment>` | `{#snippet}` / `{@render}` |
| `<svelte:component this={...}>` | `<DynamicComponent>` |
| `<svelte:self>` | Direct self-import |
| Stores | Classes with `$state` fields |
| `use:action` | `{@attach ...}` |
| `class:` directive | `class` with clsx-style arrays/objects |

---

## Async (Experimental)

Svelte 5.36+ supports await expressions in components. Requires `experimental.async` in `svelte.config.js`. Not stable — use cautiously.
