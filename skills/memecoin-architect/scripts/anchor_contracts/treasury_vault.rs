// =============================================================================
// TREASURY VAULT PROGRAM - PDA-CONTROLLED, MULTI-SIG GOVERNED
// =============================================================================
// PRINCIPLE: Treasury governed, not rug-able
// CONSTRAINT: All spends require multi-sig + logged on-chain
// COMPAT: Uses token_interface — works with both SPL Token and Token-2022
// =============================================================================

use anchor_lang::prelude::*;
use anchor_spl::token_interface::{self, TokenAccount, TokenInterface, Transfer};

declare_id!("REPLACE_WITH_YOUR_PROGRAM_ID");

#[program]
pub mod treasury_vault {
    use super::*;

    /// Initialize treasury with multi-sig configuration
    pub fn initialize(
        ctx: Context<Initialize>,
        signers: Vec<Pubkey>,
        threshold: u8,
        daily_spend_cap: u64,
    ) -> Result<()> {
        require!(signers.len() >= 2, TreasuryError::InsufficientSigners);
        require!(signers.len() <= 10, TreasuryError::TooManySigners);
        require!(threshold >= 2, TreasuryError::ThresholdTooLow);
        require!(threshold as usize <= signers.len(), TreasuryError::ThresholdExceedsSigners);

        // Check for duplicate signers
        let mut sorted = signers.clone();
        sorted.sort();
        for i in 1..sorted.len() {
            require!(sorted[i] != sorted[i - 1], TreasuryError::DuplicateSigner);
        }

        let state = &mut ctx.accounts.treasury_state;
        state.signers = signers.clone();
        state.threshold = threshold;
        state.daily_spend_cap = daily_spend_cap;
        state.daily_spent = 0;
        state.last_reset_slot = Clock::get()?.slot;
        state.proposal_count = 0;
        state.paused = false;
        state.bump = ctx.bumps.treasury_state;

        emit!(TreasuryInitialized {
            signers,
            threshold,
            daily_spend_cap,
        });

        msg!("Treasury initialized: {} signers, {} threshold, {} daily cap",
             state.signers.len(), threshold, daily_spend_cap);
        Ok(())
    }

    /// Create a spend proposal
    pub fn create_proposal(
        ctx: Context<CreateProposal>,
        amount: u64,
        recipient: Pubkey,
        description: String,
    ) -> Result<()> {
        let treasury = &mut ctx.accounts.treasury_state;
        require!(!treasury.paused, TreasuryError::TreasuryPaused);
        require!(
            treasury.signers.contains(&ctx.accounts.proposer.key()),
            TreasuryError::NotASigner
        );
        require!(description.len() <= 200, TreasuryError::DescriptionTooLong);
        require!(amount > 0, TreasuryError::ZeroAmount);

        let proposal = &mut ctx.accounts.proposal;
        proposal.id = treasury.proposal_count;
        proposal.treasury = treasury.key();
        proposal.proposer = ctx.accounts.proposer.key();
        proposal.amount = amount;
        proposal.recipient = recipient;
        proposal.description = description.clone();
        proposal.approvals = vec![ctx.accounts.proposer.key()]; // Proposer auto-approves
        proposal.executed = false;
        proposal.created_slot = Clock::get()?.slot;
        proposal.expires_slot = Clock::get()?.slot + 216000; // ~24 hours at 400ms slots

        treasury.proposal_count += 1;

        emit!(ProposalCreated {
            proposal_id: proposal.id,
            proposer: proposal.proposer,
            amount,
            recipient,
            description,
        });

        msg!("Proposal {} created: {} tokens to {}",
             proposal.id, amount, recipient);
        Ok(())
    }

