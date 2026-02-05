# Pre-Deploy Security Checklist

Complete ALL items before mainnet deployment. Each item is MANDATORY.

## Token Contract Security

### Mint Authority
- [ ] Mint authority set to `None` after initial mint
- [ ] Verified via: `spl-token display <MINT_ADDRESS>`
- [ ] Screenshot/log saved

### Freeze Authority
- [ ] Freeze authority set to `None` OR documented reason for retention
- [ ] Verified via: `spl-token display <MINT_ADDRESS>`

### Supply Verification
- [ ] Total supply matches documentation
- [ ] No additional mint functions exist
- [ ] `AlreadyMinted` error implemented in contract

## Treasury Security

### Multi-Sig Configuration
- [ ] Minimum 2 signers configured
- [ ] Threshold set to ≥2
- [ ] All signer addresses verified
- [ ] Signers are distinct entities (not same person)

### Spend Controls
- [ ] Daily spend cap configured
- [ ] Proposal expiry enabled (24h recommended)
- [ ] All treasury actions logged on-chain

## Burn Mechanics

### Deterministic Rules
- [ ] No manual burn buttons
- [ ] All burn triggers documented
- [ ] Burn rate within limits (≤5% per trade)
- [ ] Volume milestone thresholds set

## Emergency Controls

### Pause Mechanism
- [ ] Maximum pause duration set (≤6 hours)
- [ ] Cooldown between pauses (≥24 hours)
- [ ] Guardian addresses verified
- [ ] Pause threshold configured

### Limitations Verified
- [ ] Emergency controls CANNOT mint tokens
- [ ] Emergency controls CANNOT transfer treasury
- [ ] All emergency actions logged

## Liquidity Protection

### LP Token Handling
- [ ] LP lock duration: _______ months
- [ ] OR LP tokens burned permanently
- [ ] Lock/burn transaction ID: _____________

### Anti-Rug Verification
- [ ] No LP withdraw authority
- [ ] Pool parameters verified
- [ ] Initial liquidity amount: _____________

## Code Verification

### Audit Status
- [ ] Internal review completed
- [ ] External audit completed (optional but recommended)
- [ ] All findings addressed

### Build Verification
- [ ] Build hash matches deployment
- [ ] IDL published and verified
- [ ] Source code published (optional)

## Program IDs

Record all program IDs before deployment:

| Program | Devnet ID | Mainnet ID |
|---------|-----------|------------|
| Token Mint | | |
| Burn Controller | | |
| Treasury Vault | | |
| Emergency Pause | | |

## Final Sign-Off

### Deployer Confirmation

I confirm that:
- [ ] All checklist items completed
- [ ] I understand this deployment is IRREVERSIBLE
- [ ] Team has reviewed and approved
- [ ] Emergency contacts documented

**Deployer:** _________________________

**Date:** _________________________

**Signature/Commit Hash:** _________________________

---

## Post-Checklist Commands

```bash
# Verify mint authority is None
spl-token display <MINT_ADDRESS> | grep "Mint authority"

# Verify freeze authority is None
spl-token display <MINT_ADDRESS> | grep "Freeze authority"

# Verify total supply
spl-token supply <MINT_ADDRESS>

# Verify program deployment
solana program show <PROGRAM_ID>
```

## Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| Lead Dev | | |
| Treasury Signer 1 | | |
| Treasury Signer 2 | | |
| Emergency Guardian | | |
