# PRD — Static Landing Page (Ralph Loop Test)

## Goal
Build a single-page, dependency-free **static website** (`index.html` + CSS + minimal JS)
that demonstrates a polished, non-template landing page. No frameworks, no build step —
it must open correctly by double-clicking `index.html`.

This file is the single source of truth. The agent reads it every iteration.

## Agent Operating Rules (Ralph Loop)
- Complete **exactly ONE unchecked task** per iteration (the lowest-numbered `[ ]`).
- Read `AGENTS.md` (if present) and follow any project-specific guardrails in it.
- Verify the task against its **Done when** criteria by running concrete checks before marking it complete.
- **If verification fails**: fix the issue and re-verify. If you still cannot satisfy **Done when**, do **NOT** mark `[x]` and do **NOT** commit — leave it `[ ]`, append `TASK <n> BLOCKED — <short reason>` to `progress.txt`, and stop.
- **If verification passes**: mark the task `[x]` in `PRD.md`, **append** a line to `progress.txt` (`TASK <n> DONE — <one-line summary>`, never delete history), and commit the task's code changes **together with `PRD.md` and `progress.txt`** in a single commit (`feat: task <n> — <summary>`).
- Do NOT start the next task in the same iteration. Stop after one.

## Design Direction (do NOT produce a generic template)
Style: **Editorial / Swiss** — confident type, generous asymmetric whitespace, one accent.
Not dark-mode by default; warm-paper light theme.

### Palette (define as CSS custom properties, use oklch)
- `--color-surface: oklch(97% 0.01 90)`  (warm paper)
- `--color-text: oklch(22% 0.02 60)`     (near-black ink)
- `--color-muted: oklch(52% 0.02 60)`
- `--color-accent: oklch(62% 0.19 25)`   (vermilion)
- `--color-line: oklch(88% 0.01 90)`

### Typography (max two families, `font-display: swap`)
- Display/headings: a serif (e.g. "Fraunces" or system serif fallback) — high scale contrast.
- Body/UI: a grotesque sans (e.g. "Inter" or system-ui).
- Use `clamp()` for a fluid type scale; hero should be dramatically larger than body.

### Non-negotiables
- Semantic HTML: `<header><nav><main><section><footer>`, one `<h1>`.
- Animate only `transform` / `opacity`. No layout-property animation.
- Respect `prefers-reduced-motion`.
- Design tokens centralized — no repeated hardcoded colors/spacing.

## Target Structure
```
index.html
styles/tokens.css
styles/global.css
styles/typography.css
scripts/main.js
```

## Tasks
- [ ] 1. Create `index.html` skeleton: semantic `<header><main><footer>`, `<meta name="viewport">`,
      `lang` attribute on `<html>`, `<link>`s to the three CSS files (`styles/tokens.css`,
      `styles/global.css`, `styles/typography.css`), and `<script defer src="scripts/main.js">`.
      **Done when:** `test -f index.html` succeeds and `grep -qE '<html[^>]+lang=' index.html && grep -q 'styles/tokens.css' index.html && grep -q 'styles/global.css' index.html && grep -q 'styles/typography.css' index.html && grep -q 'scripts/main.js' index.html && grep -q '<header' index.html && grep -q '<main' index.html && grep -q '<footer' index.html` exits 0.
- [ ] 2. Create `styles/tokens.css` with the full palette + a fluid type scale + spacing tokens
      as `:root` custom properties (use the values above).
      **Done when:** `test -f styles/tokens.css` succeeds and `grep -q ':root' styles/tokens.css && grep -q -- '--color-surface' styles/tokens.css && grep -q -- '--color-text' styles/tokens.css && grep -q -- '--color-muted' styles/tokens.css && grep -q -- '--color-accent' styles/tokens.css && grep -q -- '--color-line' styles/tokens.css && grep -q 'clamp(' styles/tokens.css` exits 0.
- [ ] 3. Create `styles/global.css`: modern reset, `box-sizing: border-box`, base `body` using
      `var(--color-surface)` and `var(--color-text)`, sensible container max-width, and
      `@media (prefers-reduced-motion: reduce)` guard.
      **Done when:** `test -f styles/global.css` succeeds and `grep -q 'border-box' styles/global.css && grep -q 'var(--color-surface)' styles/global.css && grep -q 'var(--color-text)' styles/global.css && grep -q 'prefers-reduced-motion' styles/global.css` exits 0.
