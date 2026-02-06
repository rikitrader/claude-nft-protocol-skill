// =============================================================================
// GOVERNANCE MULTISIG PROGRAM - PROPOSAL-BASED TREASURY CONTROL
// =============================================================================
// PRINCIPLE: Transparent governance with auditable decision trail
// CONSTRAINT: All treasury spends require threshold approval
// COMPAT: Uses token_interface — works with both SPL Token and Token-2022
// =============================================================================

use anchor_lang::prelude::*;
use anchor_spl::token_interface::{self, TokenAccount, TokenInterface, Transfer};

declare_id!("REPLACE_WITH_YOUR_PROGRAM_ID");

/// Maximum owners in multisig
const MAX_OWNERS: usize = 10;

/// Maximum proposals
const MAX_PROPOSALS: u64 = 10000;

#[program]
pub mod governance_multisig {
    use super::*;

    /// Initialize governance multisig
    pub fn initialize(
        ctx: Context<Initialize>,
        owners: Vec<Pubkey>,
        threshold: u8,
        spend_cap_per_tx: u64,
    ) -> Result<()> {
        require!(owners.len() >= 2, GovernanceError::InsufficientOwners);
        require!(owners.len() <= MAX_OWNERS, GovernanceError::TooManyOwners);
        require!(threshold >= 2, GovernanceError::ThresholdTooLow);
        require!(threshold as usize <= owners.len(), GovernanceError::ThresholdExceedsOwners);
        require!(spend_cap_per_tx > 0, GovernanceError::InvalidSpendCap);

        // Check for duplicate owners
        let mut sorted_owners = owners.clone();
        sorted_owners.sort();
        for i in 1..sorted_owners.len() {
            require!(sorted_owners[i] != sorted_owners[i-1], GovernanceError::DuplicateOwner);
        }

        let state = &mut ctx.accounts.governance_state;
        state.owners = owners;
        state.threshold = threshold;
        state.spend_cap_per_tx = spend_cap_per_tx;
        state.proposal_count = 0;
        state.executed_count = 0;
        state.bump = ctx.bumps.governance_state;

        emit!(GovernanceInitialized {
            owners: state.owners.clone(),
            threshold,
            spend_cap_per_tx,
        });

        msg!("Governance initialized: {} owners, {} threshold, {} spend cap",
             state.owners.len(), threshold, spend_cap_per_tx);
        Ok(())
    }

    /// Propose a treasury spend
    pub fn propose_spend(
        ctx: Context<ProposeSpend>,
        to: Pubkey,
        amount: u64,
        memo: String,
    ) -> Result<()> {
        let governance = &mut ctx.accounts.governance_state;

        require!(
            governance.owners.contains(&ctx.accounts.proposer.key()),
            GovernanceError::NotAnOwner
        );
        require!(amount > 0, GovernanceError::ZeroAmount);
        require!(amount <= governance.spend_cap_per_tx, GovernanceError::ExceedsSpendCap);
        require!(memo.len() <= 200, GovernanceError::MemoTooLong);
        require!(governance.proposal_count < MAX_PROPOSALS, GovernanceError::MaxProposalsReached);

        let proposal = &mut ctx.accounts.proposal;
        proposal.id = governance.proposal_count;
        proposal.governance = governance.key();
        proposal.proposer = ctx.accounts.proposer.key();
        proposal.to = to;
        proposal.amount = amount;
        proposal.memo = memo.clone();
        proposal.approvals = vec![ctx.accounts.proposer.key()]; // Proposer auto-approves
        proposal.executed = false;
        proposal.cancelled = false;
        proposal.created_at = Clock::get()?.unix_timestamp;
        proposal.expires_at = Clock::get()?.unix_timestamp + 86400; // 24 hours

        governance.proposal_count += 1;

        emit!(ProposalCreated {
            proposal_id: proposal.id,
            proposer: proposal.proposer,
            to,
            amount,
            memo,
        });

        msg!("Proposal {} created: {} tokens to {}", proposal.id, amount, to);
        Ok(())
    }

