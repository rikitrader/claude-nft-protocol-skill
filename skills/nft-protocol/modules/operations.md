# Operations, Incident Response & Monitoring

Production operations runbook: incident response playbook, monitoring setup, upgrade governance flow, and disaster recovery procedures.

---

## INCIDENT RESPONSE PLAYBOOK

### Severity Classification

```
SEVERITY LEVELS
│
├─ P0 (Critical) — Active exploit, funds at risk
│  Response: Immediately pause contracts, mobilize war room
│  SLA: 15 minutes to first response
│
├─ P1 (High) — Vulnerability discovered, no active exploit
│  Response: Assess impact, prepare patch, schedule emergency upgrade
│  SLA: 1 hour to assessment
│
├─ P2 (Medium) — Non-critical bug, degraded functionality
│  Response: Document, schedule fix in next release
│  SLA: 24 hours to plan
│
└─ P3 (Low) — Cosmetic issue, minor improvement
   Response: Add to backlog
   SLA: Next sprint
```

### P0 Response: Active Exploit

```
ACTIVE EXPLOIT RESPONSE FLOW

1. DETECT (0-5 min)
   ├─ Forta alert fires
   ├─ On-chain anomaly detected
   ├─ Community report received
   └─ Monitoring dashboard alarm

2. ASSESS (5-15 min)
   ├─ Identify affected contracts
   ├─ Estimate funds at risk
   ├─ Determine attack vector
   └─ Check if attack is ongoing

3. CONTAIN (15-30 min)
   ├─ Execute emergency pause (multisig)
   │   pause() via Gnosis Safe
   ├─ Revoke compromised roles
   ├─ Blacklist attacker addresses
   └─ Disable affected functions

4. COMMUNICATE (30-60 min)
   ├─ Internal team alert
   ├─ Post-mortem channel opened
   ├─ Public disclosure (if needed)
   └─ Contact exchanges if stolen funds moving

5. REMEDIATE (1-24 hours)
   ├─ Develop and test fix
   ├─ Security review of patch
   ├─ Deploy to testnet
   ├─ Upgrade mainnet via timelock
   └─ Unpause affected contracts

6. RECOVER (24-72 hours)
   ├─ Full post-mortem document
   ├─ User compensation plan (if needed)
   ├─ Process improvements
   └─ Third-party audit of fix
```

### Emergency Pause Procedure

```solidity
// Emergency pause requires PAUSER_ROLE or multisig
// Stored in Gnosis Safe transaction queue

// Step 1: Any PAUSER_ROLE holder can pause
function pause() external onlyRole(PAUSER_ROLE);

// Step 2: Only admin multisig can unpause (2/3 required)
function unpause() external onlyRole(DEFAULT_ADMIN_ROLE);
```

**Gnosis Safe Configuration for Emergency:**
```
Emergency Multisig Setup:
├─ Threshold: 1 of 3 (for pause only)
├─ Signers:
│   ├─ CTO / Lead Developer
│   ├─ Security Lead
│   └─ Operations Lead
├─ Pause: Any single signer
├─ Unpause: 2 of 3 required
└─ Upgrade: 3 of 3 required + Timelock
```

### Emergency Contact Checklist

```
CONTACTS (Update before mainnet)
│
├─ Internal
│   ├─ Security Lead: [name] [phone] [telegram]
│   ├─ Lead Developer: [name] [phone] [telegram]
│   ├─ Operations: [name] [phone] [telegram]
│   └─ Legal: [name] [phone] [email]
│
├─ External
│   ├─ Audit Firm: [firm] [contact] [retainer status]
│   ├─ Chainlink Support: [escalation path]
│   ├─ Block Explorer: [contact for labeling]
│   └─ Insurance Provider: [policy number] [contact]
│
└─ Channels
    ├─ War Room: [private Discord/Slack channel]
    ├─ Public Status: [status page URL]
    └─ Bug Bounty: [Immunefi URL]
```

---

## MONITORING SETUP

### On-Chain Monitoring (Forta)

```javascript
// forta-agent/src/agent.js
const { Finding, FindingSeverity, FindingType } = require("forta-agent");

const CONTRACTS = {
    NFT: "0x...",
    MARKETPLACE: "0x...",
    VAULT: "0x...",
};

// Alert: Large value transfer
function handleTransaction(txEvent) {
    const findings = [];

    // Detect large ETH transfers to/from contracts
    if (txEvent.to && Object.values(CONTRACTS).includes(txEvent.to.toLowerCase())) {
        const value = BigInt(txEvent.transaction.value);
        if (value > BigInt("10000000000000000000")) { // > 10 ETH
            findings.push(Finding.fromObject({
                name: "Large Value Transaction",
                description: `Large transfer of ${value} wei to ${txEvent.to}`,
                alertId: "NFT-LARGE-TX",
                severity: FindingSeverity.Medium,
                type: FindingType.Suspicious,
            }));
        }
    }

    return findings;
}

// Alert: Unusual minting activity
function handleBlock(blockEvent) {
    const findings = [];
    // Check mint count per block
    // Alert if > 50 mints in single block (possible bot attack)
    return findings;
}

module.exports = { handleTransaction, handleBlock };
```

