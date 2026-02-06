# Module 9: "Narrative Forge" — Content Strategy Engine

## Purpose

Transform the research brief and token identity into launch-ready marketing assets. This module bridges the gap between "we have a token" and "people are talking about it." All output is templated, on-brand, and ready to post.

## Triggers

Activate Narrative Forge when:
- Phase 0 `MEMECOIN_BRIEF.md` is complete (narrative section populated)
- User says "generate marketing", "create content", "narrative forge"
- Execution mode includes `--with-content` flag

## Output Artifacts

```
/repo
  /marketing
    /threads
      /launch_thread.md          # 5-part X/Twitter alpha thread
      /milestone_thread.md       # Template for burn/holder milestones
      /fud_response_thread.md    # Pre-written FUD counter-narratives
    /announcements
      /telegram_launch.md        # Telegram launch announcement
      /telegram_milestone.md     # Milestone announcement template
      /discord_launch.md         # Discord embed format
    /visuals
      /meme_prompts.md           # 10 DALL-E/Midjourney prompts
      /brand_guide.md            # Colors, fonts, logo usage rules
      /banner_specs.md           # Social media banner dimensions
    /whitepaper
      /whitepaper_template.md    # Structured whitepaper content
      /whitepaper_style.md       # PDF styling instructions
    /media_kit
      /press_release.md          # Press release template
      /one_pager.md              # Single-page project summary
      /fact_sheet.md             # Key stats for journalists/KOLs
```

## Thread Generator

### Launch Thread Template (5-part)

The launch thread follows the **AIDA framework** (Attention, Interest, Desire, Action):

```
THREAD STRUCTURE:
┌─────────────────────────────────────────────────────────────┐
│ Part 1: THE HOOK (Attention)                                 │
│ - One-liner that stops the scroll                           │
│ - Use contrarian take, bold stat, or mystery                │
│ - End with "A thread 🧵"                                    │
├─────────────────────────────────────────────────────────────┤
│ Part 2: THE PROBLEM (Interest)                               │
│ - What's broken in the current meta                         │
│ - Name competitors without attacking                        │
│ - Show you understand the pain point                        │
├─────────────────────────────────────────────────────────────┤
│ Part 3: THE SOLUTION (Desire)                                │
│ - Introduce the token and its core mechanic                 │
│ - One key differentiator (burn, treasury, governance)       │
│ - "Built different because..." framing                      │
├─────────────────────────────────────────────────────────────┤
│ Part 4: THE PROOF (Trust)                                    │
│ - On-chain facts: fixed supply, LP locked, authorities      │
│   revoked                                                   │
│ - Link to Solscan/explorer                                  │
│ - Audits, open source, or verifiable claims                 │
├─────────────────────────────────────────────────────────────┤
│ Part 5: THE CTA (Action)                                     │
│ - How to buy (DEX link)                                     │
│ - Community links (Telegram, Discord, X)                    │
│ - "NFA/DYOR" disclaimer                                     │
│ - Engagement hook: "What are you waiting for?"              │
└─────────────────────────────────────────────────────────────┘
```

### Thread Variables (from MEMECOIN_BRIEF.md)

| Variable | Source | Example |
|----------|--------|---------|
| `{TOKEN_NAME}` | R4 recommended name | "RIBBIT" |
| `{TICKER}` | R4 recommended ticker | "$RBBT" |
| `{NARRATIVE}` | R5 narrative.one_liner | "The frog that eats inflation" |
| `{SUPPLY}` | Design Parameters | "1,000,000,000" |
| `{LP_PCT}` | Design Parameters | "70%" |
| `{BURN_MECHANIC}` | R5 retention.mechanics | "1% per trade" |
| `{CHAIN}` | R3 selected_chain | "Solana" |
| `{DEX_LINK}` | Post-deploy | "https://jup.ag/swap/USDC-{MINT}" |
| `{EXPLORER_LINK}` | Post-deploy | "https://solscan.io/token/{MINT}" |

### Example Launch Thread

