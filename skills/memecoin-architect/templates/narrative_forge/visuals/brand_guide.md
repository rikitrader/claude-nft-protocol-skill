# {TOKEN_NAME} ({TICKER}) — Brand Guide

> Auto-generated from MEMECOIN_BRIEF.md by the Narrative Forge engine.
> Replace all `{VARIABLE}` placeholders with your specific values.

---

## Logo Usage

| Rule | Specification |
|------|---------------|
| Minimum size | 32 x 32 px |
| Clear space | 1x logo width on all sides |
| Backgrounds | Dark preferred, light with dark logo variant |
| Prohibited | Do NOT stretch, rotate, skew, recolor, or add effects |

### Logo Variants

```
Primary:    Full color on dark background (#0A0A0F)
Secondary:  Monochrome white on dark
Tertiary:   Monochrome dark on light
Favicon:    Simplified mark only (no text)
```

---

## Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| Primary | {PRIMARY_COLOR} | CTAs, headers, key indicators |
| Secondary | {SECONDARY_COLOR} | Accents, links, hover states |
| Burn Orange | #FF6B35 | Burn metrics, destructive actions |
| Cyan Glow | #00F0FF | Connected states, live indicators |
| Background | #0A0A0F → #12121A | Gradient dark mode default |
| Surface | rgba(255,255,255,0.05) | Card backgrounds |
| Text Primary | #FFFFFF | Headings, important text |
| Text Secondary | rgba(255,255,255,0.6) | Body text, descriptions |
| Text Muted | rgba(255,255,255,0.3) | Labels, timestamps |

---

## Typography

| Element | Font | Weight | Size |
|---------|------|--------|------|
| Headlines (H1-H3) | Space Grotesk | Bold (700) | 32-48px |
| Subheadlines (H4-H6) | Space Grotesk | Medium (500) | 18-24px |
| Body | Inter | Regular (400) | 14-16px |
| Labels | Inter | Medium (500) | 10-12px, uppercase, tracked |
| Code/Data | JetBrains Mono | Regular (400) | 13-14px |
| Numbers/Stats | Space Grotesk | Bold (700) | 24-64px |

### Font Loading

```html
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
```

---

## Tone of Voice

### DO
- **Confident** but not arrogant — "We built this" not "We're the best"
- **Memetic** but not cringe — Wit over memes-for-the-sake-of-memes
- **Technical** when needed — Show the on-chain proof
- **Community-first** — "We" not "I"
- **Transparent** — Acknowledge risks openly

### DON'T
- NEVER promise returns or price targets
- NEVER use "guaranteed", "safe investment", "to the moon"
- NEVER attack competitors by name (compare mechanics, not teams)
- NEVER use fake urgency ("LAST CHANCE", "RUNNING OUT")
- NEVER use 🚀 more than once per post

---

## Social Media Handles

| Platform | Handle | URL |
|----------|--------|-----|
| X/Twitter | @{TICKER}token | x.com/{TICKER}token |
| Telegram | {TICKER}community | t.me/{TICKER}community |
| Discord | {TICKER} | discord.gg/{TICKER} |
| GitHub | {REPO} | github.com/{REPO} |
| Website | {WEBSITE} | {WEBSITE} |

---

## Banner Dimensions

| Platform | Size (px) | Format | Notes |
|----------|-----------|--------|-------|
| X/Twitter header | 1500 x 500 | PNG/JPG | Safe area: center 1200x400 |
| X/Twitter post | 1200 x 675 | PNG/JPG | 16:9 ratio |
| Telegram group | 1280 x 720 | PNG/JPG | Top-center crop on mobile |
| Discord banner | 960 x 540 | PNG | Shows at top of server |
| OG Image | 1200 x 630 | PNG | For link previews |
| Favicon | 32 x 32 | ICO/PNG | Simplified mark only |

---

## AI Image Prompts

Use these with DALL-E 3 or Midjourney v6+ to generate on-brand visuals.

| # | Type | Prompt |
|---|------|--------|
| 1 | Hero | `{STYLE}, {MASCOT} standing triumphantly, {CHAIN} logo glowing in background, cinematic lighting, 4K` |
| 2 | Burn | `{STYLE}, {MASCOT} throwing tokens into a bonfire, dramatic flames, deflationary energy, dark background with cyan sparks` |
| 3 | Community | `{STYLE}, army of {MASCOT}s marching together, banner with {TICKER}, epic wide shot` |
| 4 | Moon | `{STYLE}, {MASCOT} riding a rocket past the moon, {TOKEN_NAME} logo on rocket, space theme` |
| 5 | Treasury | `{STYLE}, {MASCOT} guarding a vault of gold, multisig keys floating around, warm lighting` |
| 6 | Launch | `{STYLE}, {MASCOT} pressing a big red launch button, countdown at 00:00, neon glow` |
| 7 | Chart | `{STYLE}, {MASCOT} surfing a green candlestick chart wave, bullish energy, dynamic pose` |
| 8 | Diamond | `{STYLE}, {MASCOT} holding token with diamond hands, crystalline effects, clean background` |
| 9 | Banner | `{STYLE}, wide format (1500x500), {MASCOT} centered, {TOKEN_NAME} text left, gradient {PRIMARY_COLOR} to {SECONDARY_COLOR}` |
| 10 | PFP | `{STYLE}, {MASCOT} portrait headshot, looking confident, circular crop friendly, solid {PRIMARY_COLOR} background` |
