"use client";

import React, { useEffect, useState } from "react";
import { motion, useSpring, useTransform } from "framer-motion";

interface AnimatedNumberProps {
    value: number;
    format?: (n: number) => string;
    className?: string;
}

export function AnimatedNumber({ value, format, className = "" }: AnimatedNumberProps) {
    const spring = useSpring(0, { stiffness: 50, damping: 20 });
    const display = useTransform(spring, (v) => format ? format(v) : v.toLocaleString());
    const [text, setText] = useState(format ? format(value) : value.toLocaleString());

    useEffect(() => {
        spring.set(value);
    }, [value, spring]);

    useEffect(() => {
        const unsub = display.on("change", (v) => setText(v));
        return unsub;
    }, [display]);

    return (
        <motion.span className={className}>
            {text}
        </motion.span>
    );
}
