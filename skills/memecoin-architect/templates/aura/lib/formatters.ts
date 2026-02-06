// =============================================================================
// FORMATTERS — Number, Address, and Time Utilities
// =============================================================================

/**
 * Format large numbers with compact notation (1.2B, 456M, 12K).
 */
export function formatNumber(value: number, decimals = 1): string {
    if (value >= 1_000_000_000) return `${(value / 1_000_000_000).toFixed(decimals)}B`;
    if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(decimals)}M`;
    if (value >= 1_000) return `${(value / 1_000).toFixed(decimals)}K`;
    return value.toLocaleString(undefined, { maximumFractionDigits: decimals });
}

/**
 * Format SOL amounts with lamport precision.
 */
export function formatSOL(lamports: number): string {
    const sol = lamports / 1e9;
    if (sol >= 1_000) return `${formatNumber(sol)} SOL`;
    return `${sol.toLocaleString(undefined, { maximumFractionDigits: 4 })} SOL`;
}

/**
 * Shorten a base58 address to first4...last4 format.
 */
export function shortenAddress(address: string, chars = 4): string {
    if (address.length <= chars * 2 + 3) return address;
    return `${address.slice(0, chars)}...${address.slice(-chars)}`;
}

/**
 * Format a percentage value with sign indicator.
 */
export function formatPercent(value: number, decimals = 2): string {
    const sign = value >= 0 ? "+" : "";
    return `${sign}${value.toFixed(decimals)}%`;
}

/**
 * Relative time string from a Unix timestamp or slot number.
 */
export function timeAgo(timestamp: number): string {
    const seconds = Math.floor((Date.now() / 1000) - timestamp);
    if (seconds < 60) return "just now";
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    return `${Math.floor(seconds / 86400)}d ago`;
}