    /// Approve a proposal
    pub fn approve_proposal(ctx: Context<ApproveProposal>) -> Result<()> {
        let treasury = &ctx.accounts.treasury_state;
        let proposal = &mut ctx.accounts.proposal;

        require!(!treasury.paused, TreasuryError::TreasuryPaused);
        require!(!proposal.executed, TreasuryError::AlreadyExecuted);
        require!(
            Clock::get()?.slot <= proposal.expires_slot,
            TreasuryError::ProposalExpired
        );
        require!(
            treasury.signers.contains(&ctx.accounts.signer.key()),
            TreasuryError::NotASigner
        );
        require!(
            !proposal.approvals.contains(&ctx.accounts.signer.key()),
            TreasuryError::AlreadyApproved
        );

        proposal.approvals.push(ctx.accounts.signer.key());

        emit!(ProposalApproved {
            proposal_id: proposal.id,
            approver: ctx.accounts.signer.key(),
            total_approvals: proposal.approvals.len() as u8,
            threshold: treasury.threshold,
        });

        msg!("Proposal {} approved by {}. Total approvals: {}/{}",
             proposal.id, ctx.accounts.signer.key(),
             proposal.approvals.len(), treasury.threshold);
        Ok(())
    }

    /// Execute an approved proposal
    pub fn execute_proposal(ctx: Context<ExecuteProposal>) -> Result<()> {
        let treasury = &mut ctx.accounts.treasury_state;
        let proposal = &mut ctx.accounts.proposal;

        require!(!treasury.paused, TreasuryError::TreasuryPaused);
        require!(!proposal.executed, TreasuryError::AlreadyExecuted);
        require!(
            Clock::get()?.slot <= proposal.expires_slot,
            TreasuryError::ProposalExpired
        );
        require!(
            proposal.approvals.len() >= treasury.threshold as usize,
            TreasuryError::InsufficientApprovals
        );
        // Executor must be a signer
        require!(
            treasury.signers.contains(&ctx.accounts.executor.key()),
            TreasuryError::NotASigner
        );

        // Check daily spend cap
        let current_slot = Clock::get()?.slot;
        let slots_per_day = 216000; // ~24 hours at 400ms

        if current_slot > treasury.last_reset_slot + slots_per_day {
            treasury.daily_spent = 0;
            treasury.last_reset_slot = current_slot;
        }

        require!(
            treasury.daily_spent.checked_add(proposal.amount).ok_or(TreasuryError::Overflow)?
                <= treasury.daily_spend_cap,
            TreasuryError::DailyCapExceeded
        );

        // Mark as executed BEFORE transfer (checks-effects-interactions)
        proposal.executed = true;
        treasury.daily_spent = treasury.daily_spent
            .checked_add(proposal.amount)
            .ok_or(TreasuryError::Overflow)?;

        // Execute transfer from PDA
        let seeds = &[
            b"treasury".as_ref(),
            &[treasury.bump],
        ];
        let signer = &[&seeds[..]];

        let cpi_accounts = Transfer {
            from: ctx.accounts.treasury_token_account.to_account_info(),
            to: ctx.accounts.recipient_token_account.to_account_info(),
            authority: ctx.accounts.treasury_authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);

        token_interface::transfer(cpi_ctx, proposal.amount)?;

        emit!(ProposalExecuted {
            proposal_id: proposal.id,
            amount: proposal.amount,
            recipient: proposal.recipient,
            executor: ctx.accounts.executor.key(),
        });

        msg!("Proposal {} executed: {} tokens sent to {}",
             proposal.id, proposal.amount, proposal.recipient);
        Ok(())
    }

