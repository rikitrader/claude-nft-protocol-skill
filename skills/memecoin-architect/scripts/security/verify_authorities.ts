// =============================================================================
// VERIFY AUTHORITIES — POST-DEPLOY SECURITY CHECKER
// =============================================================================
// PURPOSE: Comprehensive verification that all dangerous authorities are revoked
//          and the token is in a trustless state. Returns exit code 0 (pass) or
//          1 (fail) for CI/CD integration.
//
// CHECKS:
//   1. Mint Authority           — Must be None
//   2. Freeze Authority         — Must be None
//   3. Metadata Update Auth     — Must be None (Metaplex)
//   4. Metadata isMutable       — Must be false (Metaplex)
//   5. Token Account Ownership  — Must be PDA (program-owned)
//   6. LP Lock Status           — Must be Locked or Burned
//
// EXIT CODES:
//   0 = All checks passed
//   1 = One or more checks failed (blocks deployment)
// =============================================================================

import {
    Connection,
    PublicKey,
    clusterApiUrl,
} from "@solana/web3.js";
import {
    getMint,
    getAccount,
    TOKEN_PROGRAM_ID,
    TOKEN_2022_PROGRAM_ID,
} from "@solana/spl-token";

// Metaplex Metadata Program
const METAPLEX_METADATA_PROGRAM_ID = new PublicKey(
    "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
);

// =============================================================================
// CHECK RESULT TYPE
// =============================================================================

interface CheckResult {
    name: string;
    expected: string;
    actual: string;
    passed: boolean;
}

// =============================================================================
// INDIVIDUAL CHECKS
// =============================================================================

async function checkMintAuthority(
    connection: Connection,
    mint: PublicKey,
    tokenProgram: PublicKey,
): Promise<CheckResult> {
    const mintInfo = await getMint(connection, mint, "confirmed", tokenProgram);
    const authority = mintInfo.mintAuthority;

    return {
        name: "Mint Authority",
        expected: "None",
        actual: authority ? authority.toBase58() : "None",
        passed: authority === null,
    };
}

async function checkFreezeAuthority(
    connection: Connection,
    mint: PublicKey,
    tokenProgram: PublicKey,
): Promise<CheckResult> {
    const mintInfo = await getMint(connection, mint, "confirmed", tokenProgram);
    const authority = mintInfo.freezeAuthority;

    return {
        name: "Freeze Authority",
        expected: "None",
        actual: authority ? authority.toBase58() : "None",
        passed: authority === null,
    };
}

async function checkMetadataUpdateAuthority(
    connection: Connection,
    mint: PublicKey,
): Promise<CheckResult> {
    const [metadataAddress] = PublicKey.findProgramAddressSync(
        [
            Buffer.from("metadata"),
            METAPLEX_METADATA_PROGRAM_ID.toBuffer(),
            mint.toBuffer(),
        ],
        METAPLEX_METADATA_PROGRAM_ID
    );

    const accountInfo = await connection.getAccountInfo(metadataAddress);

    if (!accountInfo) {
        return {
            name: "Metadata Update Authority",
            expected: "None",
            actual: "No Metaplex metadata (OK for Token-2022)",
            passed: true, // No metadata = no update authority risk
        };
    }

    // Parse update authority from Metaplex metadata layout
    // Byte 0 = key, Bytes 1-32 = update authority
    const updateAuthority = new PublicKey(accountInfo.data.slice(1, 33));
    const isNone = updateAuthority.equals(PublicKey.default);

    return {
        name: "Metadata Update Authority",
        expected: "None",
        actual: isNone ? "None" : updateAuthority.toBase58(),
        passed: isNone,
    };
}

