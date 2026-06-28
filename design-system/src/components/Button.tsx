import React from "react";
import { color, font, radius } from "../tokens";

type Variant = "primary" | "accent" | "secondary" | "outline";
type Size = "lg" | "md";

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  fullWidth?: boolean;
  leftIcon?: React.ReactNode;
}

const variants: Record<Variant, React.CSSProperties> = {
  primary: { background: color.ink, color: color.onInk, border: "none" }, // 주 CTA(잉크)
  accent: { background: color.accent, color: color.onAccent, border: "none" }, // 코랄 CTA
  secondary: { background: color.soft, color: color.ink, border: "none" },
  outline: { background: color.surface, color: color.ink, border: `1px solid ${color.line}` },
};

/** PetFit 버튼. 주 CTA는 잉크(primary), 강조 CTA는 코랄(accent). 그라데이션 없음. */
export const Button: React.FC<ButtonProps> = ({
  variant = "primary",
  size = "lg",
  fullWidth = true,
  leftIcon,
  children,
  style,
  ...rest
}) => {
  const height = size === "lg" ? 52 : 44;
  return (
    <button
      style={{
        height,
        width: fullWidth ? "100%" : "auto",
        padding: "0 18px",
        borderRadius: radius.md,
        fontFamily: font.family,
        fontSize: 15,
        fontWeight: font.heavy,
        letterSpacing: "-.3px",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 7,
        cursor: "pointer",
        ...variants[variant],
        ...style,
      }}
      {...rest}
    >
      {leftIcon}
      {children}
    </button>
  );
};
