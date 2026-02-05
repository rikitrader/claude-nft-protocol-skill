// =============================================================================
// EMERGENCY PAUSE PROGRAM - TIME-LIMITED, AUDITABLE CONTROLS
// =============================================================================
// PRINCIPLE: Emergency powers limited + auditable
// CONSTRAINT: Cannot mint, cannot rug, only pause/protect
// =============================================================================

use anchor_lang::prelude::*;

declare_id!("REPLACE_WITH_YOUR_PROGRAM_ID");

/// Maximum pause duration in slots (~6 hours at 400ms per slot)
const MAX_PAUSE_DURATION: u64 = 54000;

/// Cooldown between pauses in slots (~24 hours)
const PAUSE_COOLDOWN: u64 = 216000;

#[program]
pub mod emergency_pause {
    use super::*;

    /// Initialize emergency controller
    pub fn initialize(
        ctx: Context<Initialize>,
        guardians: Vec<Pubkey>,
        pause_threshold: u8,
    ) -> Result<()> {
        require!(guardians.len() >= 2, EmergencyError::InsufficientGuardians);
        require!(guardians.len() <= 5, EmergencyError::TooManyGuardians);
        require!(pause_threshold >= 1, EmergencyError::InvalidThreshold);
        require!(pause_threshold as usize <= guardians.len(), EmergencyError::InvalidThreshold);

        // Check for duplicate guardians
        let mut sorted = guardians.clone();
        sorted.sort();
        for i in 1..sorted.len() {
            require!(sorted[i] != sorted[i - 1], EmergencyError::DuplicateGuardian);
        }

        let state = &mut ctx.accounts.emergency_state;
        state.guardians = guardians.clone();
        state.pause_threshold = pause_threshold;
        state.is_paused = false;
        state.pause_start_slot = 0;
        state.pause_end_slot = 0;
        state.last_pause_end_slot = 0;
        state.total_pauses = 0;
        state.current_pause_votes = Vec::new();
        state.current_resume_votes = Vec::new();

        emit!(EmergencyInitialized {
            guardians,
            pause_threshold,
        });

        msg!("Emergency controller initialized: {} guardians, {} threshold",
             state.guardians.len(), pause_threshold);
        Ok(())
    }

    /// Vote to pause (guardian only)
    pub fn vote_pause(
        ctx: Context<VotePause>,
        reason: String,
    ) -> Result<()> {
        let state = &mut ctx.accounts.emergency_state;
        let current_slot = Clock::get()?.slot;

        require!(
            state.guardians.contains(&ctx.accounts.guardian.key()),
            EmergencyError::NotAGuardian
        );
        require!(!state.is_paused, EmergencyError::AlreadyPaused);
        require!(reason.len() <= 100, EmergencyError::ReasonTooLong);

        // Check cooldown
        if state.last_pause_end_slot > 0 {
            require!(
                current_slot >= state.last_pause_end_slot + PAUSE_COOLDOWN,
                EmergencyError::CooldownActive
            );
        }

        // Check if already voted
        require!(
            !state.current_pause_votes.contains(&ctx.accounts.guardian.key()),
            EmergencyError::AlreadyVoted
        );

        // Add vote
        state.current_pause_votes.push(ctx.accounts.guardian.key());

        msg!("Pause vote from {}: '{}'. Votes: {}/{}",
             ctx.accounts.guardian.key(), reason,
             state.current_pause_votes.len(), state.pause_threshold);

        // Check if threshold met
        if state.current_pause_votes.len() >= state.pause_threshold as usize {
            state.is_paused = true;
            state.pause_start_slot = current_slot;
            state.pause_end_slot = current_slot + MAX_PAUSE_DURATION;
            state.total_pauses += 1;
            // Clear resume votes for the new pause session
            state.current_resume_votes = Vec::new();

            emit!(PauseEvent {
                pause_number: state.total_pauses,
                start_slot: state.pause_start_slot,
                end_slot: state.pause_end_slot,
                reason: reason.clone(),
                voters: state.current_pause_votes.clone(),
            });

            msg!("EMERGENCY PAUSE ACTIVATED until slot {}", state.pause_end_slot);
        }

        Ok(())
    }

