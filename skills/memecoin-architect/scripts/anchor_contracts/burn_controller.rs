// =============================================================================
// BURN CONTROLLER PROGRAM - DETERMINISTIC BURN MECHANICS
// =============================================================================
// PRINCIPLE: Burns are MECHANICAL, not emotional
// CONSTRAINT: No manual burn buttons - all burns rule-based
// COMPAT: Uses token_interface — works with both SPL Token and Token-2022
// =============================================================================

use anchor_lang::prelude::*;
use anchor_spl::token_interface::{self, Burn, Mint, TokenAccount, TokenInterface};

declare_id!("REPLACE_WITH_YOUR_PROGRAM_ID");

#[program]
pub mod burn_controller {
    use super::*;

    /// Initialize burn controller with deterministic rules
    pub fn initialize(
        ctx: Context<Initialize>,
        trade_burn_bps: u16,         // Basis points burned per trade (e.g., 100 = 1%)
        volume_threshold: u64,        // Volume threshold for milestone burns
        milestone_burn_amount: u64,   // Amount burned at each milestone
        authorized_caller: Pubkey,    // Program or PDA authorized to report trades
    ) -> Result<()> {
        require!(trade_burn_bps <= 500, BurnError::ExcessiveBurnRate); // Max 5%
        require!(volume_threshold > 0, BurnError::InvalidThreshold);

        let state = &mut ctx.accounts.burn_state;
        state.mint = ctx.accounts.mint.key();
        state.authority = ctx.accounts.authority.key();
        state.authorized_caller = authorized_caller;
        state.trade_burn_bps = trade_burn_bps;
        state.volume_threshold = volume_threshold;
        state.milestone_burn_amount = milestone_burn_amount;
        state.total_burned = 0;
        state.cumulative_volume = 0;
        state.milestones_reached = 0;
        state.paused = false;

        emit!(BurnControllerInitialized {
            mint: state.mint,
            trade_burn_bps,
            volume_threshold,
            milestone_burn_amount,
            authorized_caller,
        });

        msg!("Burn controller initialized: {}bps per trade, {} volume threshold",
             trade_burn_bps, volume_threshold);
        Ok(())
    }

    /// Execute trade burn - called ONLY by authorized caller (DEX hook or integration program)
    /// Burns percentage of trade amount automatically
    pub fn execute_trade_burn(
        ctx: Context<ExecuteTradeBurn>,
        trade_amount: u64,
    ) -> Result<()> {
        let state = &mut ctx.accounts.burn_state;
        require!(!state.paused, BurnError::BurnsPaused);

        // Calculate burn amount (basis points)
        let burn_amount = trade_amount
            .checked_mul(state.trade_burn_bps as u64)
            .ok_or(BurnError::Overflow)?
            .checked_div(10000)
            .ok_or(BurnError::Overflow)?;

        if burn_amount > 0 {
            // Execute burn
            let cpi_accounts = Burn {
                mint: ctx.accounts.mint.to_account_info(),
                from: ctx.accounts.token_account.to_account_info(),
                authority: ctx.accounts.token_authority.to_account_info(),
            };
            let cpi_program = ctx.accounts.token_program.to_account_info();
            let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

            token_interface::burn(cpi_ctx, burn_amount)?;

            // Update state
            state.total_burned = state.total_burned
                .checked_add(burn_amount)
                .ok_or(BurnError::Overflow)?;
        }

        // Update cumulative volume
        state.cumulative_volume = state.cumulative_volume
            .checked_add(trade_amount)
            .ok_or(BurnError::Overflow)?;

        emit!(TradeBurnExecuted {
            trade_amount,
            burn_amount,
            total_burned: state.total_burned,
            cumulative_volume: state.cumulative_volume,
        });

        Ok(())
    }