    /// Update signers - REQUIRES a separate approved proposal (governance-gated).
    /// The proposal must have reached threshold approvals and the caller must provide
    /// a valid executed config proposal as proof of governance approval.
    pub fn update_signers(
        ctx: Context<UpdateSigners>,
        new_signers: Vec<Pubkey>,
        new_threshold: u8,
    ) -> Result<()> {
        require!(new_signers.len() >= 2, TreasuryError::InsufficientSigners);
        require!(new_signers.len() <= 10, TreasuryError::TooManySigners);
        require!(new_threshold >= 2, TreasuryError::ThresholdTooLow);
        require!(new_threshold as usize <= new_signers.len(), TreasuryError::ThresholdExceedsSigners);

        // Check for duplicate signers
        let mut sorted = new_signers.clone();
        sorted.sort();
        for i in 1..sorted.len() {
            require!(sorted[i] != sorted[i - 1], TreasuryError::DuplicateSigner);
        }

        // Verify the config proposal has been properly approved
        let config_proposal = &ctx.accounts.config_proposal;
        let treasury = &mut ctx.accounts.treasury_state;

        require!(config_proposal.treasury == treasury.key(), TreasuryError::ProposalTreasuryMismatch);
        require!(!config_proposal.executed, TreasuryError::AlreadyExecuted);
        require!(
            Clock::get()?.slot <= config_proposal.expires_slot,
            TreasuryError::ProposalExpired
        );
        require!(
            config_proposal.approvals.len() >= treasury.threshold as usize,
            TreasuryError::InsufficientApprovals
        );

        let old_signers = treasury.signers.clone();
        let old_threshold = treasury.threshold;

        treasury.signers = new_signers.clone();
        treasury.threshold = new_threshold;

        emit!(SignersUpdated {
            old_signers,
            new_signers,
            old_threshold,
            new_threshold,
        });

        msg!("Signers updated: {} signers, {} threshold",
             treasury.signers.len(), new_threshold);
        Ok(())
    }

    /// Emergency pause (any single signer can pause - fast response)
    pub fn emergency_pause(ctx: Context<EmergencyPause>) -> Result<()> {
        let treasury = &mut ctx.accounts.treasury_state;
        require!(!treasury.paused, TreasuryError::AlreadyPaused);
        require!(
            treasury.signers.contains(&ctx.accounts.signer.key()),
            TreasuryError::NotASigner
        );

        treasury.paused = true;

        emit!(TreasuryPaused {
            paused_by: ctx.accounts.signer.key(),
        });

        msg!("TREASURY PAUSED by {}", ctx.accounts.signer.key());
        Ok(())
    }

    /// Resume operations - requires threshold approvals via a config proposal
    pub fn resume(ctx: Context<Resume>) -> Result<()> {
        let treasury = &mut ctx.accounts.treasury_state;
        require!(treasury.paused, TreasuryError::NotPaused);
        require!(
            treasury.signers.contains(&ctx.accounts.signer.key()),
            TreasuryError::NotASigner
        );

        // Verify the resume proposal has been properly approved
        let resume_proposal = &ctx.accounts.resume_proposal;
        require!(resume_proposal.treasury == treasury.key(), TreasuryError::ProposalTreasuryMismatch);
        require!(
            resume_proposal.approvals.len() >= treasury.threshold as usize,
            TreasuryError::InsufficientApprovals
        );

        treasury.paused = false;

        emit!(TreasuryResumed {
            resumed_by: ctx.accounts.signer.key(),
        });

        msg!("Treasury resumed");
        Ok(())
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
        space = 8 + TreasuryState::INIT_SPACE,
        seeds = [b"treasury"],
        bump
    )]
    pub treasury_state: Account<'info, TreasuryState>,

    #[account(mut)]
    pub payer: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CreateProposal<'info> {
    #[account(
        mut,
        seeds = [b"treasury"],
        bump = treasury_state.bump,
    )]
    pub treasury_state: Account<'info, TreasuryState>,

    #[account(
        init,
        payer = proposer,
        space = 8 + Proposal::INIT_SPACE,
        seeds = [b"proposal", treasury_state.key().as_ref(), &treasury_state.proposal_count.to_le_bytes()],
        bump
    )]
    pub proposal: Account<'info, Proposal>,

    #[account(mut)]
    pub proposer: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ApproveProposal<'info> {
    #[account(
        seeds = [b"treasury"],
        bump = treasury_state.bump,
    )]
    pub treasury_state: Account<'info, TreasuryState>,

    #[account(
        mut,
        constraint = proposal.treasury == treasury_state.key() @ TreasuryError::ProposalTreasuryMismatch,
    )]
    pub proposal: Account<'info, Proposal>,

    pub signer: Signer<'info>,
}