### Forta Alert Configuration

```yaml
# forta.config.yml
alertConfig:
  - name: "Pause Event"
    description: "Contract was paused"
    severity: "CRITICAL"
    conditions:
      - event: "Paused(address)"
        contract: "${NFT_CONTRACT}"

  - name: "Role Granted"
    description: "New role granted"
    severity: "HIGH"
    conditions:
      - event: "RoleGranted(bytes32,address,address)"
        contract: "${NFT_CONTRACT}"

  - name: "Large Sale"
    description: "NFT sold for > 100 ETH"
    severity: "MEDIUM"
    conditions:
      - event: "NFTSold(uint256,address,uint256)"
        contract: "${MARKETPLACE_CONTRACT}"
        filter: "price > 100000000000000000000"

  - name: "Upgrade Initiated"
    description: "Contract upgrade initiated"
    severity: "CRITICAL"
    conditions:
      - event: "Upgraded(address)"
        contract: "${NFT_CONTRACT}"
```

### OpenZeppelin Defender Setup

```javascript
// defender/autotasks/monitor.js
const { DefenderRelaySigner } = require("defender-relay-client/lib/ethers");

exports.handler = async function(credentials) {
    const provider = new DefenderRelayProvider(credentials);
    const signer = new DefenderRelaySigner(credentials, provider);

    // Monitor contract health
    const nft = new ethers.Contract(NFT_ADDRESS, ABI, provider);

    // Check if paused
    const isPaused = await nft.paused();
    if (isPaused) {
        console.log("WARNING: Contract is paused");
        // Send alert via Defender notification
    }

    // Check oracle freshness
    const lastUpdate = await oracle.latestTimestamp();
    const staleness = Date.now() / 1000 - lastUpdate;
    if (staleness > 3600) {
        console.log("WARNING: Oracle data stale by", staleness, "seconds");
    }

    // Check contract balance anomalies
    const balance = await provider.getBalance(MARKETPLACE_ADDRESS);
    // Alert if balance drops > 50% in 24h
};
```

### Grafana Dashboard Template

```json
{
    "dashboard": {
        "title": "NFT Protocol Monitoring",
        "panels": [
            {
                "title": "Minting Activity",
                "type": "timeseries",
                "targets": [{
                    "expr": "nft_mint_count_total",
                    "legendFormat": "Mints"
                }]
            },
            {
                "title": "Marketplace Volume (ETH)",
                "type": "timeseries",
                "targets": [{
                    "expr": "marketplace_volume_eth_total",
                    "legendFormat": "Volume"
                }]
            },
            {
                "title": "Active Listings",
                "type": "stat",
                "targets": [{
                    "expr": "marketplace_active_listings"
                }]
            },
            {
                "title": "Oracle Staleness",
                "type": "gauge",
                "targets": [{
                    "expr": "oracle_staleness_seconds",
                    "thresholds": [300, 1800, 3600]
                }]
            },
            {
                "title": "Gas Usage per Operation",
                "type": "bargauge",
                "targets": [{
                    "expr": "gas_used_by_function"
                }]
            },
            {
                "title": "Error Rate",
                "type": "timeseries",
                "targets": [{
                    "expr": "rate(transaction_reverts_total[5m])",
                    "legendFormat": "Reverts/min"
                }]
            }
        ]
    }
}
```

### Prometheus Metrics Exporter

