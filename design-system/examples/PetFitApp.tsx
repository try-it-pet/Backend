import React, { useState } from "react";

/**
 * PetFit 앱 — Claude Design 핸드오프("PetFit App.dc.html")의 충실한 React 구현.
 * 디자인 철학: 미니멀, 그라데이션 없음, 액센트는 코랄(#E8674A) 한 가지,
 * AI는 작은 텍스트 라벨로 조용히 표현(반짝이/별 아이콘 금지).
 */

const T = {
  paper: "#FAF8F5",
  surface: "#FFFFFF",
  soft: "#F1ECE6",
  heroBg: "#EDE6DD",
  ink: "#1A1714",
  sub: "#6E665E",
  muted: "#9B948C",
  muted2: "#A89F95",
  line: "#ECE7E1",
  accent: "#E8674A",
  accentSoft: "#FBEDE8",
  heroLabel: "#A2693F",
};

type Product = { brand: string; name: string; price: number; fit: number };
const PRODUCTS: Product[] = [
  { brand: "무무펫", name: "코지 니트 스웨터", price: 28000, fit: 96 },
  { brand: "도그웨어", name: "체크 하네스 세트", price: 34000, fit: 89 },
  { brand: "펫코", name: "경량 패딩 베스트", price: 42000, fit: 94 },
  { brand: "모카독", name: "데일리 후디", price: 25000, fit: 92 },
  { brand: "무무펫", name: "윈터 울 코트", price: 48000, fit: 90 },
  { brand: "도그웨어", name: "스트라이프 티셔츠", price: 19000, fit: 88 },
];
const won = (n: number) => n.toLocaleString("ko-KR");

type Screen = "home" | "category" | "fit" | "detail" | "likes" | "my";
type Liked = Record<number, boolean>;

/* ── 아이콘 (핸드오프 인라인 SVG) ── */
const sv = (extra?: React.CSSProperties): React.CSSProperties => ({ display: "block", ...extra });

