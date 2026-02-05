# Institutional NFT Protocol Designer

Design complete NFT/tokenization protocols for digital and real-world assets at institutional level: architecture, smart contracts, legal layers, security, governance, compliance, and DeFi integrations.

## How It Works

This skill uses a **Python engine** for targeted extraction instead of loading full modules into context. This achieves **90-99% token reduction**.

```
USER REQUEST
     |
  Engine searches 783KB source (19 modules, 99 contracts, 17 ERC standards)
     |
  Returns ONLY the relevant contract/section (~500-1,250 tokens)
     |
  Instead of loading full module (~18,000 tokens) or all modules (~230,000 tokens)
```

## Usage

### Via CLI (preferred for bulk operations)

```bash
# Search across all contracts, sections, and standards
python3 -m engine search "lending"

# Extract a specific contract (~750 tokens vs 18,000)
python3 -m engine get-contract FractionalVault

# Get a module section
python3 -m engine get-section module-3-fractionalization-vault

# List all 19 modules with summaries
python3 -m engine list-modules

# List all 99 contracts
python3 -m engine list-contracts

# Find contracts by ERC standard
python3 -m engine find-standard ERC-6551

# Show module outline (headings + declarations only)
python3 -m engine outline defi.md

# View token usage savings
python3 -m engine token-report

# Batch generate modified contracts via Anthropic API
python3 -m engine batch-generate --specs '[{"base":"FractionalVault","prompt":"Add ERC-20 support"}]'

# Analyze a module via API
python3 -m engine batch-analyze --module defi.md --prompt "Find reentrancy vulnerabilities"
```

### Via MCP Server (auto-discovery by Claude Code)

The `.mcp.json` at the skill root registers 11 MCP tools:
- `nft_search` — Search contracts, sections, standards
- `nft_get_contract` — Extract a specific contract
- `nft_get_section` — Extract a module section
- `nft_list_modules` — List all modules with stats
- `nft_list_contracts` — List all contracts with metadata
- `nft_list_standards` — List all ERC standards with contracts
- `nft_find_by_standard` — Find contracts by ERC standard
- `nft_outline` — Module structure outline
- `nft_build_index` — Rebuild the search index
- `nft_check_index` — Verify index freshness
- `nft_usage_report` — Token usage statistics

### First-Time Setup

The index auto-builds on first use. To manually rebuild:

```bash
python3 -m engine build-index
python3 -m engine check-index   # verify freshness
```

All engine code is in `engine/` (stdlib only, no pip install needed). Batch commands (`batch-generate`, `batch-analyze`) require `pip3 install anthropic` and `ANTHROPIC_API_KEY`.

## Architecture

```
~/.claude/skills/nft-protocol/
├── SKILL.md              # This file
├── .mcp.json             # MCP server config
├── modules/              # 19 markdown modules (783KB source of truth)
├── engine/               # Python extraction engine
│   ├── __main__.py       # Entry: python3 -m engine <command>
│   ├── cli.py            # 14 CLI commands
│   ├── indexer.py        # Markdown parser -> JSON index
│   ├── extractor.py      # Byte-offset targeted extraction
│   ├── searcher.py       # Fuzzy search + discovery
│   ├── tracker.py        # Token usage logging
│   ├── batch.py          # Anthropic API batch ops
│   ├── mcp_server.py     # MCP stdio JSON-RPC 2.0
│   └── schema.py         # Dataclasses
└── data/
    ├── index.json        # Pre-built search index (~60KB)
    └── token_log.jsonl   # Usage tracking
```

## Module Index

| Module | Contracts | Sections | Key Standards |
|--------|-----------|----------|---------------|
| `core.md` | 1 | 7 | ERC-721, ERC-2981 |
| `marketplace.md` | 7 | 10 | ERC-721, ERC-2981 |
| `minting.md` | 9 | 19 | ERC-721, ERC-2771, EIP-712 |
| `defi.md` | 12 | 13 | ERC-721, ERC-4907 |
| `governance.md` | 6 | 44 | KYC/AML, DAO, ZK compliance |
| `advanced-nfts.md` | 13 | 24 | ERC-1155, ERC-5192, ERC-6551, ERC-998 |
| `media.md` | 4 | 9 | ERC-721, ERC-2981 |
| `gaming.md` | 2 | 5 | ERC-721, ERC-1155 |
| `social.md` | 4 | 5 | ERC-721, EAS |
| `infrastructure.md` | 11 | 51 | ERC-4337, ERC-721, ERC-1155 |
| `modern-standards.md` | 10 | 13 | ERC-4907, ERC-6900, ERC-7572, ERC-7579 |
| `frontend.md` | 0 | 17 | React, Web3 hooks |
| `backend.md` | 0 | 9 | ERC-721 |
| `sdk-config.md` | 2 | 66 | ERC-4337, ERC-721 |
| `security-testing.md` | 7 | 13 | ERC-721, ERC-1967, ERC-2981 |
| `foundry-testing.md` | 9 | 38 | ERC-1967, Forge, Certora |
| `cicd.md` | 0 | 12 | GitHub Actions, CI pipeline |
| `operations.md` | 0 | 26 | Incident response, monitoring |
| `standards.md` | 2 | 5 | ERC-5169, ERC-5643, ERC-721 |
| **Total** | **99** | **386** | **17 ERC standards** |

## Token Reduction Performance

| Operation | Without Engine | With Engine | Reduction |
|-----------|---------------|-------------|-----------|
| Search all contracts | ~230,000 | ~500 | **99.8%** |
| Get one contract | ~18,000 | ~750 | **95.8%** |
| Get one section | ~18,000 | ~1,250 | **93.1%** |
| Module outline | ~18,000 | ~500 | **97.2%** |

## Security Stack

OpenZeppelin audited bases, ReentrancyGuard, Address.sendValue(), RBAC, Pausable, UUPS proxy, Timelock, Gnosis Safe multisig, formal verification (Certora/Halmos), static analysis (Slither/Mythril), fuzz + invariant testing (Foundry).

## Output Format

When invoked, provide based on the user's use case:
1. Architecture diagram (ASCII)
2. Smart contract code (use `get-contract` to extract)
3. Metadata schema (JSON)
4. Mint flow (step-by-step)
5. Security checklist
6. Governance model
7. RWA legal linkage (if applicable)
8. DeFi integration model
9. Deployment steps
10. Monitoring setup

## Invocation

```bash
/nft-protocol <your use case>
```