```javascript
// metrics/exporter.js
const { Registry, Counter, Gauge, Histogram } = require("prom-client");
const { ethers } = require("ethers");

const registry = new Registry();

// Counters
const mintCounter = new Counter({
    name: "nft_mint_count_total",
    help: "Total NFTs minted",
    registers: [registry],
});

const saleCounter = new Counter({
    name: "marketplace_sales_total",
    help: "Total marketplace sales",
    registers: [registry],
});

const volumeCounter = new Counter({
    name: "marketplace_volume_eth_total",
    help: "Total marketplace volume in ETH",
    registers: [registry],
});

// Gauges
const activeListings = new Gauge({
    name: "marketplace_active_listings",
    help: "Number of active marketplace listings",
    registers: [registry],
});

const oracleStaleness = new Gauge({
    name: "oracle_staleness_seconds",
    help: "Seconds since last oracle update",
    registers: [registry],
});

const contractBalance = new Gauge({
    name: "contract_balance_eth",
    help: "Contract ETH balance",
    labelNames: ["contract"],
    registers: [registry],
});

// Histograms
const gasUsed = new Histogram({
    name: "gas_used_by_function",
    help: "Gas used by contract function",
    labelNames: ["function"],
    buckets: [50000, 100000, 200000, 500000, 1000000],
    registers: [registry],
});

// Listen to events and update metrics
async function startMetricsCollection(provider, contracts) {
    const nft = new ethers.Contract(contracts.nft, NFT_ABI, provider);
    const marketplace = new ethers.Contract(contracts.marketplace, MARKETPLACE_ABI, provider);

    nft.on("TokenMinted", () => mintCounter.inc());
    marketplace.on("NFTSold", (_, __, ___, price) => {
        saleCounter.inc();
        volumeCounter.inc(parseFloat(ethers.formatEther(price)));
    });

    // Periodic gauge updates
    setInterval(async () => {
        const listings = await marketplace.activeListingCount();
        activeListings.set(Number(listings));

        const balance = await provider.getBalance(contracts.marketplace);
        contractBalance.set({ contract: "marketplace" }, parseFloat(ethers.formatEther(balance)));
    }, 60000); // Every minute
}

module.exports = { registry, startMetricsCollection };
```

---

## UPGRADE GOVERNANCE FLOW

### End-to-End Upgrade Process

```
UPGRADE GOVERNANCE FLOW

1. PROPOSAL (Day 0)
   ├─ Developer submits upgrade proposal to DAO
   ├─ Include: new implementation address, changelog, audit report
   ├─ Proposal enters voting period
   └─ Community notified via governance forum

2. VOTING (Days 1-7)
   ├─ Token holders vote (Governor contract)
   ├─ Quorum: 4% of total supply
   ├─ Majority: >50% approval
   └─ Voting period: 7 days

3. TIMELOCK (Days 7-9)
   ├─ If approved, enters Timelock queue
   ├─ Timelock delay: 48 hours
   ├─ During this window:
   │   ├─ Community can review final code
   │   ├─ Security team does final check
   │   └─ Guardian can cancel if issue found
   └─ If no cancellation, ready to execute

4. EXECUTION (Day 9)
   ├─ Multisig executes upgrade transaction
   ├─ New implementation deployed
   ├─ Proxy upgraded via UUPS pattern
   └─ Verification:
       ├─ Check new implementation address
       ├─ Run integration tests against upgraded proxy
       ├─ Verify state preservation
       └─ Monitor for 24 hours

5. POST-UPGRADE (Days 9-10)
   ├─ Update subgraph if events changed
   ├─ Update frontend ABIs
   ├─ Update SDK
   ├─ Publish changelog
   └─ Monitor metrics for anomalies
```

### Guardian / Cancel Flow

```solidity
// Guardian can cancel pending upgrades during timelock
// This is a safety mechanism for last-minute vulnerability discoveries

// Timelock controller setup
TimelockController timelock = new TimelockController(
    48 hours,           // minDelay
    proposers,          // array of proposer addresses
    executors,          // array of executor addresses
    guardian            // admin who can cancel
);

// Guardian cancels a pending upgrade
function cancelUpgrade(bytes32 operationId) external {
    require(msg.sender == guardian, "Not guardian");
    timelock.cancel(operationId);
    emit UpgradeCancelled(operationId, msg.sender, block.timestamp);
}
```

---

## DISASTER RECOVERY

### Recovery Scenarios

```
SCENARIO 1: Key Compromise
├─ Detect: Unauthorized transactions from admin key
├─ Respond:
│   ├─ Pause all contracts immediately
│   ├─ Rotate compromised key in multisig
│   ├─ Review all transactions from compromised key
│   ├─ Revoke any roles granted by compromised key
│   └─ Unpause after security review
└─ Prevent: Use hardware wallets, never expose private keys

SCENARIO 2: Oracle Failure
├─ Detect: Oracle staleness > 1 hour
├─ Respond:
│   ├─ Pause oracle-dependent functions (RWA valuation, lending)
│   ├─ Switch to backup oracle if available
│   ├─ Contact Chainlink support
│   └─ Resume when oracle is fresh
└─ Prevent: Multi-oracle setup, staleness checks in contracts

SCENARIO 3: Bridge Exploit
├─ Detect: Unusual bridging activity, balance mismatch
├─ Respond:
│   ├─ Pause bridge contracts on all chains
│   ├─ Snapshot token balances on each chain
│   ├─ Identify unauthorized mints/burns
│   ├─ Deploy fix
│   └─ Reconcile cross-chain state
└─ Prevent: Rate limiting, max bridge amounts, monitoring

SCENARIO 4: Smart Contract Bug
├─ Detect: Unexpected behavior, failed transactions, incorrect state
├─ Respond:
│   ├─ Pause affected contract
│   ├─ Assess scope of damage
│   ├─ Develop and audit fix
│   ├─ Upgrade via governance (or emergency if P0)
│   └─ Verify state after upgrade
└─ Prevent: Comprehensive testing, formal verification, audits

SCENARIO 5: Frontend Compromise
├─ Detect: Phishing reports, unexpected contract interactions
├─ Respond:
│   ├─ Take down compromised frontend
│   ├─ Alert users via all channels
│   ├─ Deploy clean frontend from verified source
│   ├─ Rotate any compromised API keys
│   └─ Check for approval draining transactions
└─ Prevent: Subresource integrity, CSP headers, CI/CD security
```

