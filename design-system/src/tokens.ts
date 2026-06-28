// PetFit 디자인 토큰 (단일 소스). Claude Design 핸드오프("PetFit App.dc.html") 기준.
// 철학: 미니멀, 그라데이션 없음, 액센트는 코랄 한 가지, AI는 텍스트 라벨로 조용히.
export const color = {
  paper: "#FAF8F5", // 앱 배경 (따뜻한 종이톤)
  surface: "#FFFFFF", // 카드·검색바·입력 표면
  soft: "#F1ECE6", // 이미지 플레이스홀더·보조 칩·구분선
  heroBg: "#EDE6DD", // 홈 히어로 배너 배경
  ink: "#1A1714", // 주 텍스트·선택 칩/버튼 배경
  sub: "#6E665E", // 본문 보조 텍스트
  muted: "#9B948C", // 캡션·비활성 라벨
  muted2: "#A89F95", // 브랜드명 등 더 옅은 라벨
  line: "#ECE7E1", // 보더·구분선
  accent: "#E8674A", // 유일한 액센트 (코랄)
  accentSoft: "#FBEDE8", // 액센트 아이콘 배경 틴트
  heroLabel: "#A2693F", // 히어로 "AI 가상 피팅" 라벨 (브론즈)
  onAccent: "#FFFFFF",
  onInk: "#FFFFFF",
} as const;

export const font = {
  family: '"Pretendard", system-ui, sans-serif',
  display: 21, // 화면 타이틀
  h1: 20, // 히어로 헤드라인
  h2: 18, // 섹션 제목
  body: 13.5,
  price: 15,
  caption: 12,
  label: 11.5, // 브랜드명
  chip: 13.5,
  tab: 10,
  regular: 400,
  medium: 500,
  semibold: 600,
  bold: 700,
  heavy: 800,
} as const;

export const space = {
  1: 4, 2: 8, 3: 12, 4: 16, 5: 20, 6: 24, 8: 32,
  screenPadding: 22,
} as const;

export const radius = {
  sm: 12, // 사각 버튼·작은 칩
  md: 14, // 검색바·하단 버튼
  card: 16, // 카드·이미지·정보 카드
  hero: 22, // 히어로·피팅 스테이지
  frame: 42, // 폰 프레임
  full: 999,
} as const;

export const shadow = {
  fab: "0 6px 16px rgba(232,103,74,.32)",
  frame: "0 30px 80px rgba(40,30,25,.18)",
} as const;
