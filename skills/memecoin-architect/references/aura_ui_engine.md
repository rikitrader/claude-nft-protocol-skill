# Module 8: "Aura" Luxury UI Engine

## Purpose

Generate a production-ready Next.js dashboard that visualizes on-chain token metrics in real-time. The UI must instill trust, look premium, and integrate seamlessly with the Anchor programs produced by the execution engine.

## Design System

### Visual Language

```
┌─────────────────────────────────────────────────────────────┐
│                    AURA DESIGN TOKENS                        │
├──────────────────┬──────────────────────────────────────────┤
│ Style            │ Glassmorphic Dark (blur + transparency)  │
│ Primary          │ #00F0FF (Cyan Glow)                      │
│ Secondary        │ #9B59FF (Phantom Purple)                 │
│ Accent           │ #FF6B35 (Burn Orange)                    │
│ Background       │ #0A0A0F → #12121A gradient              │
│ Surface          │ rgba(255,255,255,0.05) + backdrop-blur   │
│ Text Primary     │ #FFFFFF                                  │
│ Text Secondary   │ rgba(255,255,255,0.6)                    │
│ Border           │ rgba(255,255,255,0.08)                   │
│ Font Headings    │ Space Grotesk                            │
│ Font Body        │ Inter                                    │
│ Border Radius    │ 16px (cards), 12px (buttons)             │
│ Grid             │ Bento-style (CSS Grid, auto-fit)         │
└──────────────────┴──────────────────────────────────────────┘
```

### Component Library

| Component | Description | Data Source |
|-----------|-------------|-------------|
| `BurnMeter` | Animated ring showing total burned vs supply | burn_controller events |
| `TreasuryCard` | Balance + inflows/outflows sparkline | treasury_vault account |
| `PriceChart` | Candlestick + volume (Jupiter price API) | Jupiter Price API v2 |
| `HolderMap` | Top 20 holders distribution donut | RPC getProgramAccounts |
| `LPStatus` | Lock timer countdown + depth bar | Raydium pool account |
| `GovernancePanel` | Active proposals + voting status | governance_multisig events |
| `PauseIndicator` | Emergency status beacon (green/red) | emergency_pause state |
| `SupplyTicker` | Live circulating vs total supply | mint account + burn logs |

## Tech Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND STACK                             │
├──────────────────┬──────────────────────────────────────────┤
│ Framework        │ Next.js 15 (App Router)                  │
│ Language         │ TypeScript                                │
│ Styling          │ Tailwind CSS 4 + CSS Variables           │
│ Charts           │ Recharts (lightweight, composable)       │
│ Animations       │ Framer Motion                            │
│ Wallet           │ @solana/wallet-adapter-react             │
│ RPC              │ @solana/web3.js + Anchor client          │
│ State            │ TanStack Query (server state)            │
│ Deployment       │ Vercel / Cloudflare Pages                │
└──────────────────┴──────────────────────────────────────────┘
```

## Repo Tree (Frontend Addition)

```
/repo
  /frontend
    /package.json
    /tsconfig.json
    /next.config.ts
    /tailwind.config.ts
    /postcss.config.js
    /.env.example

    /public
      /favicon.ico
      /og-image.png

    /src
      /app
        /layout.tsx              # Root layout + wallet providers
        /page.tsx                # Dashboard home (Bento grid)
        /globals.css             # Design tokens + glassmorphic utils

      /components
        /dashboard
          /BurnMeter.tsx         # Animated burn ring
          /TreasuryCard.tsx      # Balance + sparkline
          /PriceChart.tsx        # Candlestick via Recharts
          /HolderMap.tsx         # Top holders donut
          /LPStatus.tsx          # LP lock countdown
          /GovernancePanel.tsx   # Proposals + votes
          /PauseIndicator.tsx    # Emergency beacon
          /SupplyTicker.tsx      # Live supply counter

        /wallet
          /WalletProvider.tsx    # Solana wallet adapter wrapper
          /ConnectButton.tsx     # Styled connect button

        /ui
          /GlassCard.tsx         # Reusable glassmorphic card
          /AnimatedNumber.tsx    # Counting animation
          /Sparkline.tsx         # Mini inline chart

      /hooks
        /useTokenMetrics.ts      # Fetch burn/supply/treasury data
        /usePriceData.ts         # Jupiter price feed
        /useGovernance.ts        # Proposal state
        /usePauseStatus.ts       # Emergency pause state

      /lib
        /anchor-client.ts        # IDL + program connection
        /constants.ts            # Program IDs, RPC endpoints
        /formatters.ts           # Number/date formatting utils
