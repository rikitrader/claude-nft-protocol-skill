// =============================================================================
// TOKEN MINT PROGRAM - FIXED SUPPLY, ONE-TIME MINT
// =============================================================================
// SECURITY: No mint authority retained after initialization
// CONSTRAINT: Total supply is immutable post-deploy
// COMPAT: Uses token_interface — works with both SPL Token and Token-2022
// =============================================================================

use anchor_lang::prelude::*;
use anchor_spl::token_interface::{self, Mint, MintTo, TokenAccount, TokenInterface};

declare_id!("REPLACE_WITH_YOUR_PROGRAM_ID");

#[program]
pub mod token_mint {
    use super::*;

    /// Initialize the memecoin with a fixed total supply
    /// This can only be called ONCE - mint authority is revoked after
    pub fn initialize(
        ctx: Context<Initialize>,
        total_supply: u64,
        decimals: u8,
    ) -> Result<()> {
        require!(decimals >= 6 && decimals <= 9, MemeError::InvalidDecimals);
        require!(total_supply > 0, MemeError::ZeroSupply);

        let state = &mut ctx.accounts.mint_state;
        state.total_supply = total_supply;
        state.decimals = decimals;
        state.mint = ctx.accounts.mint.key();
        state.authority = ctx.accounts.authority.key();
        state.initialized = true;
        state.minted = false;

        emit!(TokenInitialized {
            mint: state.mint,
            total_supply,
            decimals,
            authority: state.authority,
        });

        msg!("Memecoin initialized: {} total supply, {} decimals", total_supply, decimals);
        Ok(())
    }

    /// Mint the entire fixed supply to the treasury AND atomically revoke both authorities.
    /// This can only be called ONCE. After this call, no new tokens can ever be minted
    /// and no accounts can ever be frozen.
    pub fn mint_and_revoke(ctx: Context<MintAndRevoke>) -> Result<()> {
        let state = &mut ctx.accounts.mint_state;

        require!(state.initialized, MemeError::NotInitialized);
        require!(!state.minted, MemeError::AlreadyMinted);

        // Mint entire supply to treasury
        let cpi_accounts = MintTo {
            mint: ctx.accounts.mint.to_account_info(),
            to: ctx.accounts.treasury_token_account.to_account_info(),
            authority: ctx.accounts.authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);

        token_interface::mint_to(cpi_ctx, state.total_supply)?;

        // Mark as minted BEFORE revoking (checks-effects-interactions)
        state.minted = true;

        // Atomically revoke MINT authority
        let cpi_accounts_mint_auth = token_interface::SetAuthority {
            current_authority: ctx.accounts.authority.to_account_info(),
            account_or_mint: ctx.accounts.mint.to_account_info(),
        };
        let cpi_ctx_mint = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts_mint_auth,
        );
        token_interface::set_authority(
            cpi_ctx_mint,
            token_interface::spl_token_2022::instruction::AuthorityType::MintTokens,
            None,
        )?;

        // Atomically revoke FREEZE authority
        let cpi_accounts_freeze_auth = token_interface::SetAuthority {
            current_authority: ctx.accounts.authority.to_account_info(),
            account_or_mint: ctx.accounts.mint.to_account_info(),
        };
        let cpi_ctx_freeze = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts_freeze_auth,
        );
        token_interface::set_authority(
            cpi_ctx_freeze,
            token_interface::spl_token_2022::instruction::AuthorityType::FreezeAccount,
            None,
        )?;

        emit!(SupplyMintedAndLocked {
            mint: state.mint,
            total_supply: state.total_supply,
            treasury: ctx.accounts.treasury_token_account.key(),
            mint_authority_revoked: true,
            freeze_authority_revoked: true,
        });

        msg!("Fixed supply minted: {} tokens", state.total_supply);
        msg!("MINT AUTHORITY PERMANENTLY REVOKED");
        msg!("FREEZE AUTHORITY PERMANENTLY REVOKED");

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
        space = 8 + MintState::INIT_SPACE,
        seeds = [b"mint_state", mint.key().as_ref()],
        bump
    )]
    pub mint_state: Account<'info, MintState>,

    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
    /// Accepts both SPL Token and Token-2022
    pub token_program: Interface<'info, TokenInterface>,
}