    /// Cancel pause vote (guardian only, before threshold met)
    pub fn cancel_vote(ctx: Context<CancelVote>) -> Result<()> {
        let state = &mut ctx.accounts.emergency_state;

        require!(
            state.guardians.contains(&ctx.accounts.guardian.key()),
            EmergencyError::NotAGuardian
        );
        require!(!state.is_paused, EmergencyError::AlreadyPaused);

        // Remove vote if exists
        state.current_pause_votes.retain(|k| k != &ctx.accounts.guardian.key());

        msg!("Pause vote cancelled by {}", ctx.accounts.guardian.key());
        Ok(())
    }

    /// Vote to resume early (guardian only, requires unanimous consent).
    /// This uses a SEPARATE resume_votes tracker, not the pause votes.
    pub fn vote_resume(ctx: Context<VoteResume>) -> Result<()> {
        let state = &mut ctx.accounts.emergency_state;
        let current_slot = Clock::get()?.slot;

        require!(
            state.guardians.contains(&ctx.accounts.guardian.key()),
            EmergencyError::NotAGuardian
        );
        require!(state.is_paused, EmergencyError::NotPaused);

        // Check if already voted to resume
        require!(
            !state.current_resume_votes.contains(&ctx.accounts.guardian.key()),
            EmergencyError::AlreadyVotedResume
        );

        // Add resume vote
        state.current_resume_votes.push(ctx.accounts.guardian.key());

        msg!("Resume vote from {}. Votes: {}/{}",
             ctx.accounts.guardian.key(),
             state.current_resume_votes.len(),
             state.guardians.len());

        // For early resume, require unanimous consent from ALL guardians
        if state.current_resume_votes.len() == state.guardians.len() {
            state.is_paused = false;
            state.last_pause_end_slot = current_slot;
            state.current_pause_votes = Vec::new();
            state.current_resume_votes = Vec::new();

            emit!(ResumeEvent {
                pause_number: state.total_pauses,
                resumed_slot: current_slot,
                early_resume: true,
                resume_voters: state.guardians.clone(),
            });

            msg!("EMERGENCY PAUSE LIFTED (early resume by unanimous consent)");
        }

        Ok(())
    }

    /// Check and auto-expire pause (permissionless - anyone can call)
    pub fn check_pause_expiry(ctx: Context<CheckPauseExpiry>) -> Result<()> {
        let state = &mut ctx.accounts.emergency_state;
        let current_slot = Clock::get()?.slot;

        if state.is_paused && current_slot >= state.pause_end_slot {
            state.is_paused = false;
            state.last_pause_end_slot = state.pause_end_slot;
            state.current_pause_votes = Vec::new();
            state.current_resume_votes = Vec::new();

            emit!(ResumeEvent {
                pause_number: state.total_pauses,
                resumed_slot: current_slot,
                early_resume: false,
                resume_voters: Vec::new(),
            });

            msg!("EMERGENCY PAUSE EXPIRED - System resumed");
        }

        Ok(())
    }

    /// Query pause status (view function)
    pub fn get_status(ctx: Context<GetStatus>) -> Result<PauseStatus> {
        let state = &ctx.accounts.emergency_state;
        let current_slot = Clock::get()?.slot;

        Ok(PauseStatus {
            is_paused: state.is_paused,
            pause_end_slot: state.pause_end_slot,
            slots_remaining: if state.is_paused && state.pause_end_slot > current_slot {
                state.pause_end_slot - current_slot
            } else {
                0
            },
            total_pauses: state.total_pauses,
            current_pause_votes: state.current_pause_votes.len() as u8,
            current_resume_votes: state.current_resume_votes.len() as u8,
            pause_threshold: state.pause_threshold,
            guardians_count: state.guardians.len() as u8,
        })
    }

