import React from "react";

export interface IconProps {
  size?: number;
  color?: string;
  /** 채움 여부(하트 등) */
  filled?: boolean;
  style?: React.CSSProperties;
}

const base = (size: number, style?: React.CSSProperties): React.SVGProps<SVGSVGElement> => ({
  width: size,
  height: size,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.8,
  strokeLinecap: "round",
  strokeLinejoin: "round",
  style: { display: "block", ...style },
  "aria-hidden": true,
});

/** 외곽선 아이콘 모음. 이모티콘 대신 사용한다. color는 currentColor 상속. */

export const IconSearch: React.FC<IconProps> = ({ size = 20, color, style }) => (
  <svg {...base(size, style)} color={color}>
    <circle cx="11" cy="11" r="7" />
    <path d="m20 20-3.5-3.5" />
  </svg>
);

export const IconHeart: React.FC<IconProps> = ({ size = 20, color, filled, style }) => (
  <svg {...base(size, style)} color={color} fill={filled ? "currentColor" : "none"}>
    <path d="M12 20s-7-4.5-7-9.5A3.5 3.5 0 0 1 12 7a3.5 3.5 0 0 1 7 3.5C19 15.5 12 20 12 20Z" />
  </svg>
);

/** AI 피팅(이미지) 아이콘 — 반짝이/별 대신 사용. 핸드오프 FAB·피팅 CTA. */
export const IconImage: React.FC<IconProps> = ({ size = 20, color, style }) => (
  <svg {...base(size, style)} color={color}>
    <rect x="3" y="3" width="18" height="18" rx="3" />
    <circle cx="9" cy="9" r="2" />
    <path d="M21 15l-5-5L5 21" />
  </svg>
);

export const IconHome: React.FC<IconProps> = ({ size = 22, color, style }) => (
  <svg {...base(size, style)} color={color}>
    <path d="M4 11 12 4l8 7" />
    <path d="M6 10v9h12v-9" />
  </svg>
);

export const IconGrid: React.FC<IconProps> = ({ size = 22, color, style }) => (
  <svg {...base(size, style)} color={color}>
    <rect x="4" y="4" width="7" height="7" rx="1.5" />
    <rect x="13" y="4" width="7" height="7" rx="1.5" />
    <rect x="4" y="13" width="7" height="7" rx="1.5" />
    <rect x="13" y="13" width="7" height="7" rx="1.5" />
  </svg>
);

export const IconUser: React.FC<IconProps> = ({ size = 22, color, style }) => (
  <svg {...base(size, style)} color={color}>
    <circle cx="12" cy="8" r="3.5" />
    <path d="M5 20c0-3.5 3-6 7-6s7 2.5 7 6" />
  </svg>
);

export const IconPaw: React.FC<IconProps> = ({ size = 24, color, style }) => (
  <svg {...base(size, style)} color={color}>
    <circle cx="6.5" cy="10" r="1.8" fill="currentColor" stroke="none" />
    <circle cx="10" cy="6.5" r="1.8" fill="currentColor" stroke="none" />
    <circle cx="14" cy="6.5" r="1.8" fill="currentColor" stroke="none" />
    <circle cx="17.5" cy="10" r="1.8" fill="currentColor" stroke="none" />
    <path d="M12 12c-2.6 0-4.5 1.8-4.5 3.8 0 1.6 1.4 2.4 3 2.4.9 0 1.1.4 1.5.4s.6-.4 1.5-.4c1.6 0 3-.8 3-2.4 0-2-1.9-3.8-4.5-3.8Z" fill="currentColor" stroke="none" />
  </svg>
);
