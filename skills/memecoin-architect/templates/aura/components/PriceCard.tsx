import React from 'react';

/**
 * PRICE CARD COMPONENT
 * 
 * Displays real-time price info with a simple sparkline placeholder 
 * and 24h change indicators.
 */

interface PriceCardProps {
    price: number;
    change24h: number;
    symbol: string;
}

export const PriceCard: React.FC<PriceCardProps> = ({ price, change24h, symbol }) => {
    const isPositive = change24h >= 0;

    return (
        <div className="flex flex-col space-y-2">
            <div className="flex items-center justify-between">
                <span className="text-2xl font-bold text-white">
                    ${price < 0.0001 ? price.toExponential(4) : price.toLocaleString(undefined, { minimumFractionDigits: 6 })}
                </span>
                <div className={`flex items-center space-x-1 rounded-full px-2 py-0.5 text-[10px] font-bold ${isPositive ? 'bg-emerald-500/20 text-emerald-400' : 'bg-rose-500/20 text-rose-400'
                    }`}>
                    <span>{isPositive ? '▲' : '▼'}</span>
                    <span>{Math.abs(change24h).toFixed(2)}%</span>
                </div>
            </div>
            <div className="text-[10px] font-medium tracking-widest text-white/40 uppercase">
                {symbol} / USDC
            </div>
        </div>
    );
};
