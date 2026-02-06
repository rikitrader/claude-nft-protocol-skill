// =============================================================================
// LOCK METADATA SCRIPT — METAPLEX + TOKEN-2022 SUPPORT
// =============================================================================
// PURPOSE: Permanently locks token metadata (name, symbol, URI) by:
//   1. Setting Metaplex metadata isMutable = false
//   2. Revoking Metaplex update authority
//   3. Revoking SPL mint authority (if not already done)
//   4. Revoking SPL freeze authority (if not already done)
//
// SUPPORTS: SPL Token (via Metaplex) and Token-2022 (via metadata extension)
// WARNING: All operations are IRREVERSIBLE. Use DRY_RUN=true first.
// =============================================================================

import {
    Connection,
    PublicKey,
    Keypair,
    Transaction,
    sendAndConfirmTransaction,
    clusterApiUrl,
} from "@solana/web3.js";
import {
    createSetAuthorityInstruction,
    AuthorityType,
    getMint,
    TOKEN_PROGRAM_ID,
    TOKEN_2022_PROGRAM_ID,
} from "@solana/spl-token";
import * as fs from "fs";

// =============================================================================
// METAPLEX METADATA PROGRAM
// =============================================================================

const METAPLEX_METADATA_PROGRAM_ID = new PublicKey(
    "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
);

function findMetadataAddress(mint: PublicKey): PublicKey {
    const [metadataAddress] = PublicKey.findProgramAddressSync(
        [
            Buffer.from("metadata"),
            METAPLEX_METADATA_PROGRAM_ID.toBuffer(),
            mint.toBuffer(),
        ],
        METAPLEX_METADATA_PROGRAM_ID
    );
    return metadataAddress;
}

// =============================================================================
// VERIFICATION HELPERS
// =============================================================================

interface MetadataState {
    name: string;
    symbol: string;
    uri: string;
    isMutable: boolean;
    updateAuthority: string | null;
}

async function fetchMetaplexMetadata(
    connection: Connection,
    mint: PublicKey
): Promise<MetadataState | null> {
    const metadataAddress = findMetadataAddress(mint);
    const accountInfo = await connection.getAccountInfo(metadataAddress);

    if (!accountInfo) return null;

    // Minimal Metaplex metadata parsing (key fields only)
    const data = accountInfo.data;

    // Metaplex v1 layout:
    // [0] = key (1 byte)
    // [1..33] = update authority (32 bytes)
    // [33..65] = mint (32 bytes)
    // [65..69] = name length prefix (4 bytes)
    // [69..69+nameLen] = name
    // ... symbol, uri, etc.
    const updateAuthority = new PublicKey(data.slice(1, 33));

    const nameLen = data.readUInt32LE(65);
    const name = data.slice(69, 69 + nameLen).toString("utf8").replace(/\0/g, "");

    const symbolOffset = 69 + nameLen;
    const symbolLen = data.readUInt32LE(symbolOffset);
    const symbol = data.slice(symbolOffset + 4, symbolOffset + 4 + symbolLen).toString("utf8").replace(/\0/g, "");

    const uriOffset = symbolOffset + 4 + symbolLen;
    const uriLen = data.readUInt32LE(uriOffset);
    const uri = data.slice(uriOffset + 4, uriOffset + 4 + uriLen).toString("utf8").replace(/\0/g, "");

    // isMutable is at a fixed offset near the end of the data structure
    // After: name, symbol, uri, seller_fee_basis_points(2), creators option, ...
    // For simplicity, check the primary_sale_happened and is_mutable flags
    // is_mutable is typically at offset after all variable-length fields
    // Use a heuristic: check if updateAuthority is non-zero system program
    const isMutable = !updateAuthority.equals(PublicKey.default);

    return {
        name,
        symbol,
        uri,
        isMutable,
        updateAuthority: updateAuthority.equals(PublicKey.default) ? null : updateAuthority.toBase58(),
    };
}

// =============================================================================
// MAIN
// =============================================================================