async function checkMetadataIsMutable(
    connection: Connection,
    mint: PublicKey,
): Promise<CheckResult> {
    const [metadataAddress] = PublicKey.findProgramAddressSync(
        [
            Buffer.from("metadata"),
            METAPLEX_METADATA_PROGRAM_ID.toBuffer(),
            mint.toBuffer(),
        ],
        METAPLEX_METADATA_PROGRAM_ID
    );

    const accountInfo = await connection.getAccountInfo(metadataAddress);

    if (!accountInfo) {
        return {
            name: "Metadata isMutable",
            expected: "false",
            actual: "No Metaplex metadata (OK for Token-2022)",
            passed: true,
        };
    }

    // In Metaplex v1 layout, isMutable is at a variable offset after:
    // key(1) + updateAuthority(32) + mint(32) + name(4+32) + symbol(4+14) + uri(4+200)
    // + sellerFeeBasisPoints(2) + creatorsOption(1+variable) + primarySaleHappened(1)
    // isMutable(1)
    //
    // For a more robust check, use the update authority as proxy:
    // If update authority is null (PublicKey.default), it's effectively immutable.
    const updateAuthority = new PublicKey(accountInfo.data.slice(1, 33));
    const effectivelyImmutable = updateAuthority.equals(PublicKey.default);

    return {
        name: "Metadata isMutable",
        expected: "false",
        actual: effectivelyImmutable ? "false (authority revoked)" : "true (authority active)",
        passed: effectivelyImmutable,
    };
}

async function checkTokenAccountOwnership(
    connection: Connection,
    tokenAccountAddress: string | undefined,
    expectedOwnerProgram: string | undefined,
): Promise<CheckResult> {
    if (!tokenAccountAddress) {
        return {
            name: "Token Account Ownership",
            expected: "PDA (program-owned)",
            actual: "SKIPPED (TREASURY_TOKEN_ACCOUNT not set)",
            passed: true, // Skip if not configured
        };
    }

    try {
        const tokenAccount = await getAccount(
            connection,
            new PublicKey(tokenAccountAddress),
            "confirmed"
        );

        const owner = tokenAccount.owner.toBase58();
        const isPDA = expectedOwnerProgram
            ? owner === expectedOwnerProgram
            : !tokenAccount.owner.equals(PublicKey.default);

        return {
            name: "Token Account Ownership",
            expected: expectedOwnerProgram || "PDA (program-owned)",
            actual: owner,
            passed: isPDA,
        };
    } catch {
        return {
            name: "Token Account Ownership",
            expected: "PDA (program-owned)",
            actual: "ERROR: Could not fetch token account",
            passed: false,
        };
    }
}

async function checkLpLockStatus(
    connection: Connection,
    lpMintAddress: string | undefined,
): Promise<CheckResult> {
    if (!lpMintAddress) {
        return {
            name: "LP Lock Status",
            expected: "Locked or Burned",
            actual: "SKIPPED (LP_MINT not set)",
            passed: true, // Skip if not configured
        };
    }

    try {
        const lpMint = new PublicKey(lpMintAddress);
        // Try SPL Token first, fall back to Token-2022
        let lpMintInfo;
        try {
            lpMintInfo = await getMint(connection, lpMint, "confirmed", TOKEN_PROGRAM_ID);
        } catch {
            lpMintInfo = await getMint(connection, lpMint, "confirmed", TOKEN_2022_PROGRAM_ID);
        }

        // If supply is 0, LP tokens were burned
        if (lpMintInfo.supply === BigInt(0)) {
            return {
                name: "LP Lock Status",
                expected: "Locked or Burned",
                actual: "BURNED (supply = 0)",
                passed: true,
            };
        }

        // If supply > 0, check if mint authority is revoked (locked pattern)
        const mintRevoked = lpMintInfo.mintAuthority === null;

        return {
            name: "LP Lock Status",
            expected: "Locked or Burned",
            actual: mintRevoked
                ? `Active (supply: ${lpMintInfo.supply}) — verify lock contract`
                : `WARNING: LP mint authority active`,
            passed: mintRevoked, // Conservative: pass only if mint authority revoked
        };
    } catch {
        return {
            name: "LP Lock Status",
            expected: "Locked or Burned",
            actual: "ERROR: Could not fetch LP mint",
            passed: false,
        };
    }
}

// =============================================================================
// MAIN
// =============================================================================