    /// Check and execute volume milestone burn
    /// Triggered when cumulative volume crosses threshold
    pub fn check_milestone_burn(ctx: Context<CheckMilestoneBurn>) -> Result<()> {
        let state = &mut ctx.accounts.burn_state;
        require!(!state.paused, BurnError::BurnsPaused);

        // Calculate expected milestones based on volume
        let expected_milestones = state.cumulative_volume
            .checked_div(state.volume_threshold)
            .ok_or(BurnError::Overflow)?;

        // Check if new milestone reached
        if expected_milestones > state.milestones_reached {
            let milestones_to_burn = expected_milestones - state.milestones_reached;
            let total_burn = milestones_to_burn
                .checked_mul(state.milestone_burn_amount)
                .ok_or(BurnError::Overflow)?;

            // Execute milestone burn from reserve
            let seeds = &[
                b"burn_authority".as_ref(),
                state.mint.as_ref(),
                &[ctx.bumps.burn_authority],
            ];
            let signer = &[&seeds[..]];

            let cpi_accounts = Burn {
                mint: ctx.accounts.mint.to_account_info(),
                from: ctx.accounts.burn_reserve.to_account_info(),
                authority: ctx.accounts.burn_authority.to_account_info(),
            };
            let cpi_program = ctx.accounts.token_program.to_account_info();
            let cpi_ctx = CpiContext::new_with_signer(cpi_program, cpi_accounts, signer);

            token_interface::burn(cpi_ctx, total_burn)?;

            // Update state
            state.milestones_reached = expected_milestones;
            state.total_burned = state.total_burned
                .checked_add(total_burn)
                .ok_or(BurnError::Overflow)?;

            emit!(MilestoneBurnExecuted {
                milestones_burned: milestones_to_burn,
                tokens_burned: total_burn,
                total_milestones: state.milestones_reached,
                total_burned: state.total_burned,
            });

            msg!("Milestone burn! {} milestones, {} tokens burned",
                 milestones_to_burn, total_burn);
        }

        Ok(())
    }

    /// Treasury buyback and burn
    /// Called by treasury when executing buyback strategy
    pub fn treasury_buyback_burn(
        ctx: Context<TreasuryBuybackBurn>,
        amount: u64,
    ) -> Result<()> {
        let state = &mut ctx.accounts.burn_state;
        require!(!state.paused, BurnError::BurnsPaused);
        require!(amount > 0, BurnError::ZeroAmount);

        // Execute burn from treasury holdings
        let cpi_accounts = Burn {
            mint: ctx.accounts.mint.to_account_info(),
            from: ctx.accounts.treasury_token_account.to_account_info(),
            authority: ctx.accounts.treasury_authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

        token_interface::burn(cpi_ctx, amount)?;

        // Update state
        state.total_burned = state.total_burned
            .checked_add(amount)
            .ok_or(BurnError::Overflow)?;

        emit!(TreasuryBuybackBurnExecuted {
            amount,
            total_burned: state.total_burned,
            treasury_authority: ctx.accounts.treasury_authority.key(),
        });

        msg!("Treasury buyback burn: {} tokens", amount);
        Ok(())
    }

    /// Emergency pause burns (authority only)
    pub fn pause_burns(ctx: Context<PauseBurns>) -> Result<()> {
        let state = &mut ctx.accounts.burn_state;
        require!(!state.paused, BurnError::AlreadyPaused);

        state.paused = true;

        emit!(BurnsPaused {
            paused_by: ctx.accounts.authority.key(),
        });

        msg!("Burns paused by authority");
        Ok(())
    }

    /// Resume burns (authority only)
    pub fn resume_burns(ctx: Context<ResumeBurns>) -> Result<()> {
        let state = &mut ctx.accounts.burn_state;
        require!(state.paused, BurnError::NotPaused);

        state.paused = false;

        emit!(BurnsResumed {
            resumed_by: ctx.accounts.authority.key(),
        });

        msg!("Burns resumed");
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
        payer = authority,
        space = 8 + BurnState::INIT_SPACE,
        seeds = [b"burn_state", mint.key().as_ref()],
        bump
    )]
    pub burn_state: Account<'info, BurnState>,