```markdown
## Thread: {TOKEN_NAME} Launch

**1/5** 🧵
{NARRATIVE}

Most memecoins die because they have zero mechanics.
{TOKEN_NAME} is different. Here's why 👇

**2/5**
The problem with 99% of meme launches:
- Infinite supply = slow rug
- Team dumps on community
- Zero utility = zero retention

Sound familiar?

**3/5**
{TOKEN_NAME} ({TICKER}) fixes this:
- Fixed {SUPPLY} supply. Mint authority = REVOKED. Forever.
- {BURN_MECHANIC} — every trade reduces supply permanently
- Treasury governed by multisig — no single point of failure

Built on {CHAIN} for speed and near-zero fees.

**4/5**
Don't trust. Verify:
- Mint authority: NONE ✅ {EXPLORER_LINK}
- Freeze authority: NONE ✅
- LP: {LP_PCT} locked
- Contracts: Open source on GitHub

**5/5**
Ready to hop in?
- Swap: {DEX_LINK}
- Community: [Telegram] [Discord]
- Follow: @{TICKER}token

NFA. DYOR. This is a memecoin, not financial advice.
```

## Meme Prompt Generator

### Prompt Template Format

Each prompt is designed for DALL-E 3 or Midjourney v6+ and follows the token's visual identity from R4.

```
PROMPT STRUCTURE:
[Style] [Subject] [Action] [Environment] [Mood] [Technical]
```

### Generated Prompts (10 variations)

| # | Type | Prompt Template |
|---|------|-----------------|
| 1 | Hero | `{STYLE}, {MASCOT} standing triumphantly on a pile of {COMPETITOR_TOKENS}, {CHAIN} logo glowing in background, cinematic lighting, 4K` |
| 2 | Burn | `{STYLE}, {MASCOT} throwing tokens into a bonfire, dramatic flames, deflationary energy, dark background with cyan sparks` |
| 3 | Community | `{STYLE}, army of {MASCOT}s marching together, unity and strength, banner with {TICKER}, epic wide shot` |
| 4 | Moon | `{STYLE}, {MASCOT} riding a rocket past the moon, stars and nebula, {TOKEN_NAME} logo on rocket, space theme` |
| 5 | Treasury | `{STYLE}, {MASCOT} guarding a vault of gold, multisig keys floating around, secure and trustworthy, warm lighting` |
| 6 | Governance | `{STYLE}, {MASCOT} at a podium giving a speech, crowd of holders voting, democratic vibes, congressional hall` |
| 7 | Launch | `{STYLE}, {MASCOT} pressing a big red launch button, countdown timer at 00:00, explosive energy, neon glow` |
| 8 | Chart | `{STYLE}, {MASCOT} surfing a green candlestick chart wave, ocean of liquidity, bullish energy, dynamic pose` |
| 9 | Diamond Hands | `{STYLE}, {MASCOT} holding token with diamond hands, crystalline effects, unwavering determination, clean background` |
| 10 | Banner | `{STYLE}, wide banner format (1500x500), {MASCOT} centered, {TOKEN_NAME} text left, tagline right, gradient background {PRIMARY_COLOR} to {SECONDARY_COLOR}` |

### Visual Identity Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `{STYLE}` | R4 logo_concept | "pixel art", "3D render", "anime style" |
| `{MASCOT}` | R4 name + concept | "cartoon frog", "cyber dog", "space cat" |
| `{PRIMARY_COLOR}` | Brand guide | Dominant brand color |
| `{SECONDARY_COLOR}` | Brand guide | Accent color |

## Telegram Announcement Templates

### Launch Announcement

```markdown
## {TOKEN_NAME} Launch Announcement

🚀 **{TOKEN_NAME} ({TICKER}) IS LIVE!** 🚀

━━━━━━━━━━━━━━━━━━━━

**What is {TOKEN_NAME}?**
{NARRATIVE}

**Tokenomics:**
- Supply: {SUPPLY} (FIXED — mint revoked)
- LP: {LP_PCT} locked
- Burn: {BURN_MECHANIC}
- Treasury: Multisig governed

**How to buy:**
1. Open Jupiter: {DEX_LINK}
2. Connect wallet (Phantom/Solflare)
3. Swap USDC → {TICKER}

**Links:**
- Chart: [DEXScreener]
- Explorer: {EXPLORER_LINK}
- X/Twitter: @{TICKER}token
- Website: {WEBSITE}

━━━━━━━━━━━━━━━━━━━━

⚠️ NFA. DYOR. Memecoin = high risk.
```