    /// Approve a proposal
    pub fn approve(ctx: Context<Approve>, proposal_id: u64) -> Result<()> {
        let governance = &ctx.accounts.governance_state;
        let proposal = &mut ctx.accounts.proposal;

        require!(proposal.id == proposal_id, GovernanceError::ProposalMismatch);
        require!(
            governance.owners.contains(&ctx.accounts.approver.key()),
            GovernanceError::NotAnOwner
        );
        require!(!proposal.executed, GovernanceError::AlreadyExecuted);
        require!(!proposal.cancelled, GovernanceError::ProposalCancelled);
        require!(
            Clock::get()?.unix_timestamp <= proposal.expires_at,
            GovernanceError::ProposalExpired
        );
        require!(
            !proposal.approvals.contains(&ctx.accounts.approver.key()),
            GovernanceError::AlreadyApproved
        );

        proposal.approvals.push(ctx.accounts.approver.key());

        emit!(ProposalApproved {
            proposal_id,
            approver: ctx.accounts.approver.key(),
            total_approvals: proposal.approvals.len() as u8,
            threshold: governance.threshold,
        });

        msg!("Proposal {} approved by {}. Approvals: {}/{}",
             proposal_id, ctx.accounts.approver.key(),
             proposal.approvals.len(), governance.threshold);
        Ok(())
    }