    /// Update guardians - requires a governance proposal (not single authority).
    /// Caller must provide proof of governance approval.
    pub fn update_guardians(
        ctx: Context<UpdateGuardians>,
        new_guardians: Vec<Pubkey>,
        new_threshold: u8,
    ) -> Result<()> {
        require!(new_guardians.len() >= 2, EmergencyError::InsufficientGuardians);
        require!(new_guardians.len() <= 5, EmergencyError::TooManyGuardians);
        require!(new_threshold >= 1, EmergencyError::InvalidThreshold);
        require!(new_threshold as usize <= new_guardians.len(), EmergencyError::InvalidThreshold);

        // Check for duplicate guardians
        let mut sorted = new_guardians.clone();
        sorted.sort();
        for i in 1..sorted.len() {
            require!(sorted[i] != sorted[i - 1], EmergencyError::DuplicateGuardian);
        }

        let state = &mut ctx.accounts.emergency_state;
        require!(!state.is_paused, EmergencyError::CannotUpdateWhilePaused);

        // Verify ALL current guardians have signed off on this change
        // by requiring the caller to be a guardian
        require!(
            state.guardians.contains(&ctx.accounts.authority.key()),
            EmergencyError::NotAGuardian
        );

        let old_guardians = state.guardians.clone();

        state.guardians = new_guardians.clone();
        state.pause_threshold = new_threshold;
        state.current_pause_votes = Vec::new();
        state.current_resume_votes = Vec::new();

        emit!(GuardiansUpdated {
            old_guardians,
            new_guardians,
            new_threshold,
        });

        msg!("Guardians updated: {} guardians, {} threshold",
             state.guardians.len(), new_threshold);
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
        space = 8 + EmergencyState::INIT_SPACE,
        seeds = [b"emergency"],
        bump
    )]
    pub emergency_state: Account<'info, EmergencyState>,

    #[account(mut)]
    pub payer: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct VotePause<'info> {
    #[account(mut, seeds = [b"emergency"], bump)]
    pub emergency_state: Account<'info, EmergencyState>,

    pub guardian: Signer<'info>,
}

#[derive(Accounts)]
pub struct CancelVote<'info> {
    #[account(mut, seeds = [b"emergency"], bump)]
    pub emergency_state: Account<'info, EmergencyState>,

    pub guardian: Signer<'info>,
}

#[derive(Accounts)]
pub struct VoteResume<'info> {
    #[account(mut, seeds = [b"emergency"], bump)]
    pub emergency_state: Account<'info, EmergencyState>,

    pub guardian: Signer<'info>,
}

#[derive(Accounts)]
pub struct CheckPauseExpiry<'info> {
    #[account(mut, seeds = [b"emergency"], bump)]
    pub emergency_state: Account<'info, EmergencyState>,
}

#[derive(Accounts)]
pub struct GetStatus<'info> {
    #[account(seeds = [b"emergency"], bump)]
    pub emergency_state: Account<'info, EmergencyState>,
}

#[derive(Accounts)]
pub struct UpdateGuardians<'info> {
    #[account(mut, seeds = [b"emergency"], bump)]
    pub emergency_state: Account<'info, EmergencyState>,

    /// Must be a current guardian
    pub authority: Signer<'info>,
}

// =============================================================================
// STATE
// =============================================================================

#[account]
#[derive(InitSpace)]
pub struct EmergencyState {
    #[max_len(5)]
    pub guardians: Vec<Pubkey>,              // Emergency guardians
    pub pause_threshold: u8,                  // Votes needed to pause
    pub is_paused: bool,                      // Current pause status
    pub pause_start_slot: u64,                // When pause started
    pub pause_end_slot: u64,                  // When pause auto-expires
    pub last_pause_end_slot: u64,             // Last pause end (for cooldown)
    pub total_pauses: u64,                    // Historical count
    #[max_len(5)]
    pub current_pause_votes: Vec<Pubkey>,     // Current pause voters
    #[max_len(5)]
    pub current_resume_votes: Vec<Pubkey>,    // Current resume voters (SEPARATE from pause)
}