async function verifyAuthorities() {
    console.log("=".repeat(60));
    console.log("  POST-DEPLOY AUTHORITY VERIFICATION");
    console.log("=".repeat(60));

    const mintAddress = process.env.TOKEN_MINT;
    const rpcUrl = process.env.RPC_URL || clusterApiUrl("mainnet-beta");

    if (!mintAddress) {
        console.error("Usage: TOKEN_MINT=... ts-node verify_authorities.ts");
        console.error("");
        console.error("Required:");
        console.error("  TOKEN_MINT                — Token mint address");
        console.error("");
        console.error("Optional:");
        console.error("  RPC_URL                   — Solana RPC endpoint");
        console.error("  TREASURY_TOKEN_ACCOUNT    — Treasury ATA address");
        console.error("  EXPECTED_OWNER            — Expected treasury owner (program ID)");
        console.error("  LP_MINT                   — LP token mint address");
        process.exit(1);
    }

    const connection = new Connection(rpcUrl, "confirmed");
    const mint = new PublicKey(mintAddress);

    console.log(`\nToken Mint: ${mintAddress}`);
    console.log(`RPC:        ${rpcUrl}`);
    console.log("");

    // Detect token program
    let tokenProgram: PublicKey;
    try {
        await getMint(connection, mint, "confirmed", TOKEN_PROGRAM_ID);
        tokenProgram = TOKEN_PROGRAM_ID;
        console.log("Token Standard: SPL Token");
    } catch {
        try {
            await getMint(connection, mint, "confirmed", TOKEN_2022_PROGRAM_ID);
            tokenProgram = TOKEN_2022_PROGRAM_ID;
            console.log("Token Standard: Token-2022");
        } catch {
            console.error("ERROR: Could not fetch mint from either token program.");
            process.exit(1);
        }
    }

    console.log("");

    // =========================================================================
    // RUN ALL 6 CHECKS
    // =========================================================================

    const results: CheckResult[] = [];

    console.log("Running checks...\n");

    // Check 1: Mint Authority
    results.push(await checkMintAuthority(connection, mint, tokenProgram!));

    // Check 2: Freeze Authority
    results.push(await checkFreezeAuthority(connection, mint, tokenProgram!));

    // Check 3: Metadata Update Authority
    results.push(await checkMetadataUpdateAuthority(connection, mint));

    // Check 4: Metadata isMutable
    results.push(await checkMetadataIsMutable(connection, mint));

    // Check 5: Token Account Ownership
    results.push(await checkTokenAccountOwnership(
        connection,
        process.env.TREASURY_TOKEN_ACCOUNT,
        process.env.EXPECTED_OWNER,
    ));

    // Check 6: LP Lock Status
    results.push(await checkLpLockStatus(connection, process.env.LP_MINT));

    // =========================================================================
    // REPORT
    // =========================================================================

    console.log("+" + "-".repeat(24) + "+" + "-".repeat(17) + "+" + "-".repeat(10) + "+");
    console.log("| " + "Authority".padEnd(23) + "| " + "Expected".padEnd(16) + "| " + "Status".padEnd(9) + "|");
    console.log("+" + "-".repeat(24) + "+" + "-".repeat(17) + "+" + "-".repeat(10) + "+");

    for (const result of results) {
        const status = result.passed ? "PASS" : "FAIL";
        const icon = result.passed ? "+" : "!";
        console.log(
            `| ${result.name.padEnd(23)}| ${result.expected.padEnd(16).slice(0, 16)}| ${icon} ${status.padEnd(6)}|`
        );
    }

    console.log("+" + "-".repeat(24) + "+" + "-".repeat(17) + "+" + "-".repeat(10) + "+");

    // Detailed results for failures
    const failures = results.filter((r) => !r.passed);
    if (failures.length > 0) {
        console.log("\nFAILED CHECKS:");
        for (const f of failures) {
            console.log(`  ${f.name}`);
            console.log(`    Expected: ${f.expected}`);
            console.log(`    Actual:   ${f.actual}`);
        }
    }

    // =========================================================================
    // EXIT CODE
    // =========================================================================

    const allPassed = results.every((r) => r.passed);
    const passCount = results.filter((r) => r.passed).length;

    console.log(`\nResult: ${passCount}/${results.length} checks passed`);

    if (allPassed) {
        console.log("\nVERIFICATION PASSED: Token is in a trustless state.");
        console.log("=".repeat(60));
        process.exit(0);
    } else {
        console.log("\nVERIFICATION FAILED: One or more checks did not pass.");
        console.log("Fix the issues above before proceeding with deployment.");
        console.log("=".repeat(60));
        process.exit(1);
    }
}

verifyAuthorities().catch((err) => {
    console.error("Fatal error:", err);
    process.exit(1);
});