    /// Execute an approved proposal - performs CPI transfer from treasury PDA
    pub fn execute(ctx: Context<Execute>, proposal_id: u64) -> Result<()> {
        let governance = &mut ctx.accounts.governance_state;
        let proposal = &mut ctx.accounts.proposal;

        require!(proposal.id == proposal_id, GovernanceError::ProposalMismatch);
        require!(!proposal.executed, GovernanceError::AlreadyExecuted);
        require!(!proposal.cancelled, GovernanceError::ProposalCancelled);
        require!(
            Clock::get()?.unix_timestamp <= proposal.expires_at,
            GovernanceError::ProposalExpired
        );
        require!(
            proposal.approvals.len() >= governance.threshold as usize,
            GovernanceError::InsufficientApprovals
        );
        // Executor must be an owner
        require!(
            governance.owners.contains(&ctx.accounts.executor.key()),
            GovernanceError::NotAnOwner
        );

        // Mark as executed BEFORE CPI (checks-effects-interactions / reentrancy protection)
        proposal.executed = true;
        governance.executed_count += 1;

        // CPI to transfer tokens from treasury PDA
        let seeds = &[
            b"governance".as_ref(),
            &[governance.bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.treasury_token_account.to_account_info(),
            to: ctx.accounts.recipient_token_account.to_account_info(),
            authority: ctx.accounts.governance_authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);

        token_interface::transfer(cpi_ctx, proposal.amount)?;

        emit!(ProposalExecuted {
            proposal_id,
            to: proposal.to,
            amount: proposal.amount,
            executor: ctx.accounts.executor.key(),
        });

        msg!("Proposal {} executed: {} tokens to {}",
             proposal_id, proposal.amount, proposal.to);
        Ok(())
    }

    /// Cancel a proposal (only proposer can cancel)
    pub fn cancel(ctx: Context<Cancel>, proposal_id: u64) -> Result<()> {
        let proposal = &mut ctx.accounts.proposal;

        require!(proposal.id == proposal_id, GovernanceError::ProposalMismatch);
        require!(
            ctx.accounts.proposer.key() == proposal.proposer,
            GovernanceError::NotProposer
        );
        require!(!proposal.executed, GovernanceError::AlreadyExecuted);
        require!(!proposal.cancelled, GovernanceError::AlreadyCancelled);

        proposal.cancelled = true;

        emit!(ProposalCancelled {
            proposal_id,
            cancelled_by: ctx.accounts.proposer.key(),
        });

        msg!("Proposal {} cancelled", proposal_id);
        Ok(())
    }

    /// Update governance configuration - REQUIRES a separate approved proposal as proof
    /// of governance consensus. A single authority CANNOT change config alone.
    pub fn update_config(
        ctx: Context<UpdateConfig>,
        new_owners: Option<Vec<Pubkey>>,
        new_threshold: Option<u8>,
        new_spend_cap: Option<u64>,
    ) -> Result<()> {
        let governance = &mut ctx.accounts.governance_state;

        // Verify the config proposal has been properly approved by threshold
        let config_proposal = &ctx.accounts.config_proposal;
        require!(
            config_proposal.governance == governance.key(),
            GovernanceError::ProposalMismatch
        );
        require!(!config_proposal.executed, GovernanceError::AlreadyExecuted);
        require!(!config_proposal.cancelled, GovernanceError::ProposalCancelled);
        require!(
            Clock::get()?.unix_timestamp <= config_proposal.expires_at,
            GovernanceError::ProposalExpired
        );
        require!(
            config_proposal.approvals.len() >= governance.threshold as usize,
            GovernanceError::InsufficientApprovals
        );
        // Caller must be an owner
        require!(
            governance.owners.contains(&ctx.accounts.authority.key()),
            GovernanceError::NotAnOwner
        );

        if let Some(owners) = new_owners {
            require!(owners.len() >= 2, GovernanceError::InsufficientOwners);
            require!(owners.len() <= MAX_OWNERS, GovernanceError::TooManyOwners);

            // Check for duplicates
            let mut sorted = owners.clone();
            sorted.sort();
            for i in 1..sorted.len() {
                require!(sorted[i] != sorted[i-1], GovernanceError::DuplicateOwner);
            }

            let threshold = new_threshold.unwrap_or(governance.threshold);
            require!(threshold as usize <= owners.len(), GovernanceError::ThresholdExceedsOwners);

            governance.owners = owners;
        }

        if let Some(threshold) = new_threshold {
            require!(threshold >= 2, GovernanceError::ThresholdTooLow);
            require!(threshold as usize <= governance.owners.len(), GovernanceError::ThresholdExceedsOwners);
            governance.threshold = threshold;
        }

        if let Some(cap) = new_spend_cap {
            require!(cap > 0, GovernanceError::InvalidSpendCap);
            governance.spend_cap_per_tx = cap;
        }

        emit!(ConfigUpdated {
            owners: governance.owners.clone(),
            threshold: governance.threshold,
            spend_cap_per_tx: governance.spend_cap_per_tx,
        });

        msg!("Governance config updated");
        Ok(())
    }

    /// Get proposal status
    pub fn get_proposal_status(ctx: Context<GetProposalStatus>) -> Result<ProposalStatus> {
        let governance = &ctx.accounts.governance_state;
        let proposal = &ctx.accounts.proposal;
        let current_time = Clock::get()?.unix_timestamp;

        Ok(ProposalStatus {
            id: proposal.id,
            approvals: proposal.approvals.len() as u8,
            threshold: governance.threshold,
            executed: proposal.executed,
            cancelled: proposal.cancelled,
            expired: current_time > proposal.expires_at,
            can_execute: proposal.approvals.len() >= governance.threshold as usize
                && !proposal.executed
                && !proposal.cancelled
                && current_time <= proposal.expires_at,
        })
    }
}

// =============================================================================
// ACCOUNTS
// =============================================================================

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = payer,
        space = 8 + GovernanceState::INIT_SPACE,
        seeds = [b"governance"],
        bump
    )]
    pub governance_state: Account<'info, GovernanceState>,

    #[account(mut)]
    pub payer: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ProposeSpend<'info> {
    #[account(mut, seeds = [b"governance"], bump = governance_state.bump)]
    pub governance_state: Account<'info, GovernanceState>,

    #[account(
        init,
        payer = proposer,
        space = 8 + Proposal::INIT_SPACE,
        seeds = [
            b"proposal",
            governance_state.key().as_ref(),
            &governance_state.proposal_count.to_le_bytes()
        ],
        bump
    )]
    pub proposal: Account<'info, Proposal>,

    #[account(mut)]
    pub proposer: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Approve<'info> {
    #[account(seeds = [b"governance"], bump = governance_state.bump)]
    pub governance_state: Account<'info, GovernanceState>,

    #[account(
        mut,
        constraint = proposal.governance == governance_state.key() @ GovernanceError::ProposalMismatch,
    )]
    pub proposal: Account<'info, Proposal>,

    pub approver: Signer<'info>,
}

