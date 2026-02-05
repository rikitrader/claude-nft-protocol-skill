# Jupiter Integration Guide

Jupiter is the primary aggregator for Solana token swaps. Integration is largely automatic once you have a Raydium pool.

## Automatic Integration

Jupiter automatically indexes:
- All Raydium pools
- All Orca pools
- Most SPL token pairs with liquidity

**Timeline:** 5-30 minutes after pool creation

## Verification

### Check Token Availability

```bash
# Via API
curl "https://quote-api.jup.ag/v6/quote?inputMint=So11111111111111111111111111111111111111112&outputMint=YOUR_TOKEN_MINT&amount=1000000000"
```

### Expected Response (if indexed)

```json
{
  "inputMint": "So11111111111111111111111111111111111111112",
  "outputMint": "YOUR_TOKEN_MINT",
  "outAmount": "...",
  "routePlan": [...]
}
```

## Manual Token Registration (If Needed)

If your token isn't appearing after 30 minutes:

1. **Check Pool Liquidity**
   - Minimum ~$1000 USD in liquidity recommended
   - Jupiter may skip very low liquidity pools

2. **Verify Token Metadata**
   ```bash
   # Using Metaboss
   metaboss decode mint -a YOUR_TOKEN_MINT
   ```

3. **Submit to Jupiter Token Verification**
   - Portal: https://verify.jup.ag/
   - Submit token for community verification (GitHub token-list repo is archived)

## Jupiter API Integration

### Get Quote

```typescript
const response = await fetch(
  `https://quote-api.jup.ag/v6/quote?` +
  `inputMint=${SOL_MINT}&` +
  `outputMint=${YOUR_TOKEN}&` +
  `amount=${amountInLamports}&` +
  `slippageBps=50`
);

const quote = await response.json();
```

### Execute Swap

```typescript
const swapResponse = await fetch('https://quote-api.jup.ag/v6/swap', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    quoteResponse: quote,
    userPublicKey: wallet.publicKey.toString(),
    wrapUnwrapSOL: true,
  }),
});

const { swapTransaction } = await swapResponse.json();

// Deserialize and sign
const transaction = VersionedTransaction.deserialize(
  Buffer.from(swapTransaction, 'base64')
);
transaction.sign([wallet]);

// Send
const txid = await connection.sendTransaction(transaction);
```

## Price Feed Integration

### Get Token Price

```typescript
// Via Jupiter Price API v2
const priceResponse = await fetch(
  `https://api.jup.ag/price/v2?ids=${YOUR_TOKEN_MINT}`
);

const { data } = await priceResponse.json();
const price = data[YOUR_TOKEN_MINT]?.price; // string, e.g. "0.00123"
```

## Dashboard Integration

For your memecoin dashboard, integrate these Jupiter endpoints:

| Endpoint | Purpose |
|----------|---------|
| `/v6/quote` | Get swap quotes |
| `/v6/swap` | Execute swaps |
| `/price/v2` | Get current prices |
| `/tokens/v1` | Get token metadata |

## Best Practices

1. **Set Reasonable Slippage**
   - 0.5% for stable pairs
   - 1-3% for volatile memecoins
   - Auto-adjust based on liquidity depth

2. **Handle Route Failures**
   ```typescript
   if (!quote.routePlan || quote.routePlan.length === 0) {
     // Insufficient liquidity or token not indexed
     throw new Error('No route available');
   }
   ```

3. **Monitor Volume**
   - Jupiter provides volume data in responses
   - Track 24h volume for dashboard

## Anti-Bot Considerations

Jupiter supports:
- Priority fees (for faster execution)
- Dynamic slippage
- MEV protection (Jito integration)

For fair launches, consider adding delay between pool creation and Jupiter indexing announcement.