```

## Key Components

### BurnMeter

Real-time animated ring showing burn progress.

```
┌────────────────────────────┐
│    ╭──────────────╮        │
│    │   ◉ 12.4%    │        │
│    │   BURNED     │        │
│    ╰──────────────╯        │
│                            │
│  124,000,000 / 1,000,000,000│
│  ▓▓▓▓▓░░░░░░░░░░░░░░░░░░  │
│                            │
│  Last burn: 2m ago         │
│  24h burned: 1,204,500     │
└────────────────────────────┘
```

**Data flow:**
1. Subscribe to burn_controller program logs via WebSocket
2. Parse `BurnEvent` from event data
3. Accumulate total burned from on-chain state
4. Animate ring fill with Framer Motion `useSpring`

### TreasuryCard

```
┌────────────────────────────┐
│  TREASURY VAULT            │
│                            │
│  ◈ 847,234 USDC            │
│  ▲ +12,450 (24h)           │
│                            │
│  ┄┄┄╱╲┄┄╱╲╱╲┄┄┄╱╲┄┄      │
│  (7-day sparkline)         │
│                            │
│  Next buyback: ~$50,000    │
│  Governance: 3 active      │
└────────────────────────────┘
```

**Data flow:**
1. Read treasury PDA token account balance
2. Query historical balances from indexed events
3. Render sparkline from 7-day data points

### PriceChart

```
┌────────────────────────────────────────┐
│  TOKEN/USDC                  $0.00042  │
│                              ▲ +8.2%   │
│                                        │
│  ┃     ┃  ╻                            │
│  ┃ ╻   ┃  ┃     ╻                      │
│  ┃ ┃ ╻ ┃  ┃  ╻  ┃  ╻                  │
│  ┃ ┃ ┃ ┃  ┃  ┃  ┃  ┃  ╻              │
│  ┗━┻━┻━┻━━┻━━┻━━┻━━┻━━┛              │
│  1h  4h  1d  1w                        │
│                                        │
│  Vol 24h: $1.2M  │  Liq: $450K        │
└────────────────────────────────────────┘
```

**Data flow:**
1. Jupiter Price API v2: `GET /v2/price?ids={mint}`
2. Birdeye or DexScreener API for OHLCV candles
3. Recharts `ComposedChart` with `Bar` (volume) + `Candlestick`

## Wallet Integration

### Supported Wallets

| Wallet | Adapter | Priority |
|--------|---------|----------|
| Phantom | `@solana/wallet-adapter-phantom` | Primary |
| Solflare | `@solana/wallet-adapter-solflare` | Secondary |
| Backpack | `@solana/wallet-adapter-backpack` | Secondary |
| WalletConnect | `@walletconnect/solana-adapter` | Mobile |
| Solana Mobile | `@solana-mobile/wallet-adapter-mobile` | Mobile |

### WalletProvider Pattern

```typescript
// src/components/wallet/WalletProvider.tsx
// Wraps app with ConnectionProvider + WalletProvider
// Configures: network (devnet/mainnet), autoConnect, wallets[]
// Provides: useConnection(), useWallet(), useAnchorWallet()
```

## Data Fetching Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                │
├──────────────────┬──────────────────────────────────────────┤
│ Real-time        │ WebSocket subscription to program logs   │
│                  │ (burn events, pause events, governance)  │
├──────────────────┼──────────────────────────────────────────┤
│ Polling          │ TanStack Query with 10s refetch interval │
│                  │ (treasury balance, supply, LP status)    │
├──────────────────┼──────────────────────────────────────────┤
│ On-demand        │ Price data fetched on interval change    │
│                  │ (1h, 4h, 1d, 1w chart timeframes)       │
├──────────────────┼──────────────────────────────────────────┤
│ Static           │ Token metadata, program IDs, constants   │
│                  │ (loaded once at app init)                │
└──────────────────┴──────────────────────────────────────────┘
```

## Responsive Bento Grid

```
DESKTOP (1280px+):
┌────────┬────────┬────────┐
│ Burn   │ Price  │ Price  │
│ Meter  │ Chart  │ Chart  │
├────────┼────────┼────────┤
│Treasury│ Holders│   LP   │
│  Card  │  Map   │ Status │
├────────┼────────┴────────┤
│ Supply │   Governance    │
│ Ticker │     Panel       │
└────────┴─────────────────┘

MOBILE (< 768px):
┌─────────────────┐
│   Burn Meter    │
├─────────────────┤
│   Price Chart   │
├─────────────────┤
│  Treasury Card  │
├─────────────────┤
│    LP Status    │
├─────────────────┤
│  Supply Ticker  │
├─────────────────┤
│   Governance    │
└─────────────────┘
```

## Environment Variables

```
# .env.example
NEXT_PUBLIC_RPC_ENDPOINT=https://api.mainnet-beta.solana.com
NEXT_PUBLIC_TOKEN_MINT=<MINT_ADDRESS>
NEXT_PUBLIC_PROGRAM_ID=<PROGRAM_ID>
NEXT_PUBLIC_TREASURY_PDA=<TREASURY_PDA>
NEXT_PUBLIC_NETWORK=mainnet-beta
```

## Integration with Execution Mode

When "execution mode" generates the full repo, the `/frontend` directory is included with:
1. All component files with placeholder program IDs
2. `anchor-client.ts` auto-configured from generated IDL
3. `.env.example` pre-filled with program addresses from deployment
4. `package.json` with all dependencies pinned

The dashboard is functional immediately after `npm install && npm run dev` with a running Solana validator or devnet connection.

## Deployment Targets

| Platform | Command | Notes |
|----------|---------|-------|
| Vercel | `vercel deploy` | Recommended, zero-config for Next.js |
| Cloudflare Pages | `npx wrangler pages deploy .next` | Edge-first, global CDN |
| Self-hosted | `npm run build && npm start` | Port 3000 default |

## Security Considerations

- No private keys in frontend code
- All wallet signing via adapter (client-side only)
- RPC endpoint should use rate-limited proxy in production
- CSP headers configured in `next.config.ts`
- No server-side wallet operations
