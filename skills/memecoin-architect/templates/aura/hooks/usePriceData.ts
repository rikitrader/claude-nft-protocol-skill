"use client";

// =============================================================================
// usePriceData — Jupiter Price API v2
// =============================================================================

import { useQuery } from "@tanstack/react-query";
import { JUPITER_PRICE_API, TOKEN_MINT, REFETCH_INTERVAL } from "@/lib/constants";

export interface PriceData {
    price: number;
    change24h: number;
    volume24h: number;
    marketCap: number;
}

export function usePriceData() {
    return useQuery<PriceData>({
        queryKey: ["priceData", TOKEN_MINT.toBase58()],
        queryFn: async () => {
            const res = await fetch(
                `${JUPITER_PRICE_API}?ids=${TOKEN_MINT.toBase58()}&showExtraInfo=true`,
            );
            if (!res.ok) throw new Error(`Jupiter API ${res.status}`);

            const json = await res.json();
            const data = json.data?.[TOKEN_MINT.toBase58()];

            if (!data) {
                return { price: 0, change24h: 0, volume24h: 0, marketCap: 0 };
            }

            return {
                price: data.price ?? 0,
                change24h: data.extraInfo?.lastDayPriceChange ?? 0,
                volume24h: data.extraInfo?.quotedPrice?.buyPrice ?? 0,
                marketCap: (data.price ?? 0) * 1_000_000_000,
            };
        },
        refetchInterval: REFETCH_INTERVAL,
        staleTime: REFETCH_INTERVAL / 2,
    });
}