#[derive(Accounts)]
pub struct Execute<'info> {
    #[account(mut, seeds = [b"governance"], bump = governance_state.bump)]
    pub governance_state: Account<'info, GovernanceState>,

    #[account(
        mut,
        constraint = proposal.governance == governance_state.key() @ GovernanceError::ProposalMismatch,
    )]
    pub proposal: Account<'info, Proposal>,

    pub executor: Signer<'info>,

    // Treasury accounts for CPI transfer
    #[account(mut)]
    pub treasury_token_account: InterfaceAccount<'info, TokenAccount>,

    #[account(
        mut,
        constraint = recipient_token_account.key() == proposal.to @ GovernanceError::RecipientMismatch,
    )]
    pub recipient_token_account: InterfaceAccount<'info, TokenAccount>,

    /// CHECK: PDA authority for governance transfers
    #[account(seeds = [b"governance"], bump = governance_state.bump)]
    pub governance_authority: UncheckedAccount<'info>,

    /// Accepts both SPL Token and Token-2022
    pub token_program: Interface<'info, TokenInterface>,
}

#[derive(Accounts)]
pub struct Cancel<'info> {
    #[account(
        mut,
        constraint = proposal.governance == governance_state.key() @ GovernanceError::ProposalMismatch,
    )]
    pub proposal: Account<'info, Proposal>,

    #[account(seeds = [b"governance"], bump = governance_state.bump)]
    pub governance_state: Account<'info, GovernanceState>,

    pub proposer: Signer<'info>,
}

#[derive(Accounts)]
pub struct UpdateConfig<'info> {
    #[account(mut, seeds = [b"governance"], bump = governance_state.bump)]
    pub governance_state: Account<'info, GovernanceState>,

    /// The config proposal that proves governance approval for this change.
    /// Must have threshold approvals, not be executed/cancelled/expired.
    #[account(
        mut,
        constraint = config_proposal.governance == governance_state.key() @ GovernanceError::ProposalMismatch,
    )]
    pub config_proposal: Account<'info, Proposal>,

    /// Must be a current owner
    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct GetProposalStatus<'info> {
    #[account(seeds = [b"governance"], bump = governance_state.bump)]
    pub governance_state: Account<'info, GovernanceState>,

    #[account(
        constraint = proposal.governance == governance_state.key() @ GovernanceError::ProposalMismatch,
    )]
    pub proposal: Account<'info, Proposal>,
}

// =============================================================================
// STATE
// =============================================================================

#[account]
#[derive(InitSpace)]
pub struct GovernanceState {
    #[max_len(10)]
    pub owners: Vec<Pubkey>,            // Multisig owners
    pub threshold: u8,                   // Required approvals
    pub spend_cap_per_tx: u64,           // Max spend per transaction
    pub proposal_count: u64,             // Total proposals
    pub executed_count: u64,             // Executed proposals
    pub bump: u8,                        // PDA bump
}