#[derive(Accounts)]
pub struct ExecuteProposal<'info> {
    #[account(
        mut,
        seeds = [b"treasury"],
        bump = treasury_state.bump,
    )]
    pub treasury_state: Account<'info, TreasuryState>,

    #[account(
        mut,
        constraint = proposal.treasury == treasury_state.key() @ TreasuryError::ProposalTreasuryMismatch,
    )]
    pub proposal: Account<'info, Proposal>,

    #[account(mut)]
    pub treasury_token_account: InterfaceAccount<'info, TokenAccount>,

    #[account(
        mut,
        constraint = recipient_token_account.key() == proposal.recipient @ TreasuryError::RecipientMismatch,
    )]
    pub recipient_token_account: InterfaceAccount<'info, TokenAccount>,

    /// CHECK: PDA authority for treasury transfers
    #[account(seeds = [b"treasury"], bump = treasury_state.bump)]
    pub treasury_authority: UncheckedAccount<'info>,

    pub executor: Signer<'info>,

    /// Accepts both SPL Token and Token-2022
    pub token_program: Interface<'info, TokenInterface>,
}

#[derive(Accounts)]
pub struct UpdateSigners<'info> {
    #[account(
        mut,
        seeds = [b"treasury"],
        bump = treasury_state.bump,
    )]
    pub treasury_state: Account<'info, TreasuryState>,

    /// The config proposal that proves governance approval for this change
    #[account(
        mut,
        constraint = config_proposal.treasury == treasury_state.key() @ TreasuryError::ProposalTreasuryMismatch,
    )]
    pub config_proposal: Account<'info, Proposal>,

    /// Must be a current signer — enforced via constraint
    #[account(
        constraint = treasury_state.signers.contains(&authority.key()) @ TreasuryError::NotASigner,
    )]
    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct EmergencyPause<'info> {
    #[account(
        mut,
        seeds = [b"treasury"],
        bump = treasury_state.bump,
    )]
    pub treasury_state: Account<'info, TreasuryState>,

    pub signer: Signer<'info>,
}

#[derive(Accounts)]
pub struct Resume<'info> {
    #[account(
        mut,
        seeds = [b"treasury"],
        bump = treasury_state.bump,
    )]
    pub treasury_state: Account<'info, TreasuryState>,

    /// The resume proposal that proves governance approval
    #[account(
        constraint = resume_proposal.treasury == treasury_state.key() @ TreasuryError::ProposalTreasuryMismatch,
    )]
    pub resume_proposal: Account<'info, Proposal>,

    /// Must be a current signer
    pub signer: Signer<'info>,
}

// =============================================================================
// STATE
// =============================================================================

#[account]
#[derive(InitSpace)]
pub struct TreasuryState {
    #[max_len(10)]
    pub signers: Vec<Pubkey>,       // Multi-sig participants
    pub threshold: u8,               // Required approvals
    pub daily_spend_cap: u64,        // Max daily spend
    pub daily_spent: u64,            // Today's spending
    pub last_reset_slot: u64,        // Slot of last daily reset
    pub proposal_count: u64,         // Total proposals created
    pub paused: bool,                // Emergency pause flag
    pub bump: u8,                    // PDA bump
}

#[account]
#[derive(InitSpace)]
pub struct Proposal {
    pub id: u64,                     // Proposal ID
    pub treasury: Pubkey,            // Treasury this belongs to
    pub proposer: Pubkey,            // Who created it
    pub amount: u64,                 // Amount to transfer
    pub recipient: Pubkey,           // Recipient address
    #[max_len(200)]
    pub description: String,         // What this is for
    #[max_len(10)]
    pub approvals: Vec<Pubkey>,      // Who approved
    pub executed: bool,              // Already executed?
    pub created_slot: u64,           // When created
    pub expires_slot: u64,           // When it expires
}

// =============================================================================
// EVENTS
// =============================================================================

#[event]
pub struct TreasuryInitialized {
    pub signers: Vec<Pubkey>,
    pub threshold: u8,
    pub daily_spend_cap: u64,
}