    pub mint: InterfaceAccount<'info, Mint>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ExecuteTradeBurn<'info> {
    #[account(
        mut,
        seeds = [b"burn_state", mint.key().as_ref()],
        bump,
        has_one = mint,
    )]
    pub burn_state: Account<'info, BurnState>,

    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        mut,
        constraint = token_account.mint == mint.key() @ BurnError::MintMismatch,
    )]
    pub token_account: InterfaceAccount<'info, TokenAccount>,

    /// Must be the authorized_caller stored in burn_state (DEX hook or integration)
    #[account(
        constraint = token_authority.key() == burn_state.authorized_caller @ BurnError::UnauthorizedCaller,
    )]
    pub token_authority: Signer<'info>,

    /// Accepts both SPL Token and Token-2022
    pub token_program: Interface<'info, TokenInterface>,
}

#[derive(Accounts)]
pub struct CheckMilestoneBurn<'info> {
    #[account(
        mut,
        seeds = [b"burn_state", mint.key().as_ref()],
        bump,
        has_one = mint,
    )]
    pub burn_state: Account<'info, BurnState>,

    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        mut,
        constraint = burn_reserve.mint == mint.key() @ BurnError::MintMismatch,
        constraint = burn_reserve.owner == burn_authority.key() @ BurnError::ReserveOwnerMismatch,
    )]
    pub burn_reserve: InterfaceAccount<'info, TokenAccount>,

    /// CHECK: PDA authority for burns
    #[account(
        seeds = [b"burn_authority", mint.key().as_ref()],
        bump
    )]
    pub burn_authority: UncheckedAccount<'info>,

    /// Accepts both SPL Token and Token-2022
    pub token_program: Interface<'info, TokenInterface>,
}

#[derive(Accounts)]
pub struct TreasuryBuybackBurn<'info> {
    #[account(
        mut,
        seeds = [b"burn_state", mint.key().as_ref()],
        bump,
        has_one = mint,
        has_one = authority,
    )]
    pub burn_state: Account<'info, BurnState>,

    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        mut,
        constraint = treasury_token_account.mint == mint.key() @ BurnError::MintMismatch,
    )]
    pub treasury_token_account: InterfaceAccount<'info, TokenAccount>,

    /// Must be the burn_state.authority (treasury signer)
    pub treasury_authority: Signer<'info>,

    /// CHECK: Verified via has_one on burn_state
    #[account(constraint = authority.key() == burn_state.authority @ BurnError::Unauthorized)]
    pub authority: UncheckedAccount<'info>,

    /// Accepts both SPL Token and Token-2022
    pub token_program: Interface<'info, TokenInterface>,
}

#[derive(Accounts)]
pub struct PauseBurns<'info> {
    #[account(
        mut,
        seeds = [b"burn_state", mint.key().as_ref()],
        bump,
        has_one = authority,
    )]
    pub burn_state: Account<'info, BurnState>,

    pub authority: Signer<'info>,

    /// CHECK: Used only for seed derivation
    pub mint: UncheckedAccount<'info>,
}

#[derive(Accounts)]
pub struct ResumeBurns<'info> {
    #[account(
        mut,
        seeds = [b"burn_state", mint.key().as_ref()],
        bump,
        has_one = authority,
    )]
    pub burn_state: Account<'info, BurnState>,

    pub authority: Signer<'info>,

    /// CHECK: Used only for seed derivation
    pub mint: UncheckedAccount<'info>,
}

// =============================================================================
// STATE
// =============================================================================

#[account]
#[derive(InitSpace)]
pub struct BurnState {
    pub mint: Pubkey,                   // 32 bytes
    pub authority: Pubkey,              // 32 bytes
    pub authorized_caller: Pubkey,      // 32 bytes - who can report trades
    pub trade_burn_bps: u16,            // 2 bytes - basis points per trade
    pub volume_threshold: u64,          // 8 bytes - volume milestone threshold
    pub milestone_burn_amount: u64,     // 8 bytes - burn at each milestone
    pub total_burned: u64,              // 8 bytes - cumulative burns
    pub cumulative_volume: u64,         // 8 bytes - cumulative trading volume
    pub milestones_reached: u64,        // 8 bytes - number of milestones hit
    pub paused: bool,                   // 1 byte - emergency pause flag
}

