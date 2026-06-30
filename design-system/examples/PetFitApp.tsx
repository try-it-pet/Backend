import React, { useState, useEffect, useRef } from "react";
import {
  apiBase, fetchProducts, runTryOn, type TryOnResult, type Provider,
  setToken, getToken, fetchMe, fetchLikes, toggleLikeApi, addToCart, fetchStats,
  devLogin, kakaoLoginUrl, type User, type Stats,
} from "./api";

/**
 * Pawdy — 펫 전문 멀티샵 앱. 반려동물 프로필 기반 추천 + AI 가상 피팅(착용·배치).
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

type Product = { id: number; brand: string; name: string; price: number; fit: number; category: string; species: string; fittable: boolean; ref_image?: string | null };

const CATEGORIES: { key: string; label: string; subs: string[] }[] = [
  { key: "care", label: "데일리케어", subs: ["샴푸", "브러쉬", "덴탈케어", "위생용품", "사료", "간식", "영양제"] },
  { key: "fashion", label: "패션·스타일", subs: ["의류", "하네스", "리드줄", "액세서리", "코스튬"] },
  { key: "active", label: "액티브·아웃도어", subs: ["산책용품", "유모차", "이동가방", "카시트", "장난감", "훈련용품"] },
  { key: "wellness", label: "헬스·웰니스", subs: ["건강보조제", "관절케어", "피부케어", "체중관리"] },
  { key: "home", label: "홈·인테리어", subs: ["캣타워", "숨숨집", "쿠션", "하우스", "스크래처", "터널", "급수기"] },
];
const CAT_LABEL: Record<string, string> = Object.fromEntries(CATEGORIES.map((c) => [c.key, c.label]));

// 백엔드 미연결 시 폴백 (실제 카탈로그는 GET /products). 펫 전문 멀티샵.
const PRODUCTS: Product[] = [
  { id: 0, brand: "무무펫", name: "코지 니트 스웨터", price: 28000, fit: 96, category: "fashion", species: "dog", fittable: true },
  { id: 1, brand: "도그웨어", name: "체크 하네스 세트", price: 34000, fit: 89, category: "fashion", species: "dog", fittable: true },
  { id: 2, brand: "펫코", name: "경량 패딩 베스트", price: 42000, fit: 94, category: "fashion", species: "dog", fittable: true },
  { id: 3, brand: "모카독", name: "데일리 후디", price: 25000, fit: 92, category: "fashion", species: "dog", fittable: true },
  { id: 4, brand: "무무펫", name: "윈터 울 코트", price: 48000, fit: 90, category: "fashion", species: "dog", fittable: true },
  { id: 5, brand: "캣무드", name: "니트 캣 코스튬", price: 21000, fit: 88, category: "fashion", species: "cat", fittable: true },
  { id: 6, brand: "퓨어펫", name: "약산성 저자극 샴푸", price: 16000, fit: 91, category: "care", species: "all", fittable: false },
  { id: 7, brand: "치카독", name: "덴탈케어 껌 30개입", price: 9000, fit: 87, category: "care", species: "dog", fittable: false },
  { id: 8, brand: "네이처바울", name: "자연식 연어 사료 2kg", price: 38000, fit: 95, category: "care", species: "all", fittable: false },
  { id: 9, brand: "리얼바이트", name: "동결건조 닭가슴살 간식", price: 14000, fit: 90, category: "care", species: "all", fittable: false },
  { id: 10, brand: "워크업", name: "가벼운 산책 리드줄", price: 22000, fit: 89, category: "active", species: "dog", fittable: false },
  { id: 11, brand: "트래블펫", name: "반려동물 4륜 유모차", price: 159000, fit: 92, category: "active", species: "all", fittable: true },
  { id: 12, brand: "플레이펫", name: "노즈워크 코끼리 장난감", price: 18000, fit: 88, category: "active", species: "dog", fittable: false },
  { id: 13, brand: "헬스독", name: "관절 글루코사민 영양제", price: 32000, fit: 93, category: "wellness", species: "dog", fittable: false },
  { id: 14, brand: "스킨펫", name: "피부 보습 미스트", price: 15000, fit: 86, category: "wellness", species: "all", fittable: false },
  { id: 15, brand: "코지캣", name: "3단 원목 캣타워", price: 89000, fit: 94, category: "home", species: "cat", fittable: true },
  { id: 16, brand: "하우스펫", name: "포근 숨숨집 텐트", price: 26000, fit: 90, category: "home", species: "all", fittable: true },
  { id: 17, brand: "워터펫", name: "자동 순환 급수기", price: 34000, fit: 88, category: "home", species: "all", fittable: false },
];
const won = (n: number) => n.toLocaleString("ko-KR");

// 목업 이미지: 상품은 이름에 맞는 키워드로 Flickr 검색(loremflickr), 펫은 placedog(강아지).
// 로드 실패 시 라벨 박스로 폴백.
const PROD_KW: Record<number, string> = {
  0: "dog,sweater", 1: "dog,harness", 2: "dog,coat", 3: "dog,hoodie", 4: "dog,coat", 5: "cat,costume",
  6: "dog,bath", 7: "dog,chewing", 8: "dog,food", 9: "dog,treat",
  10: "dog,leash", 11: "dog,stroller", 12: "dog,toy",
  13: "dog,vitamins", 14: "dog,grooming",
  15: "cat,tree", 16: "dog,bed", 17: "cat,fountain",
};
const prodImg = (id: number, w = 600, h = 600) =>
  `https://loremflickr.com/${w}/${h}/${PROD_KW[id] ?? "pet"}?lock=${id + 1}`;
const petImg = (n: number, w = 400, h = 500) => `https://placedog.net/${w}/${h}?id=${n}`;

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
const ImageSlot = ({ label, src, radius = 0, circle = false, style }: { label: string; src?: string; radius?: number; circle?: boolean; style?: React.CSSProperties }) => (
  <div
    style={{
      position: "relative",
      width: "100%",
      height: "100%",
      background: T.soft,
      borderRadius: circle ? "50%" : radius,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      overflow: "hidden",
      ...style,
    }}
  >
    <span style={{ fontSize: 10.5, color: T.muted2, fontWeight: 600, letterSpacing: "-.2px", textAlign: "center", padding: 4 }}>{label}</span>
    {src && (
      <img
        src={src}
        alt={label}
        loading="lazy"
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }}
        onError={(e) => { e.currentTarget.style.display = "none"; }}
      />
    )}
  </div>
);

export function PetFitApp({ petName = "초코" }: { petName?: string }) {
  const [st, setSt] = useState<{
    screen: Screen; prev: Screen; chip: string; catChip: string; species: string; size: string; fitG: number; selProd: number; liked: Liked;
  }>({
    screen: "home", prev: "home", chip: "all", catChip: "all", species: "all", size: "M", fitG: 0, selProd: 0,
    liked: { 0: false, 1: true, 2: false, 3: true, 4: false, 5: false },
  });
  const [recent, setRecent] = useState<number[]>([]); // 최근 본 상품 (찜 화면)

  // 백엔드 연동: 상품은 API 에서 로드(실패 시 로컬 폴백), AI 피팅은 /tryon 잡으로 처리
  const [products, setProducts] = useState<Product[]>(PRODUCTS);
  const [fit, setFit] = useState<{ loading: boolean; result: TryOnResult | null; error: boolean; msg: string }>({
    loading: false, result: null, error: false, msg: "",
  });
  const [provider, setProvider] = useState<Provider>("mock"); // mock=키 불필요 / openai=gpt-image-2 / replicate
  const [petPhoto, setPetPhoto] = useState<File | null>(null);
  const [petPhotoUrl, setPetPhotoUrl] = useState<string | null>(null);
  const fitReq = useRef(0);
  const fileRef = useRef<HTMLInputElement | null>(null);

  const onPickPhoto = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    setPetPhoto(f);
    setPetPhotoUrl((prev) => { if (prev) URL.revokeObjectURL(prev); return URL.createObjectURL(f); });
  };

  // ── 인증 ──
  const [user, setUser] = useState<User | null>(null);
  const [stats, setStats] = useState<Stats | null>(null);
  const [toast, setToast] = useState("");
  const showToast = (m: string) => { setToast(m); window.setTimeout(() => setToast(""), 1800); };

  const loadLikes = () =>
    fetchLikes().then((ids) => {
      const liked: Liked = {}; ids.forEach((id) => { liked[id] = true; });
      setSt((s) => ({ ...s, liked }));
    }).catch(() => {});

  useEffect(() => {
    // 카카오 리다이렉트(?token=) 처리
    const params = new URLSearchParams(window.location.search);
    const t = params.get("token");
    if (t) { setToken(t); window.history.replaceState({}, "", window.location.pathname); }
    if (getToken()) fetchMe().then((u) => { setUser(u); if (u) loadLikes(); }).catch(() => {});
  }, []);

  useEffect(() => { if (st.screen === "my" && getToken()) fetchStats().then(setStats).catch(() => {}); }, [st.screen, user]);

  const doDevLogin = async () => {
    try {
      const { token, user: u } = await devLogin();
      setToken(token); setUser(u); showToast(`${u.nickname}님 환영해요`); loadLikes();
    } catch {
      // 데모(백엔드 미배포): 클라이언트 목업 로그인
      setUser({ id: 0, provider: "dev", nickname: "초코집사", profile_image: null, kakao_id: null });
      showToast("초코집사님 환영해요 (데모)");
    }
  };
  const doKakaoLogin = () => { window.location.href = kakaoLoginUrl(); };
  const logout = () => { setToken(null); setUser(null); setStats(null); setSt((s) => ({ ...s, liked: {} })); showToast("로그아웃됐어요"); };

  const addCart = async (productId: number, size: string) => {
    if (!getToken()) { showToast("로그인이 필요해요"); return; }
    try { await addToCart(productId, size); showToast("장바구니에 담았어요"); }
    catch { showToast("담기 실패"); }
  };

  useEffect(() => {
    fetchProducts().then(setProducts).catch(() => {/* 백엔드 미연결 시 로컬 더미 유지 */});
  }, []);

  useEffect(() => {
    if (st.screen !== "fit") return;
    const product = products[st.fitG];
    if (!product) return;
    // 실제 모델(openai/replicate)은 펫 사진이 필요. mock 은 사진 없이도 동작.
    if (provider !== "mock" && !petPhoto) {
      setFit({ loading: false, result: null, error: false, msg: "펫 사진을 추가하면 AI가 입혀드려요" });
      return;
    }
    const reqId = ++fitReq.current;
    setFit({ loading: true, result: null, error: false, msg: "" });
    runTryOn({ productId: product.id, size: st.size, provider, petImage: petPhoto ?? undefined })
      .then((job) => {
        if (fitReq.current !== reqId) return; // 최신 요청만 반영(가먼트/모델 빠른 전환 대비)
        if (job.status === "done" && job.result) setFit({ loading: false, result: job.result, error: false, msg: "" });
        else setFit({ loading: false, result: null, error: true, msg: job.error || "생성 실패" });
      })
      .catch(() => {
        if (fitReq.current !== reqId) return;
        // 데모(백엔드 미배포): 클라이언트 목업 결과로 화면을 채운다
        setFit({
          loading: false, error: false, msg: "",
          result: { image_url: "", fit_score: product.fit, recommended_size: st.size,
            analysis: `${petName}의 체형에는 ${st.size} 사이즈가 잘 맞아요. (데모 미리보기)` },
        });
      });
  }, [st.screen, st.fitG, st.size, products, provider, petPhoto]);

  const set = (patch: Partial<typeof st>) => setSt((s) => ({ ...s, ...patch }));
  const go = (screen: Screen) => setSt((s) => ({ ...s, screen, prev: s.screen }));
  const toggle = (i: number) => {
    setSt((s) => ({ ...s, liked: { ...s.liked, [i]: !s.liked[i] } })); // 낙관적
    if (getToken()) {
      toggleLikeApi(products[i].id)
        .then((res) => {
          const liked: Liked = {}; res.likedIds.forEach((id) => { liked[id] = true; });
          setSt((s) => ({ ...s, liked }));
        })
        .catch(() => {/* 낙관적 상태 유지 */});
    }
  };

  // 상품 이미지: 실제 상품컷(ref_image, 백엔드 정적)이 있으면 그걸, 없으면 키워드 목업
  const imgFor = (id: number) => {
    const p = products[id];
    return p && p.ref_image ? `${apiBase}${p.ref_image}` : prodImg(id);
  };

  const card = (i: number) => {
    const p = products[i];
    const on = st.liked[i];
    return {
      i, brand: p.brand, name: p.name, priceText: won(p.price), showBadge: p.fit >= 93,
      heartFill: on ? T.accent : "none", heartStroke: on ? T.accent : T.ink,
      onOpen: () => {
        setRecent((r) => [i, ...r.filter((x) => x !== i)].slice(0, 8));
        setSt((s) => ({ ...s, screen: "detail", prev: s.screen, selProd: i }));
      },
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
        <ImageSlot label="상품 사진" src={imgFor(p.i)} />
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
  const fitP = products[st.fitG];
  const fitScore = fit.result?.fit_score ?? fitP.fit;
  const fitRecSize = fit.result?.recommended_size ?? st.size;
  const fitOn = st.liked[st.fitG];
  const d = card(st.selProd);
  const dProd = products[st.selProd];
  const fitVerb = dProd?.category === "home" ? "배치해보기" : "입혀보기";
  const likedIdx = Object.keys(st.liked).filter((k) => st.liked[Number(k)]).map(Number);
  const showTab = ["home", "category", "likes", "my"].includes(st.screen);

  const matchesSpecies = (p: Product) => st.species === "all" || p.species === st.species || p.species === "all";
  const catIdx = products.map((_, i) => i).filter((i) => (st.catChip === "all" || products[i].category === st.catChip) && matchesSpecies(products[i]));
  const homeIdx = (st.chip === "all"
    ? [0, 8, 15, 13, 2, 9]
    : products.map((_, i) => i).filter((i) => products[i].category === st.chip)
  ).filter((i) => i < products.length).slice(0, 6);
  const selectedCat = CATEGORIES.find((c) => c.key === st.catChip);

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
                <span style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-.8px" }}>Pawdy</span>
                <span style={{ width: 5, height: 5, borderRadius: "50%", background: T.accent, marginLeft: 2, alignSelf: "flex-end", marginBottom: 5 }} />
              </div>
              <div onClick={() => go("my")} style={{ width: 36, height: 36, cursor: "pointer" }}>
                <ImageSlot label="펫" circle src={petImg(7)} />
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
              {[{ key: "all", label: "전체" }, ...CATEGORIES].map((c) => (
                <div key={c.key} style={chipStyle(st.chip === c.key)} onClick={() => set({ chip: c.key })}>{c.label}</div>
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
              <div style={{ width: 104, height: 128, flexShrink: 0 }}><ImageSlot label="초코 사진" radius={18} src={petImg(1)} /></div>
            </div>
            <div style={{ padding: "26px 22px 0", display: "flex", alignItems: "flex-end", justifyContent: "space-between" }}>
              <div>
                <h3 style={{ margin: 0, fontSize: 18, fontWeight: 800, letterSpacing: "-.5px" }}>{sectionTitle}</h3>
                <p style={{ margin: "6px 0 0", fontSize: 12.5, color: T.muted, fontWeight: 500, letterSpacing: "-.2px" }}>{aiSubcopy}</p>
              </div>
              <div style={{ fontSize: 13, color: T.muted, fontWeight: 600, cursor: "pointer" }} onClick={() => go("category")}>더보기</div>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "18px 14px", padding: "18px 22px 0" }}>
              {homeIdx.map((i) => <ProductCardView key={i} p={card(i)} />)}
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
            <div className="pf-scroll" style={{ display: "flex", gap: 8, overflowX: "auto", padding: "4px 16px 12px" }}>
              {[{ key: "all", label: "전체" }, ...CATEGORIES].map((c) => (
                <div key={c.key} style={chipStyle(st.catChip === c.key)} onClick={() => set({ catChip: c.key })}>{c.label}</div>
              ))}
            </div>
          </div>
          {selectedCat && (
            <div className="pf-scroll" style={{ display: "flex", gap: 7, overflowX: "auto", padding: "2px 22px 8px" }}>
              {selectedCat.subs.map((s) => (
                <span key={s} style={{ flexShrink: 0, fontSize: 12, color: T.sub, fontWeight: 600, background: T.soft, padding: "6px 12px", borderRadius: 999, whiteSpace: "nowrap" }}>{s}</span>
              ))}
            </div>
          )}
          <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "6px 22px 4px" }}>
            {[{ key: "all", label: "전체" }, { key: "dog", label: "강아지" }, { key: "cat", label: "고양이" }].map((sp) => {
              const on = st.species === sp.key;
              return (
                <button key={sp.key} onClick={() => set({ species: sp.key })} style={{ fontSize: 12, fontWeight: 700, padding: "6px 12px", borderRadius: 999, cursor: "pointer", background: on ? T.accentSoft : T.surface, color: on ? T.accent : T.sub, border: `1px solid ${on ? T.accent : T.line}` }}>{sp.label}</button>
              );
            })}
            <span style={{ marginLeft: "auto", fontSize: 13, color: T.muted, fontWeight: 600 }}>{catIdx.length}개</span>
          </div>
          <div className="pf-scroll" style={{ flex: 1, overflowY: "auto" }}>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "18px 14px", padding: "12px 22px 0" }}>
              {catIdx.map((i) => <ProductCardView key={i} p={card(i)} />)}
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
            <input ref={fileRef} type="file" accept="image/*" onChange={onPickPhoto} style={{ display: "none" }} />
            <div style={{ display: "flex", gap: 6, alignItems: "center", padding: "8px 22px 2px" }}>
              <span style={{ fontSize: 11, color: T.muted, fontWeight: 600 }}>AI 모델</span>
              {(["mock", "openai", "replicate"] as Provider[]).map((pv) => {
                const on = provider === pv;
                return (
                  <button key={pv} onClick={() => setProvider(pv)} style={{ fontSize: 11, fontWeight: 600, padding: "5px 10px", borderRadius: 999, cursor: "pointer", background: on ? T.ink : T.surface, color: on ? "#fff" : T.sub, border: `1px solid ${on ? T.ink : T.line}` }}>
                    {pv === "openai" ? "gpt-image-2" : pv}
                  </button>
                );
              })}
            </div>
            <div style={{ margin: "8px 22px 0", borderRadius: 22, position: "relative", overflow: "hidden", aspectRatio: "4 / 5", background: T.soft, border: `1px solid ${T.line}` }}>
              {fit.loading ? (
                <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
                  <div style={{ width: 44, height: 44, borderRadius: "50%", border: `3px solid ${T.line}`, borderTopColor: T.accent, animation: "pf-spin 0.8s linear infinite" }} />
                  <span style={{ fontSize: 13, color: T.sub, fontWeight: 600 }}>AI가 {petName}에게 입히는 중…</span>
                </div>
              ) : fit.result ? (
                fit.result.image_url ? (
                  <img src={fit.result.image_url.startsWith("http") ? fit.result.image_url : apiBase + fit.result.image_url} alt="AI 피팅 결과" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
                ) : petPhotoUrl ? (
                  <img src={petPhotoUrl} alt="AI 피팅 결과" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
                ) : (
                  <ImageSlot label="AI 피팅 결과 미리보기" />
                )
              ) : petPhotoUrl ? (
                <img src={petPhotoUrl} alt="펫 사진" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", display: "block" }} />
              ) : (
                <button onClick={() => fileRef.current?.click()} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10, background: "none", border: "none", cursor: "pointer" }}>
                  <div style={{ width: 52, height: 52, borderRadius: "50%", background: T.surface, border: `1px solid ${T.line}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={T.accent} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 8.5A1.5 1.5 0 0 1 4.5 7h2L8 5h8l1.5 2h2A1.5 1.5 0 0 1 21 8.5v9A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5z" /><circle cx="12" cy="13" r="3" /></svg>
                  </div>
                  <span style={{ fontSize: 13, color: T.sub, fontWeight: 600 }}>{petName} 사진 추가</span>
                  {fit.msg && <span style={{ fontSize: 11, color: T.muted }}>{fit.msg}</span>}
                </button>
              )}
              {fit.result && (
                <span style={{ position: "absolute", top: 14, left: 14, background: "rgba(255,255,255,.94)", color: T.ink, fontSize: 11, fontWeight: 700, padding: "6px 11px", borderRadius: 999, letterSpacing: "-.2px" }}>피팅 적용됨</span>
              )}
              {petPhotoUrl && !fit.result && !fit.loading && (
                <button onClick={() => fileRef.current?.click()} style={{ position: "absolute", bottom: 12, right: 12, background: "rgba(26,23,20,.7)", color: "#fff", fontSize: 11, fontWeight: 600, padding: "6px 11px", borderRadius: 999, border: "none", cursor: "pointer" }}>사진 바꾸기</button>
              )}
              {fit.error && (
                <span style={{ position: "absolute", bottom: 12, left: 12, right: 12, background: "rgba(26,23,20,.78)", color: "#fff", fontSize: 11, padding: "7px 11px", borderRadius: 10 }}>{fit.msg}</span>
              )}
            </div>
            <div style={{ margin: "18px 22px 0", display: "flex", gap: 10 }}>
              <div style={{ flex: 1, background: "#fff", border: `1px solid ${T.line}`, borderRadius: 15, padding: "14px 16px" }}>
                <div style={{ fontSize: 11.5, color: T.muted, fontWeight: 600 }}>AI 핏 스코어</div>
                <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-.5px", marginTop: 3, color: T.accent }}>{fit.loading ? "…" : fitScore}<span style={{ fontSize: 13 }}>%</span></div>
              </div>
              <div style={{ flex: 1, background: "#fff", border: `1px solid ${T.line}`, borderRadius: 15, padding: "14px 16px" }}>
                <div style={{ fontSize: 11.5, color: T.muted, fontWeight: 600 }}>추천 사이즈</div>
                <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-.5px", marginTop: 3 }}>{fitRecSize}<span style={{ fontSize: 12, color: T.muted, fontWeight: 600, marginLeft: 5 }}>가슴 42cm</span></div>
              </div>
            </div>
            <div style={{ padding: "24px 22px 0", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <span style={{ fontSize: 15, fontWeight: 800, letterSpacing: "-.3px" }}>입혀볼 옷</span>
              <span style={{ fontSize: 12.5, color: T.muted, fontWeight: 600 }}>{fitP.brand} {fitP.name}</span>
            </div>
            <div className="pf-scroll" style={{ display: "flex", gap: 10, overflowX: "auto", padding: "14px 22px 4px" }}>
              {products.map((_, i) => (
                <div key={i} onClick={() => set({ fitG: i })} style={{ flexShrink: 0, borderRadius: 14, padding: 3, cursor: "pointer", border: `2px solid ${st.fitG === i ? T.accent : "transparent"}` }}>
                  <div style={{ width: 60, height: 60 }}><ImageSlot label="옷" radius={12} src={imgFor(i)} /></div>
                </div>
              ))}
            </div>
            <div style={{ margin: "20px 22px 0", background: "#fff", border: `1px solid ${T.line}`, borderRadius: 16, padding: "16px 18px" }}>
              <div style={{ fontSize: 13, fontWeight: 800, letterSpacing: "-.3px" }}>AI 핏 분석</div>
              <p style={{ margin: "9px 0 0", fontSize: 13, lineHeight: 1.65, color: T.sub, fontWeight: 500, letterSpacing: "-.2px" }}>
                {fit.result
                  ? fit.result.analysis
                  : fit.loading
                  ? "AI가 체형을 분석하고 있어요…"
                  : `${petName}의 체형에는 ${fitRecSize} 사이즈가 가장 잘 맞아요.`}
              </p>
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
              <ImageSlot label="상품 사진" src={imgFor(d.i)} />
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
            {dProd?.fittable && (
              <div onClick={() => setSt((s) => ({ ...s, screen: "fit", prev: "detail", fitG: s.selProd }))} style={{ margin: "20px 22px 0", background: "#fff", border: `1px solid ${T.line}`, borderRadius: 16, padding: "15px 17px", display: "flex", alignItems: "center", gap: 13, cursor: "pointer" }}>
                <div style={{ width: 40, height: 40, borderRadius: 11, background: T.accentSoft, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><FitIcon /></div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 800, letterSpacing: "-.3px" }}>{dProd.category === "home" ? `우리 집에 ${fitVerb}` : `${petName}한테 ${fitVerb}`}</div>
                  <div style={{ fontSize: 12, color: T.muted, fontWeight: 500, marginTop: 2 }}>{dProd.category === "home" ? "AI가 우리 집 사진에 배치해드려요" : "AI가 우리 아이 사진에 바로 입혀드려요"}</div>
                </div>
                <ChevR size={19} stroke="#C4BDB3" w={2.2} />
              </div>
            )}
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
            <button onClick={() => addCart(d.i, st.size)} style={{ flex: 1, height: 52, borderRadius: 15, border: "none", cursor: "pointer", fontFamily: "inherit", fontSize: 15.5, fontWeight: 800, color: "#fff", letterSpacing: "-.3px", background: T.ink }}>장바구니 담기</button>
          </div>
        </div>
      )}

      {/* ===== LIKES ===== */}
      {st.screen === "likes" && (
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", background: T.paper }}>
          <div style={{ paddingTop: 44 }}>
            <div style={{ height: 56, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 22px" }}>
              <span style={{ fontSize: 21, fontWeight: 800, letterSpacing: "-.5px" }}>찜</span>
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
                <p style={{ margin: "18px 0 0", fontSize: 14, color: T.muted, fontWeight: 600 }}>아직 찜한 상품이 없어요</p>
              </div>
            )}
            {recent.length > 0 && (
              <div style={{ marginTop: 24 }}>
                <div style={{ padding: "0 22px 4px", fontSize: 16, fontWeight: 800, letterSpacing: "-.4px" }}>최근 본 상품</div>
                <div className="pf-scroll" style={{ display: "flex", gap: 12, overflowX: "auto", padding: "12px 22px 0" }}>
                  {recent.map((i) => (products[i] ? (
                    <div key={i} style={{ width: 116, flexShrink: 0 }}><ProductCardView p={card(i)} badge={false} /></div>
                  ) : null))}
                </div>
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
              {user ? (
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 8 }}>
                  <span style={{ fontSize: 13, color: T.sub, fontWeight: 600 }}>{user.nickname}님 · {user.provider === "kakao" ? "카카오" : "체험"}</span>
                  <button onClick={logout} style={{ fontSize: 12, fontWeight: 600, color: T.sub, background: T.surface, border: `1px solid ${T.line}`, borderRadius: 999, padding: "6px 12px", cursor: "pointer" }}>로그아웃</button>
                </div>
              ) : (
                <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
                  <button onClick={doKakaoLogin} style={{ flex: 1, height: 44, borderRadius: 12, border: "none", cursor: "pointer", background: "#FEE500", color: "#1A1714", fontSize: 14, fontWeight: 800, letterSpacing: "-.3px" }}>카카오로 로그인</button>
                  <button onClick={doDevLogin} style={{ height: 44, borderRadius: 12, border: `1px solid ${T.line}`, background: T.surface, color: T.sub, fontSize: 13, fontWeight: 700, padding: "0 14px", cursor: "pointer" }}>둘러보기</button>
                </div>
              )}
              <div style={{ display: "flex", alignItems: "center", gap: 14, marginTop: 16 }}>
                <div style={{ width: 60, height: 60, flexShrink: 0 }}><ImageSlot label="초코" circle src={petImg(1)} /></div>
                <div style={{ flex: 1 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                    <span style={{ fontSize: 18, fontWeight: 800, letterSpacing: "-.4px" }}>초코</span>
                    <span style={{ fontSize: 11, fontWeight: 700, color: T.sub, background: T.soft, padding: "3px 9px", borderRadius: 999 }}>말티즈 · 남아 · 3.2kg</span>
                  </div>
                  <div style={{ fontSize: 12.5, color: T.muted, fontWeight: 500, marginTop: 5 }}>가슴 42cm · 목 24cm · 등길이 30cm</div>
                </div>
                <div style={{ width: 32, height: 32, borderRadius: "50%", background: "#fff", border: `1px solid ${T.line}`, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={T.sub} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" /></svg>
                </div>
              </div>
              <div style={{ display: "flex", gap: 14, marginTop: 20 }}>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                  <div style={{ width: 50, height: 50, borderRadius: "50%", border: `2px solid ${T.accent}`, padding: 2 }}><ImageSlot label="초코" circle src={petImg(1)} /></div>
                  <span style={{ fontSize: 11, fontWeight: 700 }}>초코</span>
                </div>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                  <div style={{ width: 50, height: 50, borderRadius: "50%", border: `1px solid ${T.line}`, padding: 2 }}><ImageSlot label="콩이" circle src={petImg(2)} /></div>
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
              {[[String(stats ? stats.orders : 7), "주문"], [String(stats ? stats.likes : likedIdx.length), "좋아요"], [String(stats ? stats.fittings : 12), "AI 피팅"]].map(([n, l], i) => (
                <div key={l} style={{ flex: 1, textAlign: "center", borderRight: i < 2 ? `1px solid ${T.soft}` : "none" }}>
                  <div style={{ fontSize: 19, fontWeight: 800, letterSpacing: "-.4px" }}>{n}</div>
                  <div style={{ fontSize: 11.5, color: T.muted, fontWeight: 600, marginTop: 3 }}>{l}</div>
                </div>
              ))}
            </div>
            <div style={{ margin: "14px 22px 0", background: "#fff", border: `1px solid ${T.line}`, borderRadius: 16, overflow: "hidden" }}>
              {[["주문 내역", ""], ["배송 현황", "2건 배송중"], ["AI 피팅 기록", "12회"], ["리뷰 관리", "4"], ["쿠폰 · 포인트", "3장 · 2,400P"], ["고객센터 · 설정", ""]].map(([label, meta], i, arr) => (
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
          {([["likes", "찜"], ["my", "마이"]] as [Screen, string][]).map(([key, label]) => (
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

      {toast && (
        <div style={{ position: "absolute", bottom: 96, left: "50%", transform: "translateX(-50%)", background: "rgba(26,23,20,.9)", color: "#fff", fontSize: 12, fontWeight: 600, padding: "9px 16px", borderRadius: 999, zIndex: 80, whiteSpace: "nowrap" }}>{toast}</div>
      )}

      {/* home indicator */}
      <div style={{ position: "absolute", bottom: 7, left: "50%", transform: "translateX(-50%)", width: 128, height: 5, borderRadius: 3, background: T.ink, opacity: 0.16, zIndex: 50 }} />
    </div>
  );
}