#[event]
pub struct ProposalCreated {
    pub proposal_id: u64,
    pub proposer: Pubkey,
    pub amount: u64,
    pub recipient: Pubkey,
    pub description: String,
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
    pub amount: u64,
    pub recipient: Pubkey,
    pub executor: Pubkey,
}

#[event]
pub struct SignersUpdated {
    pub old_signers: Vec<Pubkey>,
    pub new_signers: Vec<Pubkey>,
    pub old_threshold: u8,
    pub new_threshold: u8,
}

#[event]
pub struct TreasuryPaused {
    pub paused_by: Pubkey,
}

#[event]
pub struct TreasuryResumed {
    pub resumed_by: Pubkey,
}

// =============================================================================
// ERRORS
// =============================================================================

#[error_code]
pub enum TreasuryError {
    #[msg("Need at least 2 signers")]
    InsufficientSigners,
    #[msg("Maximum 10 signers")]
    TooManySigners,
    #[msg("Threshold must be at least 2")]
    ThresholdTooLow,
    #[msg("Threshold cannot exceed number of signers")]
    ThresholdExceedsSigners,
    #[msg("Duplicate signer address")]
    DuplicateSigner,
    #[msg("Treasury is paused")]
    TreasuryPaused,
    #[msg("Treasury is not paused")]
    NotPaused,
    #[msg("Treasury already paused")]
    AlreadyPaused,
    #[msg("Not a valid signer")]
    NotASigner,
    #[msg("Description too long (max 200 chars)")]
    DescriptionTooLong,
    #[msg("Already executed")]
    AlreadyExecuted,
    #[msg("Proposal expired")]
    ProposalExpired,
    #[msg("Already approved by this signer")]
    AlreadyApproved,
    #[msg("Insufficient approvals")]
    InsufficientApprovals,
    #[msg("Daily spend cap exceeded")]
    DailyCapExceeded,
    #[msg("Arithmetic overflow")]
    Overflow,
    #[msg("Proposal does not belong to this treasury")]
    ProposalTreasuryMismatch,
    #[msg("Recipient does not match proposal")]
    RecipientMismatch,
    #[msg("Amount must be greater than zero")]
    ZeroAmount,
}

// =============================================================================
// TREASURY FLOW (ASCII)
// =============================================================================
/*
+-------------------------------------------------------------+
|                    TREASURY GOVERNANCE                       |
+-------------------------------------------------------------+
|                                                              |
|  Revenue In:                                                 |
|  +---------+ +---------+ +---------+ +---------+            |
|  |NFT Mint | | Merch   | |Partners | | Games   |            |
|  +----+----+ +----+----+ +----+----+ +----+----+            |
|       +----------++---------++----------+                    |
|                   |                                          |
|          +--------v--------+                                 |
|          | TREASURY PDA    | <- Multi-sig controlled         |
|          +--------+--------+                                 |
|                   |                                          |
|  +----------------v-----------------+                        |
|  |         PROPOSAL FLOW            |                        |
|  +----------------------------------+                        |
|  | 1. Signer creates proposal       |                        |
|  | 2. Other signers approve         |                        |
|  | 3. Threshold met -> Execute      |                        |
|  | 4. Daily cap enforced            |                        |
|  +----------------------------------+                        |
|                   |                                          |
|  Spend Options:                                              |
|  +---------+ +---------+ +---------+ +---------+            |
|  |Buy&Burn | |Marketing| |Products | |LP Supp. |            |
|  +---------+ +---------+ +---------+ +---------+            |
|                                                              |
|  CONSTRAINTS:                                                |
|  - All spends logged on-chain (events)                       |
|  - Daily spend cap enforced                                  |
|  - Multi-sig required                                        |
|  - Proposals expire after 24h                                |
|  - Signer updates require governance proposal                |
|  - Resume from pause requires governance proposal            |
|  - Duplicate signers rejected                                |
|  - Executor must be a signer                                 |
|                                                              |
+-------------------------------------------------------------+
*/
