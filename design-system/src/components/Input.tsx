import React from "react";
import { color, font, radius } from "../tokens";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
}

/** 기본 텍스트 인풋. 높이 48, surface 표면, line 보더, 포커스 시 accent 보더. */
export const Input: React.FC<InputProps> = ({ label, style, ...rest }) => (
  <label style={{ display: "block", fontFamily: font.family }}>
    {label && (
      <span style={{ display: "block", fontSize: font.caption, color: color.sub, fontWeight: font.semibold, marginBottom: 6 }}>
        {label}
      </span>
    )}
    <input
      style={{
        height: 48,
        width: "100%",
        boxSizing: "border-box",
        padding: "0 15px",
        borderRadius: radius.md,
        border: `1px solid ${color.line}`,
        background: color.surface,
        fontSize: 14.5,
        color: color.ink,
        outline: "none",
        ...style,
      }}
      onFocus={(e) => (e.currentTarget.style.borderColor = color.accent)}
      onBlur={(e) => (e.currentTarget.style.borderColor = color.line)}
      {...rest}
    />
  </label>
);