#[derive(Accounts)]
pub struct MintAndRevoke<'info> {
    #[account(
        mut,
        seeds = [b"mint_state", mint.key().as_ref()],
        bump,
        has_one = mint,
        has_one = authority,
    )]
    pub mint_state: Account<'info, MintState>,

    #[account(mut)]
    pub mint: InterfaceAccount<'info, Mint>,

    #[account(
        mut,
        constraint = treasury_token_account.mint == mint.key() @ MemeError::MintMismatch,
        constraint = treasury_token_account.owner == treasury_owner.key() @ MemeError::OwnerMismatch,
    )]
    pub treasury_token_account: InterfaceAccount<'info, TokenAccount>,

    /// CHECK: Treasury PDA or known wallet that owns the token account
    pub treasury_owner: UncheckedAccount<'info>,

    #[account(mut)]
    pub authority: Signer<'info>,

    /// Accepts both SPL Token and Token-2022
    pub token_program: Interface<'info, TokenInterface>,
}

// =============================================================================
// STATE
// =============================================================================

#[account]
#[derive(InitSpace)]
pub struct MintState {
    pub total_supply: u64,      // 8 bytes
    pub decimals: u8,           // 1 byte
    pub mint: Pubkey,           // 32 bytes
    pub authority: Pubkey,      // 32 bytes
    pub initialized: bool,      // 1 byte
    pub minted: bool,           // 1 byte - TRUE means no more minting possible
}

// =============================================================================
// EVENTS
// =============================================================================

#[event]
pub struct TokenInitialized {
    pub mint: Pubkey,
    pub total_supply: u64,
    pub decimals: u8,
    pub authority: Pubkey,
}

#[event]
pub struct SupplyMintedAndLocked {
    pub mint: Pubkey,
    pub total_supply: u64,
    pub treasury: Pubkey,
    pub mint_authority_revoked: bool,
    pub freeze_authority_revoked: bool,
}

// =============================================================================
// ERRORS
// =============================================================================

#[error_code]
pub enum MemeError {
    #[msg("Invalid decimals - must be between 6 and 9")]
    InvalidDecimals,
    #[msg("Total supply must be greater than zero")]
    ZeroSupply,
    #[msg("Mint state not initialized")]
    NotInitialized,
    #[msg("Tokens already minted - no further minting allowed")]
    AlreadyMinted,
    #[msg("Token account mint does not match expected mint")]
    MintMismatch,
    #[msg("Token account owner does not match expected owner")]
    OwnerMismatch,
}

// =============================================================================
// DEPLOYMENT FLOW (ASCII)
// =============================================================================
/*
+-------------------------------------------------------------+
|                    TOKEN MINT FLOW                           |
+-------------------------------------------------------------+
|                                                              |
|  1. Deploy Program                                           |
|         |                                                    |
|  2. Create SPL Token Mint                                    |
|         |                                                    |
|  3. Initialize (set total_supply, decimals)                  |
|         |                                                    |
|  4. Create Treasury Token Account                            |
|         |                                                    |
|  5. mint_and_revoke (ATOMIC: mint + revoke mint + freeze)    |
|         |                                                    |
|  NO MORE TOKENS CAN EVER BE MINTED                          |
|  NO ACCOUNTS CAN EVER BE FROZEN                             |
|                                                              |
+-------------------------------------------------------------+

SECURITY INVARIANTS:
- minted = true -> No mint_and_revoke calls possible
- Mint authority = None -> SPL token level protection
- Freeze authority = None -> No account freezing possible
- Both layers must be satisfied for security
- treasury_token_account.mint MUST match mint (enforced)
- treasury_token_account.owner MUST match treasury_owner (enforced)
*/
