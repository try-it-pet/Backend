import React from "react";
import { color, font, radius, shadow } from "../tokens";
import { IconHome, IconGrid, IconHeart, IconUser, IconImage } from "./icons";

export interface TabItem {
  key: string;
  label: string;
  /** 중앙 AI 피팅 탭은 코랄 원형 FAB로 강조 */
  fab?: boolean;
}

export interface BottomTabProps {
  items?: TabItem[];
  activeKey?: string;
  onChange?: (key: string) => void;
}

const DEFAULT_ITEMS: TabItem[] = [
  { key: "home", label: "홈" },
  { key: "category", label: "카테고리" },
  { key: "ai", label: "AI 피팅", fab: true },
  { key: "likes", label: "좋아요" },
  { key: "my", label: "마이" },
];

const TAB_ICON: Record<string, React.FC<{ size?: number }>> = {
  home: IconHome,
  category: IconGrid,
  likes: IconHeart,
  my: IconUser,
};

/** 하단 5탭. 중앙 'AI 피팅'은 코랄 원형 FAB(이미지 아이콘). 활성=accent, 비활성=muted. */
export const BottomTab: React.FC<BottomTabProps> = ({
  items = DEFAULT_ITEMS, activeKey = "home", onChange,
}) => (
  <nav
    style={{
      display: "flex", alignItems: "flex-start",
      height: 82, paddingTop: 11,
      background: "rgba(250,248,245,.94)", backdropFilter: "blur(14px)",
      borderTop: `1px solid ${color.line}`, fontFamily: font.family,
    }}
  >
    {items.map((it) => {
      const active = it.key === activeKey;
      if (it.fab) {
        return (
          <div key={it.key} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center" }}>
            <button
              onClick={() => onChange?.(it.key)}
              style={{
                marginTop: -24, width: 54, height: 54, borderRadius: "50%",
                border: `4px solid ${color.paper}`, background: color.accent,
                cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center",
                boxShadow: shadow.fab, color: color.onAccent,
              }}
            >
              <IconImage size={24} />
            </button>
            <span style={{ fontSize: font.tab, fontWeight: font.bold, color: color.accent, marginTop: 4, letterSpacing: "-.2px" }}>{it.label}</span>
          </div>
        );
      }
      const Ico = TAB_ICON[it.key] ?? IconHome;
      return (
        <button
          key={it.key}
          onClick={() => onChange?.(it.key)}
          style={{
            flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
            background: "none", border: "none", cursor: "pointer",
            fontSize: font.tab, fontWeight: font.bold, letterSpacing: "-.2px",
            color: active ? color.accent : "#B3ABA1",
          }}
        >
          <Ico size={22} />
          <span>{it.label}</span>
        </button>
      );
    })}
  </nav>
);
