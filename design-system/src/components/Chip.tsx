import React from "react";
import { color, font, radius } from "../tokens";

export interface ChipProps {
  label: string;
  selected?: boolean;
  onClick?: () => void;
}

/** 카테고리/필터 칩. 선택=ink 배경+흰 글자, 비선택=surface+line 보더+sub 글자. */
export const Chip: React.FC<ChipProps> = ({ label, selected = false, onClick }) => (
  <button
    onClick={onClick}
    style={{
      display: "inline-flex",
      alignItems: "center",
      height: 36,
      padding: "0 16px",
      borderRadius: radius.full,
      cursor: "pointer",
      fontFamily: font.family,
      fontSize: font.chip,
      fontWeight: font.bold,
      letterSpacing: "-.3px",
      whiteSpace: "nowrap",
      background: selected ? color.ink : color.surface,
      color: selected ? color.onInk : color.sub,
      border: `1px solid ${selected ? color.ink : color.line}`,
    }}
  >
    {label}
  </button>
);