const Heart = ({ size = 20, fill = "none", stroke = T.ink }: { size?: number; fill?: string; stroke?: string }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={stroke} strokeWidth={1.8} style={sv()}>
    <path d="M12 20.5C7 16.5 3.5 13.3 3.5 9.4 3.5 6.9 5.5 5 7.9 5c1.6 0 2.9.8 4.1 2.3C13.2 5.8 14.5 5 16.1 5c2.4 0 4.4 1.9 4.4 4.4 0 3.9-3.5 7.1-8.5 11.1z" />
  </svg>
);
const FitIcon = ({ size = 20, stroke = T.accent }: { size?: number; stroke?: string }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={stroke} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" style={sv()}>
    <rect x="3" y="3" width="18" height="18" rx="3" />
    <circle cx="9" cy="9" r="2" />
    <path d="M21 15l-5-5L5 21" />
  </svg>
);
const Back = ({ size = 22 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={T.ink} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" style={sv()}>
    <path d="M15 6l-6 6 6 6" />
  </svg>
);
const ChevR = ({ size = 17, stroke = "#C4BDB3", w = 2 }: { size?: number; stroke?: string; w?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={stroke} strokeWidth={w} strokeLinecap="round" strokeLinejoin="round" style={sv()}>
    <path d="M9 6l6 6-6 6" />
  </svg>
);
const Search = ({ size = 18 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="#B3ABA1" strokeWidth={2} strokeLinecap="round" style={sv()}>
    <circle cx="11" cy="11" r="7" />
    <path d="M20 20l-3.2-3.2" />
  </svg>
);

/* ── 이미지 플레이스홀더 ── */
const ImageSlot = ({ label, radius = 0, circle = false, style }: { label: string; radius?: number; circle?: boolean; style?: React.CSSProperties }) => (
  <div
    style={{
      width: "100%",
      height: "100%",
      background: T.soft,
      borderRadius: circle ? "50%" : radius,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      ...style,
    }}
  >
    <span style={{ fontSize: 10.5, color: T.muted2, fontWeight: 600, letterSpacing: "-.2px", textAlign: "center", padding: 4 }}>{label}</span>
  </div>
);

export function PetFitApp({ petName = "초코" }: { petName?: string }) {
  const [st, setSt] = useState<{
    screen: Screen; prev: Screen; chip: string; catChip: string; size: string; fitG: number; selProd: number; liked: Liked;
  }>({
    screen: "home", prev: "home", chip: "전체", catChip: "전체", size: "M", fitG: 0, selProd: 0,
    liked: { 0: false, 1: true, 2: false, 3: true, 4: false, 5: false },
  });

  const set = (patch: Partial<typeof st>) => setSt((s) => ({ ...s, ...patch }));
  const go = (screen: Screen) => setSt((s) => ({ ...s, screen, prev: s.screen }));
  const toggle = (i: number) => setSt((s) => ({ ...s, liked: { ...s.liked, [i]: !s.liked[i] } }));

  const card = (i: number) => {
    const p = PRODUCTS[i];
    const on = st.liked[i];
    return {
      i, brand: p.brand, name: p.name, priceText: won(p.price), showBadge: p.fit >= 93,
      heartFill: on ? T.accent : "none", heartStroke: on ? T.accent : T.ink,
      onOpen: () => setSt((s) => ({ ...s, screen: "detail", prev: s.screen, selProd: i })),
      onLike: (e: React.MouseEvent) => { e.stopPropagation(); toggle(i); },
    };
  };

  const chipStyle = (active: boolean): React.CSSProperties => ({
    display: "inline-flex", alignItems: "center", padding: "9px 16px", borderRadius: 999,
    fontSize: 13.5, fontWeight: 700, whiteSpace: "nowrap", cursor: "pointer", letterSpacing: "-.3px",
    flex: "0 0 auto", background: active ? T.ink : T.surface, color: active ? "#fff" : T.sub,
    border: `1px solid ${active ? T.ink : T.line}`,
  });

  const ProductCardView = ({ p, badge = true }: { p: ReturnType<typeof card>; badge?: boolean }) => (
    <div onClick={p.onOpen} style={{ cursor: "pointer" }}>
      <div style={{ position: "relative", aspectRatio: "1 / 1", background: T.soft, borderRadius: 16, overflow: "hidden" }}>
        <ImageSlot label="상품 사진" />
        {badge && p.showBadge && (
          <span style={{ position: "absolute", top: 9, left: 9, background: "rgba(255,255,255,.94)", color: T.accent, fontSize: 10.5, fontWeight: 800, padding: "4px 9px", borderRadius: 999, letterSpacing: "-.2px" }}>AI 추천</span>
        )}
        <div onClick={p.onLike} style={{ position: "absolute", top: 8, right: 8, width: 30, height: 30, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
          <Heart size={20} fill={p.heartFill} stroke={p.heartStroke} />
        </div>
      </div>
      <div style={{ paddingTop: 10 }}>
        <div style={{ fontSize: 11.5, color: T.muted2, fontWeight: 600, letterSpacing: "-.2px" }}>{p.brand}</div>
        <div style={{ fontSize: 13.5, fontWeight: 500, marginTop: 3, letterSpacing: "-.3px", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{p.name}</div>
        <div style={{ fontSize: 15, fontWeight: 800, marginTop: 6, letterSpacing: "-.4px" }}>{p.priceText}<span style={{ fontSize: 12, fontWeight: 600, color: T.muted, marginLeft: 1 }}>원</span></div>
      </div>
    </div>
  );

  const sectionTitle = `${petName}한테 어울려요`;
  const aiSubcopy = `AI가 ${petName}의 체형을 분석했어요`;
  const fitP = PRODUCTS[st.fitG];
  const fitOn = st.liked[st.fitG];
  const d = card(st.selProd);
  const likedIdx = Object.keys(st.liked).filter((k) => st.liked[Number(k)]).map(Number);
  const showTab = ["home", "category", "likes", "my"].includes(st.screen);

  const frame: React.CSSProperties = {
    width: 390, height: 844, margin: "0 auto", background: T.paper, borderRadius: 42,
    overflow: "hidden", position: "relative", fontFamily: "Pretendard, system-ui, sans-serif",
    color: T.ink, boxShadow: "0 30px 80px rgba(40,30,25,.18)", border: `1px solid ${T.line}`,
  };
  const headPad: React.CSSProperties = { paddingTop: 44, background: T.paper };

  return (
    <div style={frame}>
      {/* status bar */}
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, zIndex: 60, height: 44, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 24px", fontSize: 14, fontWeight: 600, letterSpacing: "-.3px", pointerEvents: "none" }}>
        <span>9:41</span>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <svg width="17" height="12" viewBox="0 0 17 12" fill={T.ink}><rect x="0" y="7" width="3" height="5" rx="1" /><rect x="4.5" y="4.5" width="3" height="7.5" rx="1" /><rect x="9" y="2" width="3" height="10" rx="1" /><rect x="13.5" y="0" width="3" height="12" rx="1" /></svg>
          <svg width="25" height="12" viewBox="0 0 25 12" fill="none"><rect x="1" y="1" width="20" height="10" rx="2.5" stroke={T.ink} strokeOpacity=".4" /><rect x="2.5" y="2.5" width="15" height="7" rx="1.3" fill={T.ink} /><rect x="22.5" y="4" width="1.6" height="4" rx=".8" fill={T.ink} fillOpacity=".4" /></svg>
        </div>
      </div>

      {/* ===== HOME ===== */}
      {st.screen === "home" && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", background: T.paper }}>
          <div style={headPad}>
            <div style={{ height: 52, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 22px" }}>
              <div style={{ display: "flex", alignItems: "baseline" }}>
                <span style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-.8px" }}>PetFit</span>
                <span style={{ width: 5, height: 5, borderRadius: "50%", background: T.accent, marginLeft: 2, alignSelf: "flex-end", marginBottom: 5 }} />
              </div>
              <div onClick={() => go("my")} style={{ width: 36, height: 36, cursor: "pointer" }}>
                <ImageSlot label="펫" circle />
              </div>
            </div>
            <div style={{ padding: "6px 22px 14px" }} onClick={() => go("category")}>
              <div style={{ display: "flex", alignItems: "center", gap: 10, height: 48, background: T.surface, border: `1px solid ${T.line}`, borderRadius: 14, padding: "0 15px", cursor: "pointer" }}>
                <Search />
                <span style={{ flex: 1, fontSize: 14.5, color: T.muted2, fontWeight: 500, letterSpacing: "-.3px" }}>우리 아이 옷 찾기</span>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={T.ink} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 8.5A1.5 1.5 0 0 1 4.5 7h2L8 5h8l1.5 2h2A1.5 1.5 0 0 1 21 8.5v9A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5z" /><circle cx="12" cy="13" r="3" /></svg>
              </div>
            </div>
          </div>
          <div className="pf-scroll" style={{ flex: 1, overflowY: "auto" }}>
            <div className="pf-scroll" style={{ display: "flex", gap: 8, overflowX: "auto", padding: "6px 22px" }}>
              {["전체", "상의", "하네스", "아우터"].map((l) => (
                <div key={l} style={chipStyle(st.chip === l)} onClick={() => set({ chip: l })}>{l}</div>
              ))}
            </div>
            <div style={{ margin: "12px 22px 6px", background: T.heroBg, borderRadius: 22, padding: "24px 22px", display: "flex", alignItems: "center", gap: 14, overflow: "hidden", cursor: "pointer" }} onClick={() => go("fit")}>
              <div style={{ flex: 1 }}>
                <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: "1.2px", color: T.heroLabel, textTransform: "uppercase" }}>AI 가상 피팅</span>
                <h2 style={{ margin: "11px 0 0", fontSize: 20, fontWeight: 800, lineHeight: 1.4, letterSpacing: "-.6px" }}>사진 한 장이면<br />우리 아이가 입은<br />모습이 바로 보여요</h2>
                <div style={{ marginTop: 18, display: "inline-flex", alignItems: "center", gap: 6, background: T.ink, color: "#fff", fontSize: 13.5, fontWeight: 700, padding: "11px 18px", borderRadius: 999, letterSpacing: "-.3px" }}>지금 입혀보기
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h13M13 6l6 6-6 6" /></svg>
                </div>
              </div>
              <div style={{ width: 104, height: 128, flexShrink: 0 }}><ImageSlot label="초코 사진" radius={18} /></div>
            </div>
            <div style={{ padding: "26px 22px 0", display: "flex", alignItems: "flex-end", justifyContent: "space-between" }}>
              <div>
                <h3 style={{ margin: 0, fontSize: 18, fontWeight: 800, letterSpacing: "-.5px" }}>{sectionTitle}</h3>
                <p style={{ margin: "6px 0 0", fontSize: 12.5, color: T.muted, fontWeight: 500, letterSpacing: "-.2px" }}>{aiSubcopy}</p>
              </div>
              <div style={{ fontSize: 13, color: T.muted, fontWeight: 600, cursor: "pointer" }} onClick={() => go("category")}>더보기</div>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "18px 14px", padding: "18px 22px 0" }}>
              {[0, 1, 2, 3].map((i) => <ProductCardView key={i} p={card(i)} />)}
            </div>
            <div style={{ height: 112 }} />
          </div>
        </div>
      )}

      {/* ===== CATEGORY ===== */}
      {st.screen === "category" && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", background: T.paper }}>
          <div style={headPad}>
            <div style={{ height: 52, display: "flex", alignItems: "center", gap: 10, padding: "0 16px" }}>
              <div onClick={() => go("home")} style={{ width: 36, height: 36, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}><Back /></div>
              <div style={{ flex: 1, display: "flex", alignItems: "center", gap: 9, height: 42, background: T.surface, border: `1px solid ${T.line}`, borderRadius: 13, padding: "0 14px" }}>
                <Search size={17} />
                <span style={{ flex: 1, fontSize: 14, color: T.muted2, fontWeight: 500, letterSpacing: "-.3px" }}>우리 아이 옷 찾기</span>
              </div>
            </div>
            <div className="pf-scroll" style={{ display: "flex", gap: 8, overflowX: "auto", padding: "4px 16px 14px" }}>
              {["전체", "상의", "하네스", "아우터", "신발", "액세서리"].map((l) => (
                <div key={l} style={chipStyle(st.catChip === l)} onClick={() => set({ catChip: l })}>{l}</div>
              ))}
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "10px 22px 6px" }}>
            <span style={{ fontSize: 13, color: T.muted, fontWeight: 600 }}>전체 {PRODUCTS.length}개</span>
            <div style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 13, fontWeight: 700, letterSpacing: "-.2px", cursor: "pointer" }}>AI 핏 높은순
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={T.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M6 9l6 6 6-6" /></svg>
            </div>
          </div>
          <div className="pf-scroll" style={{ flex: 1, overflowY: "auto" }}>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "18px 14px", padding: "12px 22px 0" }}>
              {[0, 1, 2, 3, 4, 5].map((i) => <ProductCardView key={i} p={card(i)} />)}
            </div>
            <div style={{ height: 112 }} />
          </div>
        </div>
      )}

      {/* ===== AI FITTING ===== */}
      {st.screen === "fit" && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", background: T.paper }}>
          <div style={{ paddingTop: 44 }}>
            <div style={{ height: 52, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 16px" }}>
              <div onClick={() => set({ screen: st.prev || "home" })} style={{ width: 36, height: 36, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}><Back /></div>
              <span style={{ fontSize: 16, fontWeight: 800, letterSpacing: "-.4px" }}>AI 피팅</span>
              <div style={{ width: 36, height: 36, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={T.ink} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3" /></svg>
              </div>
            </div>
          </div>
          <div className="pf-scroll" style={{ flex: 1, overflowY: "auto" }}>
            <div style={{ margin: "6px 22px 0", borderRadius: 22, position: "relative", overflow: "hidden", aspectRatio: "4 / 5", background: T.soft, border: `1px solid ${T.line}` }}>
              <ImageSlot label="초코 전신 사진" />
              <span style={{ position: "absolute", top: 14, left: 14, background: "rgba(255,255,255,.94)", color: T.ink, fontSize: 11, fontWeight: 700, padding: "6px 11px", borderRadius: 999, letterSpacing: "-.2px" }}>피팅 적용됨</span>
            </div>
            <div style={{ margin: "18px 22px 0", display: "flex", gap: 10 }}>
              <div style={{ flex: 1, background: "#fff", border: `1px solid ${T.line}`, borderRadius: 15, padding: "14px 16px" }}>
                <div style={{ fontSize: 11.5, color: T.muted, fontWeight: 600 }}>AI 핏 스코어</div>
                <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-.5px", marginTop: 3, color: T.accent }}>{fitP.fit}<span style={{ fontSize: 13 }}>%</span></div>
              </div>
              <div style={{ flex: 1, background: "#fff", border: `1px solid ${T.line}`, borderRadius: 15, padding: "14px 16px" }}>
                <div style={{ fontSize: 11.5, color: T.muted, fontWeight: 600 }}>추천 사이즈</div>
                <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-.5px", marginTop: 3 }}>{st.size}<span style={{ fontSize: 12, color: T.muted, fontWeight: 600, marginLeft: 5 }}>가슴 42cm</span></div>
              </div>
            </div>
            <div style={{ padding: "24px 22px 0", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <span style={{ fontSize: 15, fontWeight: 800, letterSpacing: "-.3px" }}>입혀볼 옷</span>
              <span style={{ fontSize: 12.5, color: T.muted, fontWeight: 600 }}>{fitP.brand} {fitP.name}</span>
            </div>
            <div className="pf-scroll" style={{ display: "flex", gap: 10, overflowX: "auto", padding: "14px 22px 4px" }}>
              {PRODUCTS.map((_, i) => (
                <div key={i} onClick={() => set({ fitG: i })} style={{ flexShrink: 0, borderRadius: 14, padding: 3, cursor: "pointer", border: `2px solid ${st.fitG === i ? T.accent : "transparent"}` }}>
                  <div style={{ width: 60, height: 60 }}><ImageSlot label="옷" radius={12} /></div>
                </div>
              ))}
            </div>
            <div style={{ margin: "20px 22px 0", background: "#fff", border: `1px solid ${T.line}`, borderRadius: 16, padding: "16px 18px" }}>
              <div style={{ fontSize: 13, fontWeight: 800, letterSpacing: "-.3px" }}>AI 핏 분석</div>
              <p style={{ margin: "9px 0 0", fontSize: 13, lineHeight: 1.65, color: T.sub, fontWeight: 500, letterSpacing: "-.2px" }}>초코의 체형에는 <b style={{ color: T.ink }}>{st.size} 사이즈</b>가 가장 잘 맞아요. 목둘레가 여유로워 활동성이 좋고, 어깨선이 자연스럽게 떨어집니다.</p>
            </div>
            <div style={{ height: 118 }} />
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, padding: "14px 22px 30px", background: T.paper, borderTop: `1px solid ${T.line}`, display: "flex", gap: 11 }}>
            <button onClick={() => toggle(st.fitG)} style={{ width: 52, height: 52, borderRadius: 15, border: `1px solid ${T.line}`, background: "#fff", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <Heart size={22} fill={fitOn ? T.accent : "none"} stroke={fitOn ? T.accent : T.ink} />
            </button>
            <button onClick={() => setSt((s) => ({ ...s, screen: "detail", prev: "fit", selProd: s.fitG }))} style={{ flex: 1, height: 52, borderRadius: 15, border: "none", cursor: "pointer", fontFamily: "inherit", fontSize: 15, fontWeight: 800, color: "#fff", letterSpacing: "-.3px", background: T.accent }}>이 옷 담기 · {won(fitP.price)}원</button>
          </div>
        </div>
      )}

      {/* ===== DETAIL ===== */}
      {st.screen === "detail" && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", background: T.paper }}>
          <div className="pf-scroll" style={{ flex: 1, overflowY: "auto" }}>
            <div style={{ position: "relative", aspectRatio: "1 / 1", background: T.soft }}>
              <ImageSlot label="상품 사진" />
              <div style={{ position: "absolute", top: 44, left: 14, right: 14, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <button onClick={() => set({ screen: st.prev || "home" })} style={{ width: 38, height: 38, borderRadius: "50%", background: "rgba(255,255,255,.94)", border: "none", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}><Back /></button>
                <button style={{ width: 38, height: 38, borderRadius: "50%", background: "rgba(255,255,255,.94)", border: "none", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={T.ink} strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round"><path d="M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7M16 6l-4-4-4 4M12 2v13" /></svg>
                </button>
              </div>
            </div>
            <div style={{ padding: "20px 22px 0" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <span style={{ fontSize: 13, color: T.muted2, fontWeight: 700, letterSpacing: "-.2px" }}>{d.brand}</span>
                <div style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 12.5, color: T.sub, fontWeight: 600 }}>
                  <svg width="13" height="13" viewBox="0 0 24 24" fill={T.ink}><path d="M12 2l2.9 6.3 6.9.7-5.1 4.7 1.4 6.8L12 17.6 5.9 20.5l1.4-6.8L2.2 9l6.9-.7z" /></svg>4.9 <span style={{ color: "#C4BDB3" }}>(312)</span>
                </div>
              </div>
              <h2 style={{ margin: "8px 0 0", fontSize: 21, fontWeight: 800, letterSpacing: "-.5px" }}>{d.name}</h2>
              <div style={{ marginTop: 11, display: "flex", alignItems: "baseline", gap: 8 }}>
                <span style={{ fontSize: 15, fontWeight: 800, color: T.accent }}>23%</span>
                <span style={{ fontSize: 24, fontWeight: 800, letterSpacing: "-.6px" }}>{d.priceText}<span style={{ fontSize: 15 }}>원</span></span>
              </div>
            </div>
            <div onClick={() => setSt((s) => ({ ...s, screen: "fit", prev: "detail", fitG: s.selProd }))} style={{ margin: "20px 22px 0", background: "#fff", border: `1px solid ${T.line}`, borderRadius: 16, padding: "15px 17px", display: "flex", alignItems: "center", gap: 13, cursor: "pointer" }}>
              <div style={{ width: 40, height: 40, borderRadius: 11, background: T.accentSoft, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><FitIcon /></div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 14, fontWeight: 800, letterSpacing: "-.3px" }}>{petName}한테 입혀보기</div>
                <div style={{ fontSize: 12, color: T.muted, fontWeight: 500, marginTop: 2 }}>AI가 우리 아이 사진에 바로 입혀드려요</div>
              </div>
              <ChevR size={19} stroke="#C4BDB3" w={2.2} />
            </div>
            <div style={{ padding: "26px 22px 0" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <span style={{ fontSize: 15, fontWeight: 800, letterSpacing: "-.3px" }}>사이즈</span>
                <span style={{ fontSize: 12.5, fontWeight: 700, color: T.accent }}>AI 추천 {st.size}</span>
              </div>
              <div style={{ display: "flex", gap: 9, marginTop: 13 }}>
                {["S", "M", "L", "XL"].map((l) => {
                  const on = st.size === l;
                  return (
                    <div key={l} onClick={() => set({ size: l })} style={{ flex: 1, textAlign: "center", padding: "12px 0", borderRadius: 12, fontSize: 14, fontWeight: 700, cursor: "pointer", letterSpacing: "-.2px", background: on ? T.ink : "#fff", color: on ? "#fff" : T.sub, border: `1px solid ${on ? T.ink : T.line}` }}>{l}</div>
                  );
                })}
              </div>
            </div>
            <div style={{ padding: "26px 22px 0" }}>
              <span style={{ fontSize: 15, fontWeight: 800, letterSpacing: "-.3px" }}>상품 정보</span>
              <p style={{ margin: "12px 0 0", fontSize: 13.5, lineHeight: 1.7, color: T.sub, fontWeight: 500, letterSpacing: "-.2px" }}>부드러운 극세사 안감으로 보온성이 뛰어난 데일리 아이템. 목과 가슴 둘레를 넉넉하게 디자인해 답답함 없이 편안하게 착용할 수 있어요. 산책부터 실내 생활까지 두루 활용하기 좋습니다.</p>
              <div style={{ marginTop: 16, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                <div style={{ background: "#fff", border: `1px solid ${T.line}`, borderRadius: 13, padding: "13px 15px" }}><div style={{ fontSize: 11.5, color: T.muted, fontWeight: 600 }}>소재</div><div style={{ fontSize: 13.5, fontWeight: 700, marginTop: 3 }}>극세사 / 폴리</div></div>
                <div style={{ background: "#fff", border: `1px solid ${T.line}`, borderRadius: 13, padding: "13px 15px" }}><div style={{ fontSize: 11.5, color: T.muted, fontWeight: 600 }}>사이즈 범위</div><div style={{ fontSize: 13.5, fontWeight: 700, marginTop: 3 }}>S · M · L · XL</div></div>
              </div>
            </div>
            <div style={{ height: 118 }} />
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, padding: "12px 22px 30px", background: T.paper, borderTop: `1px solid ${T.line}`, display: "flex", gap: 11, alignItems: "center" }}>
            <button onClick={d.onLike} style={{ width: 52, height: 52, borderRadius: 15, border: `1px solid ${T.line}`, background: "#fff", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><Heart size={23} fill={d.heartFill} stroke={d.heartStroke} /></button>
            <button style={{ flex: 1, height: 52, borderRadius: 15, border: "none", cursor: "pointer", fontFamily: "inherit", fontSize: 15.5, fontWeight: 800, color: "#fff", letterSpacing: "-.3px", background: T.ink }}>장바구니 담기</button>
          </div>
        </div>
      )}

      {/* ===== LIKES ===== */}
      {st.screen === "likes" && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", background: T.paper }}>
          <div style={{ paddingTop: 44 }}>
            <div style={{ height: 56, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 22px" }}>
              <span style={{ fontSize: 21, fontWeight: 800, letterSpacing: "-.5px" }}>좋아요</span>
              <span style={{ fontSize: 13, color: T.muted, fontWeight: 600 }}>{likedIdx.length}개 저장됨</span>
            </div>
          </div>
          <div className="pf-scroll" style={{ flex: 1, overflowY: "auto" }}>
            {likedIdx.length > 0 ? (
              <>
                <div style={{ margin: "8px 22px 0", background: "#fff", border: `1px solid ${T.line}`, borderRadius: 15, padding: "14px 16px", display: "flex", alignItems: "center", gap: 12 }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: T.accentSoft, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={T.accent} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 19V5M5 12l7-7 7 7" /></svg>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 800, letterSpacing: "-.3px" }}>2개 상품 가격이 내려갔어요</div>
                    <div style={{ fontSize: 12, color: T.muted, fontWeight: 500, marginTop: 1 }}>지금 담으면 최대 23% 할인</div>
                  </div>
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "18px 14px", padding: "18px 22px 0" }}>
                  {likedIdx.map((i) => <ProductCardView key={i} p={card(i)} badge={false} />)}
                </div>
              </>
            ) : (
              <div style={{ padding: "90px 40px", textAlign: "center" }}>
                <div style={{ width: 60, height: 60, borderRadius: 18, background: T.soft, margin: "0 auto", display: "flex", alignItems: "center", justifyContent: "center" }}><Heart size={28} fill="none" stroke="#C4BDB3" /></div>
                <p style={{ margin: "18px 0 0", fontSize: 14, color: T.muted, fontWeight: 600 }}>아직 좋아요한 상품이 없어요</p>
              </div>
            )}
            <div style={{ height: 112 }} />
          </div>
        </div>
      )}

      {/* ===== MY ===== */}
      {st.screen === "my" && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", background: T.paper }}>
          <div className="pf-scroll" style={{ flex: 1, overflowY: "auto" }}>
            <div style={{ padding: "44px 22px 24px" }}>
              <div style={{ height: 52, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <span style={{ fontSize: 21, fontWeight: 800, letterSpacing: "-.5px" }}>마이</span>
                <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke={T.ink} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z" /></svg>
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 14, marginTop: 10 }}>
                <div style={{ width: 60, height: 60, flexShrink: 0 }}><ImageSlot label="초코" circle /></div>
                <div style={{ flex: 1 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                    <span style={{ fontSize: 18, fontWeight: 800, letterSpacing: "-.4px" }}>초코</span>
                    <span style={{ fontSize: 11, fontWeight: 700, color: T.sub, background: T.soft, padding: "3px 9px", borderRadius: 999 }}>말티즈 · 3.2kg</span>
                  </div>
                  <div style={{ fontSize: 12.5, color: T.muted, fontWeight: 500, marginTop: 5 }}>가슴 42cm · 목 24cm · 등길이 30cm</div>
                </div>
                <div style={{ width: 32, height: 32, borderRadius: "50%", background: "#fff", border: `1px solid ${T.line}`, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={T.sub} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" /></svg>
                </div>
              </div>
              <div style={{ display: "flex", gap: 14, marginTop: 20 }}>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                  <div style={{ width: 50, height: 50, borderRadius: "50%", border: `2px solid ${T.accent}`, padding: 2 }}><ImageSlot label="초코" circle /></div>
                  <span style={{ fontSize: 11, fontWeight: 700 }}>초코</span>
                </div>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                  <div style={{ width: 50, height: 50, borderRadius: "50%", border: `1px solid ${T.line}`, padding: 2 }}><ImageSlot label="콩이" circle /></div>
                  <span style={{ fontSize: 11, fontWeight: 600, color: T.muted }}>콩이</span>
                </div>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                  <div style={{ width: 50, height: 50, borderRadius: "50%", border: "1.5px dashed #D8D2CA", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#B3ABA1" strokeWidth="2" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
                  </div>
                  <span style={{ fontSize: 11, fontWeight: 600, color: T.muted }}>추가</span>
                </div>
              </div>
            </div>
            <div style={{ margin: "0 22px", background: "#fff", border: `1px solid ${T.line}`, borderRadius: 16, padding: "18px 0", display: "flex" }}>
              {[["7", "주문"], [String(likedIdx.length), "좋아요"], ["12", "AI 피팅"]].map(([n, l], i) => (
                <div key={l} style={{ flex: 1, textAlign: "center", borderRight: i < 2 ? `1px solid ${T.soft}` : "none" }}>
                  <div style={{ fontSize: 19, fontWeight: 800, letterSpacing: "-.4px" }}>{n}</div>
                  <div style={{ fontSize: 11.5, color: T.muted, fontWeight: 600, marginTop: 3 }}>{l}</div>
                </div>
              ))}
            </div>
            <div style={{ margin: "14px 22px 0", background: "#fff", border: `1px solid ${T.line}`, borderRadius: 16, overflow: "hidden" }}>
              {[["주문 내역", ""], ["AI 피팅 기록", "12회"], ["내가 쓴 리뷰", "4"], ["쿠폰함", "3장"], ["고객센터 · 설정", ""]].map(([label, meta], i, arr) => (
                <div key={label} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "15px 18px", cursor: "pointer", borderBottom: i < arr.length - 1 ? "1px solid #F1ECE6" : "none" }}>
                  <span style={{ fontSize: 14.5, fontWeight: 600, letterSpacing: "-.3px" }}>{label}</span>
                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <span style={{ fontSize: 13, color: T.muted, fontWeight: 600 }}>{meta}</span>
                    <ChevR />
                  </div>
                </div>
              ))}
            </div>
            <div style={{ height: 112 }} />
          </div>
        </div>
      )}

      {/* ===== bottom tab ===== */}
      {showTab && (
        <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, zIndex: 30, height: 82, background: "rgba(250,248,245,.94)", backdropFilter: "blur(14px)", borderTop: `1px solid ${T.line}`, display: "flex", alignItems: "flex-start", paddingTop: 11 }}>
          {([["home", "홈"], ["category", "카테고리"]] as [Screen, string][]).map(([key, label]) => (
            <div key={key} onClick={() => go(key)} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 4, cursor: "pointer", fontSize: 10, fontWeight: 700, letterSpacing: "-.2px", color: st.screen === key ? T.accent : "#B3ABA1" }}>
              {key === "home" ? (
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round"><path d="M3 10.5L12 4l9 6.5V19a1 1 0 0 1-1 1h-4v-6h-8v6H4a1 1 0 0 1-1-1z" /></svg>
              ) : (
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="4" width="7" height="7" rx="2" /><rect x="13" y="4" width="7" height="7" rx="2" /><rect x="4" y="13" width="7" height="7" rx="2" /><rect x="13" y="13" width="7" height="7" rx="2" /></svg>
              )}
              <span>{label}</span>
            </div>
          ))}
          <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center" }}>
            <div onClick={() => go("fit")} style={{ marginTop: -24, width: 54, height: 54, borderRadius: "50%", border: `4px solid ${T.paper}`, background: T.accent, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 6px 16px rgba(232,103,74,.32)" }}>
              <FitIcon size={24} stroke="#fff" />
            </div>
            <span style={{ fontSize: 10, fontWeight: 700, color: T.accent, marginTop: 4, letterSpacing: "-.2px" }}>AI 피팅</span>
          </div>
          {([["likes", "좋아요"], ["my", "마이"]] as [Screen, string][]).map(([key, label]) => (
            <div key={key} onClick={() => go(key)} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 4, cursor: "pointer", fontSize: 10, fontWeight: 700, letterSpacing: "-.2px", color: st.screen === key ? T.accent : "#B3ABA1" }}>
              {key === "likes" ? (
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round"><path d="M12 20.5C7 16.5 3.5 13.3 3.5 9.4 3.5 6.9 5.5 5 7.9 5c1.6 0 2.9.8 4.1 2.3C13.2 5.8 14.5 5 16.1 5c2.4 0 4.4 1.9 4.4 4.4 0 3.9-3.5 7.1-8.5 11.1z" /></svg>
              ) : (
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="8" r="3.6" /><path d="M5 20c0-3.6 3.1-6 7-6s7 2.4 7 6" /></svg>
              )}
              <span>{label}</span>
            </div>
          ))}
        </div>
      )}

      {/* home indicator */}
      <div style={{ position: "absolute", bottom: 7, left: "50%", transform: "translateX(-50%)", width: 128, height: 5, borderRadius: 3, background: T.ink, opacity: 0.16, zIndex: 50 }} />
    </div>
  );
}