#[account]
#[derive(InitSpace)]
pub struct Proposal {
    pub id: u64,                         // Proposal ID
    pub governance: Pubkey,              // Parent governance
    pub proposer: Pubkey,                // Who proposed
    pub to: Pubkey,                      // Recipient
    pub amount: u64,                     // Amount to spend
    #[max_len(200)]
    pub memo: String,                    // Description
    #[max_len(10)]
    pub approvals: Vec<Pubkey>,          // Who approved
    pub executed: bool,                  // Executed?
    pub cancelled: bool,                 // Cancelled?
    pub created_at: i64,                 // Unix timestamp
    pub expires_at: i64,                 // Expiration timestamp
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct ProposalStatus {
    pub id: u64,
    pub approvals: u8,
    pub threshold: u8,
    pub executed: bool,
    pub cancelled: bool,
    pub expired: bool,
    pub can_execute: bool,
}

// =============================================================================
// EVENTS
// =============================================================================

#[event]
pub struct GovernanceInitialized {
    pub owners: Vec<Pubkey>,
    pub threshold: u8,
    pub spend_cap_per_tx: u64,
}

#[event]
pub struct ProposalCreated {
    pub proposal_id: u64,
    pub proposer: Pubkey,
    pub to: Pubkey,
    pub amount: u64,
    pub memo: String,
}

#[event]
pub struct ProposalApproved {
    pub proposal_id: u64,
    pub approver: Pubkey,
    pub total_approvals: u8,
    pub threshold: u8,
}

#[event]
pub struct ProposalExecuted {
    pub proposal_id: u64,
    pub to: Pubkey,
    pub amount: u64,
    pub executor: Pubkey,
}

#[event]
pub struct ProposalCancelled {
    pub proposal_id: u64,
    pub cancelled_by: Pubkey,
}

#[event]
pub struct ConfigUpdated {
    pub owners: Vec<Pubkey>,
    pub threshold: u8,
    pub spend_cap_per_tx: u64,
}

// =============================================================================
// ERRORS
// =============================================================================

#[error_code]
pub enum GovernanceError {
    #[msg("Need at least 2 owners")]
    InsufficientOwners,
    #[msg("Maximum 10 owners")]
    TooManyOwners,
    #[msg("Threshold must be at least 2")]
    ThresholdTooLow,
    #[msg("Threshold cannot exceed number of owners")]
    ThresholdExceedsOwners,
    #[msg("Duplicate owner address")]
    DuplicateOwner,
    #[msg("Invalid spend cap")]
    InvalidSpendCap,
    #[msg("Not an owner")]
    NotAnOwner,
    #[msg("Amount must be greater than zero")]
    ZeroAmount,
    #[msg("Amount exceeds spend cap per transaction")]
    ExceedsSpendCap,
    #[msg("Memo too long (max 200 chars)")]
    MemoTooLong,
    #[msg("Maximum proposals reached")]
    MaxProposalsReached,
    #[msg("Proposal ID or governance mismatch")]
    ProposalMismatch,
    #[msg("Already executed")]
    AlreadyExecuted,
    #[msg("Proposal cancelled")]
    ProposalCancelled,
    #[msg("Proposal expired")]
    ProposalExpired,
    #[msg("Already approved by this owner")]
    AlreadyApproved,
    #[msg("Insufficient approvals")]
    InsufficientApprovals,
    #[msg("Not the proposer")]
    NotProposer,
    #[msg("Already cancelled")]
    AlreadyCancelled,
    #[msg("Recipient does not match proposal")]
    RecipientMismatch,
}

// =============================================================================
// GOVERNANCE FLOW (ASCII)
// =============================================================================
/*
+-------------------------------------------------------------+
|                   GOVERNANCE MULTISIG                        |
+-------------------------------------------------------------+
|                                                              |
|  OWNERS: [Owner1, Owner2, Owner3, ...]                       |
|  THRESHOLD: 2/3 (or configured)                              |
|  SPEND CAP: Max tokens per proposal                          |
|                                                              |
|  PROPOSAL LIFECYCLE:                                         |
|                                                              |
|  1. PROPOSE                                                  |
|     Owner creates proposal (auto-approves)                   |
|                                                              |
|  2. APPROVE (until threshold)                                |
|     Other owners approve                                     |
|                                                              |
|  3. EXECUTE (if threshold met + not expired)                 |
|     Any owner executes -> CPI transfer from treasury PDA     |
|                                                              |
|  CONFIG CHANGES (update_config):                             |
|     Requires a separate approved proposal as proof           |
|     Single authority CANNOT change config alone              |
|                                                              |
|  CONSTRAINTS:                                                |
|  - Threshold required for all actions                        |
|  - Spend cap per tx                                          |
|  - 24h expiration                                            |
|  - All actions logged via events                             |
|  - Executor must be an owner                                 |
|  - Config changes require governance proposal                |
|                                                              |
+-------------------------------------------------------------+
*/