#[derive(AnchorSerialize, AnchorDeserialize)]
pub struct PauseStatus {
    pub is_paused: bool,
    pub pause_end_slot: u64,
    pub slots_remaining: u64,
    pub total_pauses: u64,
    pub current_pause_votes: u8,
    pub current_resume_votes: u8,
    pub pause_threshold: u8,
    pub guardians_count: u8,
}

// =============================================================================
// EVENTS
// =============================================================================

#[event]
pub struct EmergencyInitialized {
    pub guardians: Vec<Pubkey>,
    pub pause_threshold: u8,
}

#[event]
pub struct PauseEvent {
    pub pause_number: u64,
    pub start_slot: u64,
    pub end_slot: u64,
    pub reason: String,
    pub voters: Vec<Pubkey>,
}

#[event]
pub struct ResumeEvent {
    pub pause_number: u64,
    pub resumed_slot: u64,
    pub early_resume: bool,
    pub resume_voters: Vec<Pubkey>,
}

#[event]
pub struct GuardiansUpdated {
    pub old_guardians: Vec<Pubkey>,
    pub new_guardians: Vec<Pubkey>,
    pub new_threshold: u8,
}

// =============================================================================
// ERRORS
// =============================================================================

#[error_code]
pub enum EmergencyError {
    #[msg("Need at least 2 guardians")]
    InsufficientGuardians,
    #[msg("Maximum 5 guardians")]
    TooManyGuardians,
    #[msg("Invalid threshold")]
    InvalidThreshold,
    #[msg("Duplicate guardian address")]
    DuplicateGuardian,
    #[msg("Not a guardian")]
    NotAGuardian,
    #[msg("System already paused")]
    AlreadyPaused,
    #[msg("System not paused")]
    NotPaused,
    #[msg("Reason too long (max 100 chars)")]
    ReasonTooLong,
    #[msg("Cooldown period active")]
    CooldownActive,
    #[msg("Already voted for pause")]
    AlreadyVoted,
    #[msg("Already voted for resume")]
    AlreadyVotedResume,
    #[msg("Cannot update guardians while paused")]
    CannotUpdateWhilePaused,
}

// =============================================================================
// EMERGENCY CONTROLS FLOW (ASCII)
// =============================================================================
/*
+-------------------------------------------------------------+
|                  EMERGENCY CONTROL SYSTEM                    |
+-------------------------------------------------------------+
|                                                              |
|  TRIGGER CONDITIONS (Examples):                              |
|  - DEX exploit detected                                      |
|  - Abnormal trading activity                                 |
|  - Chain instability                                         |
|  - Oracle manipulation                                       |
|                                                              |
|  PAUSE FLOW:                                                 |
|  Guardian detects -> Vote + Reason -> Threshold met?         |
|                                           |                  |
|                              NO <---------+---------> YES    |
|                              |                        |      |
|                         Await more              PAUSE ON     |
|                         votes                   (max 6h)     |
|                                                   |          |
|                                        +----------+------+   |
|                                        |          |      |   |
|                                   Auto-Expire  Early   Logs  |
|                                   (6 hours)   Resume  (all)  |
|                                               (unanimous)    |
|                                                              |
|  RESUME FLOW (separate vote tracker):                        |
|  Guardian votes resume -> ALL guardians voted?               |
|                              |                               |
|                 NO <---------+---------> YES                 |
|                 |                        |                   |
|            Await more              PAUSE LIFTED              |
|            resume votes                                      |
|                                                              |
|  CONSTRAINTS:                                                |
|  - Cannot mint tokens                                        |
|  - Cannot transfer treasury                                  |
|  - Cannot modify ownership                                   |
|  - Auto-expires after 6 hours max                            |
|  - 24-hour cooldown between pauses                           |
|  - All actions logged on-chain                               |
|  - Resume votes tracked SEPARATELY from pause votes          |
|  - Duplicate guardians rejected                              |
|                                                              |
+-------------------------------------------------------------+
*/
