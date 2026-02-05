# Post-Deploy Verification Checklist

Complete within 1 hour of mainnet deployment.

## Immediate Verification (0-15 minutes)

### Program Deployment
- [ ] All programs deployed successfully
- [ ] Program IDs recorded
- [ ] Programs visible on Solscan/Solana Explorer

### Token Verification
- [ ] Token mint created
- [ ] Metadata uploaded correctly
- [ ] Total supply correct
- [ ] Mint authority = None (CRITICAL)
- [ ] Freeze authority = None

### On-Chain State
- [ ] Treasury initialized
- [ ] Multi-sig configured
- [ ] Burn controller active
- [ ] Emergency system initialized

## Liquidity Setup (15-30 minutes)

### Pool Creation
- [ ] Raydium pool created
- [ ] Pool ID recorded: _____________
- [ ] Initial liquidity deposited
- [ ] Trading tested (small amount)

### LP Protection
- [ ] LP tokens locked/burned
- [ ] Lock transaction ID: _____________
- [ ] Verified on-chain

### Jupiter Integration
- [ ] Token indexed on Jupiter
- [ ] Swap tested via Jupiter
- [ ] Price feed active

## Monitoring Setup (30-60 minutes)

### Dashboard
- [ ] Metrics dashboard live
- [ ] Price tracking active
- [ ] Volume monitoring active
- [ ] Holder count tracking

### Alerts Configured
- [ ] Liquidity drain alert
- [ ] Whale accumulation alert
- [ ] Emergency pause alert
- [ ] Treasury spend alert

## Public Verification

### Explorer Links
Record all verification links:

| Item | Link |
|------|------|
| Token Mint | |
| Token Mint Program | |
| Burn Controller | |
| Treasury | |
| Raydium Pool | |
| LP Lock TX | |

### Metadata Verification
- [ ] Name correct
- [ ] Symbol correct
- [ ] Logo displays correctly
- [ ] Description accurate
- [ ] Website link works
- [ ] Twitter link works
- [ ] Telegram link works

## Community Disclosure

### Required Announcements
- [ ] Token contract address posted
- [ ] LP lock/burn proof posted
- [ ] Team token vesting disclosed
- [ ] Treasury multi-sig addresses disclosed
- [ ] Tokenomics breakdown posted

### Documentation Published
- [ ] Whitepaper/Docs live
- [ ] Contract addresses listed
- [ ] How-to-buy guide

## Security Monitoring

### First 24 Hours
- [ ] Monitor all large transactions
- [ ] Track holder distribution
- [ ] Watch for unusual patterns
- [ ] Check DEX activity

### Ongoing Monitoring
- [ ] Daily treasury review
- [ ] Weekly burn metrics
- [ ] Monthly governance report

## Sign-Off

### Verification Complete

I confirm all post-deployment checks passed:

**Verifier:** _________________________

**Date/Time:** _________________________

**Block Height at Verification:** _________________________

---

## Emergency Procedures

If issues detected post-launch:

1. **Assessment** (0-5 min)
   - Identify issue severity
   - Document current state

2. **Communication** (5-10 min)
   - Alert team immediately
   - DO NOT post publicly until assessed

3. **Response** (10-30 min)
   - If critical: Initiate emergency pause
   - If moderate: Plan response
   - If low: Document and monitor

4. **Resolution** (30+ min)
   - Implement fix or mitigation
   - Test thoroughly
   - Resume operations

5. **Post-Mortem** (24-48 hours)
   - Full incident report
   - Lessons learned
   - Process improvements

## Contact Sheet

| Situation | Contact | Method |
|-----------|---------|--------|
| Smart Contract Issue | Lead Dev | |
| Treasury Emergency | Multi-sig Signers | |
| Community Crisis | Community Lead | |
| Exchange Issue | Exchange Liaison | |