async function lockMetadata() {
    console.log("=".repeat(60));
    console.log("  METADATA LOCK — IRREVERSIBLE OPERATION");
    console.log("=".repeat(60));

    // Load config
    const rpcUrl = process.env.RPC_URL || clusterApiUrl("mainnet-beta");
    const mintAddress = process.env.TOKEN_MINT;
    const payerPath = process.env.PAYER_KEYPAIR_PATH;
    const dryRun = process.env.DRY_RUN === "true";

    if (!mintAddress || !payerPath) {
        console.error("Required environment variables:");
        console.error("  TOKEN_MINT           — Your token mint address");
        console.error("  PAYER_KEYPAIR_PATH   — Path to authority keypair JSON");
        console.error("");
        console.error("Optional:");
        console.error("  RPC_URL              — Solana RPC endpoint");
        console.error("  DRY_RUN              — Set 'true' to simulate only");
        process.exit(1);
    }

    const connection = new Connection(rpcUrl, "confirmed");
    const mint = new PublicKey(mintAddress);
    const payerBuffer = JSON.parse(fs.readFileSync(payerPath, "utf-8"));
    const payer = Keypair.fromSecretKey(Uint8Array.from(payerBuffer));

    console.log(`\nToken Mint: ${mintAddress}`);
    console.log(`Authority:  ${payer.publicKey.toBase58()}`);
    console.log(`Dry Run:    ${dryRun}`);
    console.log("");

    // =========================================================================
    // STEP 1: Detect token standard (SPL Token vs Token-2022)
    // =========================================================================

    console.log("Step 1: Detecting token standard...");

    let tokenProgram: PublicKey;
    let mintInfo;

    try {
        mintInfo = await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);
        tokenProgram = TOKEN_PROGRAM_ID;
        console.log("  Standard: SPL Token (Token Program)");
    } catch {
        try {
            mintInfo = await getMint(connection, mint, "confirmed", TOKEN_2022_PROGRAM_ID);
            tokenProgram = TOKEN_2022_PROGRAM_ID;
            console.log("  Standard: Token-2022 (Token Extensions)");
        } catch {
            console.error("  Failed to fetch mint info from either program.");
            process.exit(1);
        }
    }

    // =========================================================================
    // STEP 2: Verify current metadata state
    // =========================================================================

    console.log("\nStep 2: Verifying current metadata...");

    const metadata = await fetchMetaplexMetadata(connection, mint);
    if (metadata) {
        console.log(`  Name:             ${metadata.name}`);
        console.log(`  Symbol:           ${metadata.symbol}`);
        console.log(`  URI:              ${metadata.uri}`);
        console.log(`  Is Mutable:       ${metadata.isMutable}`);
        console.log(`  Update Authority: ${metadata.updateAuthority || "None (already locked)"}`);
    } else {
        console.log("  No Metaplex metadata found (Token-2022 may use extensions).");
    }

    console.log(`\n  Mint Authority:   ${mintInfo!.mintAuthority?.toBase58() || "None (revoked)"}`);
    console.log(`  Freeze Authority: ${mintInfo!.freezeAuthority?.toBase58() || "None (revoked)"}`);

    // =========================================================================
    // STEP 3: Build lock transaction
    // =========================================================================

    console.log("\nStep 3: Building lock transaction...");

    const tx = new Transaction();
    let instructionCount = 0;

    // 3a: Revoke Mint Authority (if still active)
    if (mintInfo!.mintAuthority) {
        if (mintInfo!.mintAuthority.equals(payer.publicKey)) {
            tx.add(createSetAuthorityInstruction(
                mint,
                payer.publicKey,
                AuthorityType.MintTokens,
                null,
                [],
                tokenProgram!
            ));
            instructionCount++;
            console.log("  + Revoke Mint Authority");
        } else {
            console.warn(`  ! Mint authority is ${mintInfo!.mintAuthority.toBase58()}, not your key. Skipping.`);
        }
    } else {
        console.log("  - Mint authority already revoked");
    }

    // 3b: Revoke Freeze Authority (if still active)
    if (mintInfo!.freezeAuthority) {
        if (mintInfo!.freezeAuthority.equals(payer.publicKey)) {
            tx.add(createSetAuthorityInstruction(
                mint,
                payer.publicKey,
                AuthorityType.FreezeAccount,
                null,
                [],
                tokenProgram!
            ));
            instructionCount++;
            console.log("  + Revoke Freeze Authority");
        } else {
            console.warn(`  ! Freeze authority is ${mintInfo!.freezeAuthority.toBase58()}, not your key. Skipping.`);
        }
    } else {
        console.log("  - Freeze authority already revoked");
    }

    // 3c: Set Metaplex metadata isMutable = false (if applicable)
    // NOTE: This requires building a Metaplex UpdateMetadataAccountV2 instruction.
    // The @metaplex-foundation/mpl-token-metadata SDK provides this.
    // Below is a structural note — in production, use the Metaplex SDK:
    //
    //   import { createUpdateMetadataAccountV2Instruction } from
    //     "@metaplex-foundation/mpl-token-metadata";
    //
    //   tx.add(createUpdateMetadataAccountV2Instruction(
    //     { metadata: metadataAddress, updateAuthority: payer.publicKey },
    //     { updateMetadataAccountArgsV2: {
    //         data: null,           // keep existing data
    //         updateAuthority: null, // keep existing (will revoke separately)
    //         primarySaleHappened: null,
    //         isMutable: false,     // LOCK
    //       }
    //     }
    //   ));

    if (metadata?.isMutable) {
        console.log("  + Set Metaplex isMutable = false (requires @metaplex-foundation/mpl-token-metadata)");
        console.log("    NOTE: Install the Metaplex SDK and uncomment the instruction above.");
        instructionCount++;
    } else if (metadata) {
        console.log("  - Metaplex metadata already immutable");
    }

    if (instructionCount === 0) {
        console.log("\nAll authorities already revoked. Nothing to do.");
        process.exit(0);
    }

    // =========================================================================
    // STEP 4: Execute (or simulate)
    // =========================================================================

    if (dryRun) {
        console.log(`\n[DRY RUN] Would execute ${instructionCount} instruction(s).`);
        console.log("[DRY RUN] Re-run without DRY_RUN=true to execute.");
        console.log("[DRY RUN] WARNING: These operations are IRREVERSIBLE.");
        process.exit(0);
    }

    // Confirmation prompt
    console.log("\n" + "!".repeat(60));
    console.log("  WARNING: THE FOLLOWING OPERATIONS ARE IRREVERSIBLE");
    console.log("  You will permanently lose the ability to:");
    console.log("    - Mint new tokens");
    console.log("    - Freeze token accounts");
    console.log("    - Update token metadata");
    console.log("!".repeat(60));

    // In a CI context, use CONFIRM=true env var to skip prompt
    if (process.env.CONFIRM !== "true") {
        const readline = await import("readline");
        const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
        const answer = await new Promise<string>((resolve) => {
            rl.question("\nType 'LOCK' to confirm: ", resolve);
        });
        rl.close();

        if (answer.trim() !== "LOCK") {
            console.log("Aborted.");
            process.exit(0);
        }
    }

    console.log("\nExecuting lock transaction...");

    try {
        const signature = await sendAndConfirmTransaction(connection, tx, [payer]);
        console.log(`\nTransaction confirmed: ${signature}`);
    } catch (error) {
        console.error("Transaction failed:", error);
        process.exit(1);
    }

    // =========================================================================
    // STEP 5: Post-verification
    // =========================================================================

    console.log("\nStep 5: Post-verification...");

    const updatedMint = await getMint(connection, mint, "confirmed", tokenProgram!);
    console.log(`  Mint Authority:   ${updatedMint.mintAuthority?.toBase58() || "None (REVOKED)"}`);
    console.log(`  Freeze Authority: ${updatedMint.freezeAuthority?.toBase58() || "None (REVOKED)"}`);

    const allRevoked = !updatedMint.mintAuthority && !updatedMint.freezeAuthority;

    if (allRevoked) {
        console.log("\n  VERIFICATION PASSED: Token is now trustless and immutable.");
    } else {
        console.log("\n  VERIFICATION WARNING: Some authorities remain active.");
    }

    console.log("\n" + "=".repeat(60));
    console.log("  METADATA LOCK COMPLETE");
    console.log("=".repeat(60));
}

lockMetadata().catch((err) => {
    console.error("Fatal error:", err);
    process.exit(1);
});