### State Backup Strategy

```
BACKUP SCHEDULE
│
├─ Continuous
│   ├─ The Graph indexes all events
│   ├─ Event logs stored in archival nodes
│   └─ IPFS metadata pinned to multiple providers
│
├─ Hourly
│   ├─ Snapshot contract state (balances, ownership)
│   ├─ Export marketplace listings
│   └─ Backup oracle price history
│
├─ Daily
│   ├─ Full database backup (off-chain data)
│   ├─ API server state export
│   └─ Configuration backup
│
└─ Weekly
    ├─ Cross-chain state reconciliation
    ├─ Audit log review
    └─ Access control review
```

---

## BUG BOUNTY PROGRAM

### Immunefi Configuration

```
BUG BOUNTY TIERS
│
├─ Critical ($50,000 - $500,000)
│   ├─ Direct theft of user funds
│   ├─ Permanent freezing of funds
│   ├─ Unauthorized minting
│   └─ Governance manipulation
│
├─ High ($10,000 - $50,000)
│   ├─ Theft of unclaimed yield/rewards
│   ├─ Temporary freezing of funds
│   ├─ Bypass of compliance controls
│   └─ Oracle manipulation
│
├─ Medium ($2,000 - $10,000)
│   ├─ Griefing attacks (no fund loss)
│   ├─ Incorrect state transitions
│   ├─ Gas optimization issues >50%
│   └─ Front-running vulnerabilities
│
└─ Low ($500 - $2,000)
    ├─ Informational findings
    ├─ Best practice violations
    ├─ Minor access control issues
    └─ View function errors
```

### In-Scope Contracts

```
IN SCOPE:
├─ InstitutionalNFT.sol (proxy + implementation)
├─ NFTMarketplace.sol
├─ FractionalizationVault.sol
├─ NFTLending.sol
├─ GovernorDAO.sol
├─ ComplianceRegistry.sol
├─ RoyaltyRouter.sol
├─ CCIPBridge.sol
└─ All deployed proxy contracts

OUT OF SCOPE:
├─ Test contracts
├─ Frontend / Backend
├─ Third-party contracts (OpenZeppelin, Chainlink)
├─ Already reported issues
└─ Issues requiring social engineering
```

---

## RUNBOOK TEMPLATES

### Daily Operations Checklist

```
DAILY CHECKLIST
□ Check monitoring dashboards for anomalies
□ Review Oracle freshness (< 1 hour staleness)
□ Check marketplace listing count / volume
□ Review gas prices and adjust fee parameters if needed
□ Check pending governance proposals
□ Review Forta/Defender alerts from last 24 hours
□ Verify IPFS pinning health
□ Check The Graph indexing lag
```

### Weekly Operations Checklist

```
WEEKLY CHECKLIST
□ Review access control roles and permissions
□ Check multisig signer availability
□ Review bridge balances across chains
□ Audit new whitelist/blacklist entries
□ Check contract upgrade proposals
□ Review bug bounty submissions
□ Cross-chain state reconciliation
□ Dependency update check (OpenZeppelin, etc.)
□ Backup verification
□ Rotate API keys if needed
```

### Pre-Deployment Checklist

```
DEPLOYMENT CHECKLIST
□ All tests passing (unit, fuzz, invariant)
□ Coverage > 80%
□ Slither clean (no high/medium findings)
□ Formal verification specs passing
□ Gas benchmarks within acceptable range
□ Testnet deployment successful
□ Frontend tested against testnet
□ Audit report received and findings addressed
□ Multisig signers confirmed availability
□ Monitoring alerts configured
□ Rollback plan documented
□ Communication plan ready
□ Legal review complete (if RWA)
```