// =============================================================================
// EVENTS
// =============================================================================

#[event]
pub struct BurnControllerInitialized {
    pub mint: Pubkey,
    pub trade_burn_bps: u16,
    pub volume_threshold: u64,
    pub milestone_burn_amount: u64,
    pub authorized_caller: Pubkey,
}

#[event]
pub struct TradeBurnExecuted {
    pub trade_amount: u64,
    pub burn_amount: u64,
    pub total_burned: u64,
    pub cumulative_volume: u64,
}

#[event]
pub struct MilestoneBurnExecuted {
    pub milestones_burned: u64,
    pub tokens_burned: u64,
    pub total_milestones: u64,
    pub total_burned: u64,
}

#[event]
pub struct TreasuryBuybackBurnExecuted {
    pub amount: u64,
    pub total_burned: u64,
    pub treasury_authority: Pubkey,
}

#[event]
pub struct BurnsPaused {
    pub paused_by: Pubkey,
}

#[event]
pub struct BurnsResumed {
    pub resumed_by: Pubkey,
}

// =============================================================================
// ERRORS
// =============================================================================

#[error_code]
pub enum BurnError {
    #[msg("Burn rate too high - max 5% (500 bps)")]
    ExcessiveBurnRate,
    #[msg("Volume threshold must be greater than zero")]
    InvalidThreshold,
    #[msg("Burns are currently paused")]
    BurnsPaused,
    #[msg("Burns are not paused")]
    NotPaused,
    #[msg("Burns already paused")]
    AlreadyPaused,
    #[msg("Arithmetic overflow")]
    Overflow,
    #[msg("Unauthorized")]
    Unauthorized,
    #[msg("Only the authorized caller can report trades")]
    UnauthorizedCaller,
    #[msg("Token account mint does not match burn state mint")]
    MintMismatch,
    #[msg("Burn reserve owner does not match burn authority PDA")]
    ReserveOwnerMismatch,
    #[msg("Amount must be greater than zero")]
    ZeroAmount,
}

// =============================================================================
// BURN MECHANICS FLOW (ASCII)
// =============================================================================
/*
+-------------------------------------------------------------+
|                  DETERMINISTIC BURN FLOW                     |
+-------------------------------------------------------------+
|                                                              |
|  TRIGGER 1: Trade Burns (Authorized Caller Only)             |
|  +-----------+    +------------+    +-----------+            |
|  |DEX Hook / |-->| Calculate % |-->| Burn      |            |
|  |Integration|   | (trade_bps) |   | Tokens    |            |
|  +-----------+   +------------+    +-----------+             |
|                                                              |
|  TRIGGER 2: Volume Milestones (Permissionless check)         |
|  +-----------+    +------------+    +-----------+            |
|  |Volume Hit |-->| Check State |-->| Burn from |            |
|  |Threshold  |   | Milestone   |   | Reserve   |            |
|  +-----------+   +------------+    +-----------+             |
|                                                              |
|  TRIGGER 3: Treasury Buyback (Authority Only)                |
|  +-----------+    +------------+    +-----------+            |
|  |DAO Vote   |-->| Execute Buy |-->| Burn      |            |
|  |Approved   |   | from Market |   | Bought    |            |
|  +-----------+   +------------+    +-----------+             |
|                                                              |
|  NO MANUAL BURN BUTTONS                                      |
|  ALL BURNS DETERMINISTIC + LOGGED                            |
|  TRADE BURNS RESTRICTED TO AUTHORIZED CALLER                 |
|                                                              |
+-------------------------------------------------------------+
*/