- [ ] 4. Create `styles/typography.css`: pair serif headings with grotesque/system sans body
      using the `clamp()` type scale (if web fonts are loaded, include `font-display: swap` or
      `&display=swap`; system font stacks are also acceptable).
      **Done when:** `test -f styles/typography.css && grep -qi 'serif' styles/typography.css && grep -qiE 'sans|system-ui' styles/typography.css && grep -qE 'h1\b' styles/typography.css && (! grep -qi '@font-face' styles/typography.css || grep -qi 'font-display:[[:space:]]*swap' styles/typography.css)` exits 0.
- [ ] 5. Build the `<header>` with `<nav aria-label="Main navigation">`: brand mark + at least
      3 links, with explicit `:hover` and `:focus-visible` styles.
      **Done when:** `grep -q 'aria-label="Main navigation"' index.html && [ "$(grep -c '<a[[:space:]>]' index.html)" -ge 3 ] && grep -q ':focus-visible' styles/*.css` exits 0.
- [ ] 6. Build the hero `<section aria-labelledby="hero-heading">`: oversized `<h1 id="hero-heading">`,
      supporting paragraph, primary + ghost CTA links/buttons in an asymmetric editorial layout.
      **Done when:** `grep -q 'aria-labelledby="hero-heading"' index.html && [ "$(grep -c '<h1[[:space:]>]' index.html)" -eq 1 ] && grep -q 'id="hero-heading"' index.html && node -e "const fs=require('fs'); const h=fs.readFileSync('index.html','utf8'); const m=h.match(/<section[^>]*aria-labelledby=\"hero-heading\"[\s\S]*?<\/section>/); if(!m) process.exit(1); const ctas=(m[0].match(/<(?:a|button)\b/g)||[]).length; if(ctas<2) process.exit(1);"` exits 0.
- [ ] 7. Build a features/bento `<section>`: 3–4 cards with intentional asymmetric grid rhythm,
      hover elevation using `transform` / `opacity` only (no `all` or layout-property transitions).
      **Done when:** `[ "$(grep -c '<article' index.html)" -ge 3 ] && grep -q 'transform' styles/global.css && ! grep -qE 'transition:[^;]*(all|width|height|top|left|margin|padding)' styles/*.css` exits 0.
- [ ] 8. Build the `<footer>`: contact/links and a fine top border using `var(--color-line)`.
      **Done when:** `grep -q 'border-top' styles/global.css && grep -q 'var(--color-line)' styles/global.css && grep -A 20 '<footer' index.html | grep -q '<a '` exits 0.
- [ ] 9. Responsive pass for 320 / 375 / 768 / 1024 / 1440: add `@media` rules so nav and grids
      adapt cleanly without horizontal overflow (`overflow-x: clip` or safe fluid grids; avoid fixed
      4-digit `width` declarations while `max-width`/`min-width` are allowed).
      **Done when:** `[ "$(grep -c '@media' styles/global.css)" -ge 2 ] && ! grep -qE '(^|[;{[[:space:]])width:[[:space:]]*[0-9]{4,}px' styles/*.css` exits 0.
- [ ] 10. Create `scripts/main.js`: entrance reveal (`opacity`/`transform`) via `IntersectionObserver`,
      bypassed immediately when `window.matchMedia('(prefers-reduced-motion: reduce)').matches` is true.
      **Done when:** `test -f scripts/main.js && node --check scripts/main.js && grep -q 'IntersectionObserver' scripts/main.js && grep -q 'prefers-reduced-motion' scripts/main.js` exits 0.
- [ ] 11. Accessibility + polish pass: verify all `<img>` tags (if any) have `alt`, only one `<h1>`
      exists, all local `href`/`src` asset paths resolve to existing files, and headings do not skip levels.
      **Done when:** `node -e "const fs=require('fs'); const h=fs.readFileSync('index.html','utf8'); if((h.match(/<h1\b/g)||[]).length!==1) throw 'need 1 h1'; const imgs=h.match(/<img[^>]*>/g)||[]; if(!imgs.every(i=>/\balt=/.test(i))) throw 'missing alt'; const assets=[...h.matchAll(/(?:href|src)=\"(styles\/[^\"]+|scripts\/[^\"]+)\"/g)].map(m=>m[1]); if(!assets.length || !assets.every(a=>fs.existsSync(a))) throw 'missing assets: '+assets; console.log('A11Y_AND_ASSET_CHECK_OK');"` prints `A11Y_AND_ASSET_CHECK_OK`.

## Definition of Done (whole project)
All 11 tasks `[x]`, `scripts/main.js` passes `node --check`, all local CSS/JS asset references in `index.html` exist, and opening `index.html` in a browser renders the Editorial/Swiss landing page with no console errors.
