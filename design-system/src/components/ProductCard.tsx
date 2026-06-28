import React from "react";
import { color, font, radius } from "../tokens";
import { IconHeart } from "./icons";

export interface ProductCardProps {
  brand: string;
  name: string;
  price: number;
  imageUrl?: string;
  liked?: boolean;
  /** AI 핏이 높을 때 좌상단 "AI 추천" 라벨 표시 */
  aiRecommend?: boolean;
  onLike?: (e: React.MouseEvent) => void;
  onClick?: () => void;
}

const won = (n: number) => `${n.toLocaleString("ko-KR")}원`;

/** 상품 카드: soft 이미지(1:1) + "AI 추천" 텍스트 라벨 + 하트. 그림자 없음(미니멀). */
export const ProductCard: React.FC<ProductCardProps> = ({
  brand, name, price, imageUrl, liked = false, aiRecommend = false, onLike, onClick,
}) => (
  <div style={{ fontFamily: font.family, cursor: onClick ? "pointer" : "default" }} onClick={onClick}>
    <div
      style={{
        position: "relative",
        aspectRatio: "1 / 1",
        borderRadius: radius.card,
        overflow: "hidden",
        background: imageUrl ? `center/cover no-repeat url(${imageUrl})` : color.soft,
      }}
    >
      {aiRecommend && (
        <span
          style={{
            position: "absolute", top: 9, left: 9,
            background: "rgba(255,255,255,.94)", color: color.accent,
            fontSize: 10.5, fontWeight: font.heavy, padding: "4px 9px",
            borderRadius: radius.full, letterSpacing: "-.2px",
          }}
        >
          AI 추천
        </span>
      )}
      <button
        aria-label="좋아요"
        onClick={(e) => { e.stopPropagation(); onLike?.(e); }}
        style={{
          position: "absolute", top: 8, right: 8, width: 30, height: 30,
          display: "flex", alignItems: "center", justifyContent: "center",
          background: "none", border: "none", cursor: "pointer", padding: 0,
          color: liked ? color.accent : color.ink,
        }}
      >
        <IconHeart size={20} filled={liked} />
      </button>
    </div>
    <div style={{ paddingTop: 10 }}>
      <div style={{ fontSize: font.label, color: color.muted2, fontWeight: font.semibold, letterSpacing: "-.2px" }}>{brand}</div>
      <div style={{ fontSize: font.body, fontWeight: font.medium, marginTop: 3, letterSpacing: "-.3px", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{name}</div>
      <div style={{ fontSize: font.price, fontWeight: font.heavy, marginTop: 6, letterSpacing: "-.4px", color: color.ink }}>{won(price)}</div>
    </div>
  </div>
);