## Whitepaper Structure

### Template Sections

```
WHITEPAPER STRUCTURE:
┌─────────────────────────────────────────────────────────────┐
│ 1. Executive Summary (from R5 narrative.expanded_pitch)      │
│ 2. Problem Statement (from R2 competitor weaknesses)         │
│ 3. Solution (from SKILL.md Modules 1-7 architecture)        │
│ 4. Tokenomics (from Module 1 + tokenomics_template.md)      │
│ 5. Technology (from Anchor contracts + security checklist)   │
│ 6. Roadmap (from R5 utility_roadmap)                        │
│ 7. Team (placeholder — user fills)                          │
│ 8. Risk Factors (from regulatory_notes.md disclosures)      │
│ 9. Legal Disclaimer (from regulatory_notes.md template)     │
└─────────────────────────────────────────────────────────────┘
```

### PDF Styling

| Element | Specification |
|---------|---------------|
| Page size | Letter (8.5 x 11) |
| Margins | 1 inch all sides |
| Header font | Space Grotesk Bold |
| Body font | Inter Regular |
| Code font | JetBrains Mono |
| Primary color | From brand_guide.md |
| Page numbers | Bottom center |
| Cover page | Full-bleed with logo + tagline |
| Charts | Embedded from tokenomics calculations |

## Brand Guide Template

### Generated Brand Guide

```
BRAND GUIDE: {TOKEN_NAME}
━━━━━━━━━━━━━━━━━━━━

LOGO USAGE:
- Minimum size: 32x32px
- Clear space: 1x logo width on all sides
- Do NOT stretch, rotate, or recolor

COLOR PALETTE:
- Primary: {PRIMARY_COLOR} — use for CTAs, headers
- Secondary: {SECONDARY_COLOR} — use for accents, links
- Background: #0A0A0F — dark mode default
- Text: #FFFFFF / rgba(255,255,255,0.6)

TYPOGRAPHY:
- Headlines: Space Grotesk Bold
- Body: Inter Regular
- Code/Data: JetBrains Mono

TONE OF VOICE:
- Confident but not arrogant
- Memetic but not cringe
- Technical when needed, simple by default
- NEVER promise returns or price targets

SOCIAL HANDLES:
- X/Twitter: @{TICKER}token
- Telegram: t.me/{TICKER}community
- Discord: discord.gg/{TICKER}

BANNER DIMENSIONS:
- X/Twitter header: 1500x500
- Telegram group: 1280x720
- Discord banner: 960x540
```

## Media Kit: One-Pager

```
┌─────────────────────────────────────────────────────────────┐
│                    {TOKEN_NAME} ({TICKER})                    │
│                    ━━━━━━━━━━━━━━━━━━━━                     │
│                                                              │
│  "{NARRATIVE}"                                               │
│                                                              │
│  CHAIN: {CHAIN}          │  SUPPLY: {SUPPLY}                │
│  DEX: Jupiter/Raydium    │  LP: {LP_PCT} locked             │
│  BURN: {BURN_MECHANIC}   │  TREASURY: Multisig DAO          │
│                                                              │
│  WHY {TOKEN_NAME}?                                           │
│  1. Fixed supply — mint authority permanently revoked        │
│  2. Deterministic burns — no manual "burn events"           │
│  3. Governed treasury — no single key controls funds        │
│  4. Open source — all contracts verifiable on-chain         │
│                                                              │
│  LINKS:                                                      │
│  Website: {WEBSITE}                                          │
│  X: @{TICKER}token    TG: t.me/{TICKER}community           │
│  Code: github.com/{REPO}                                    │
│                                                              │
│  ⚠️ This is a memecoin. High risk. DYOR. NFA.               │
└─────────────────────────────────────────────────────────────┘
```

## Downstream Integration

| Consumer | Fields Used |
|----------|-------------|
| Module 8 (Aura UI) | brand_guide colors, typography |
| Module 11 (Propulsion) | media_kit for KOL outreach |
| Execution Mode | All marketing/ artifacts generated in repo |
| Phase 3 (Post-Deploy) | Thread templates populated with live addresses |
