// PetFit 백엔드 API 클라이언트 (FastAPI, 기본 http://localhost:8000)
const API_BASE: string =
  (import.meta as unknown as { env?: { VITE_API_BASE?: string } }).env?.VITE_API_BASE ||
  "http://localhost:8000";

export const apiBase = API_BASE;

// ── 인증 토큰 ──
let authToken: string | null = (() => {
  try { return localStorage.getItem("petfit_token"); } catch { return null; }
})();
export function setToken(t: string | null) {
  authToken = t;
  try { t ? localStorage.setItem("petfit_token", t) : localStorage.removeItem("petfit_token"); } catch { /* ignore */ }
}
export function getToken() { return authToken; }
function authHeaders(): Record<string, string> {
  return authToken ? { Authorization: `Bearer ${authToken}` } : {};
}

export type User = { id: number; provider: string; nickname: string; profile_image: string | null; kakao_id: string | null };
export type Stats = { orders: number; likes: number; fittings: number };

export async function devLogin(nickname = "초코집사"): Promise<{ token: string; user: User }> {
  const r = await fetch(`${API_BASE}/auth/dev-login`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ nickname }),
  });
  if (!r.ok) throw new Error("dev login failed");
  return r.json();
}
export function kakaoLoginUrl() { return `${API_BASE}/auth/kakao/login`; }

export async function fetchMe(): Promise<User | null> {
  if (!authToken) return null;
  const r = await fetch(`${API_BASE}/auth/me`, { headers: authHeaders() });
  return r.ok ? r.json() : null;
}
export async function fetchLikes(): Promise<number[]> {
  const r = await fetch(`${API_BASE}/me/likes`, { headers: authHeaders() });
  if (!r.ok) throw new Error("likes failed");
  return r.json();
}
export async function toggleLikeApi(productId: number): Promise<{ liked: boolean; likedIds: number[] }> {
  const r = await fetch(`${API_BASE}/me/likes/${productId}`, { method: "POST", headers: authHeaders() });
  if (!r.ok) throw new Error("like failed");
  return r.json();
}
export async function addToCart(productId: number, size: string, qty = 1) {
  const r = await fetch(`${API_BASE}/me/cart`, {
    method: "POST", headers: { ...authHeaders(), "Content-Type": "application/json" },
    body: JSON.stringify({ product_id: productId, size, qty }),
  });
  if (!r.ok) throw new Error("cart failed");
  return r.json();
}
export async function fetchStats(): Promise<Stats> {
  const r = await fetch(`${API_BASE}/me/stats`, { headers: authHeaders() });
  if (!r.ok) throw new Error("stats failed");
  return r.json();
}

export type Pet = {
  id: number; name: string; species: string; breed: string | null;
  weight_kg: number | null; age: string | null;
  chest_cm: number | null; neck_cm: number | null; back_cm: number | null;
};
export async function fetchPets(): Promise<Pet[]> {
  if (!authToken) return [];
  const r = await fetch(`${API_BASE}/me/pets`, { headers: authHeaders() });
  return r.ok ? r.json() : [];
}
export type PetInput = {
  name: string; species?: string; breed?: string | null; weight_kg?: number | null;
  age?: string | null; chest_cm?: number | null; neck_cm?: number | null; back_cm?: number | null;
};
export async function createPet(body: PetInput): Promise<Pet | null> {
  const r = await fetch(`${API_BASE}/me/pets`, {
    method: "POST", headers: { ...authHeaders(), "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return r.ok ? r.json() : null;
}

export type ApiProduct = { id: number; brand: string; name: string; price: number; fit: number };
export type TryOnResult = { image_url: string; fit_score: number; recommended_size: string; analysis: string };
export type TryOnJob = {
  id: string;
  status: "queued" | "processing" | "done" | "failed";
  product_id: number;
  size: string;
  result: TryOnResult | null;
  error: string | null;
};

export async function fetchProducts(): Promise<ApiProduct[]> {
  const r = await fetch(`${API_BASE}/products`);
  if (!r.ok) throw new Error("products fetch failed");
  return r.json();
}

export type Provider = "mock" | "openai" | "replicate";
export type Style = "winter" | "ghibli" | "riso" | "mood" | "studio" | "lifestyle" | "film" | "snap";
export type Composition = "front_full" | "side" | "closeup" | "sitting";
export type Background = "studio" | "keep";

export type TryOnParams = {
  productId: number;
  size: string;
  petId?: number;
  provider?: Provider;
  petImage?: File;
  style?: Style;
  composition?: Composition;
  background?: Background;
};

export async function createTryOn(p: TryOnParams): Promise<TryOnJob> {
  const fd = new FormData();
  fd.append("product_id", String(p.productId));
  fd.append("size", p.size);
  if (p.petId != null) fd.append("pet_id", String(p.petId));
  if (p.provider) fd.append("provider", p.provider);
  if (p.style) fd.append("style", p.style);
  if (p.composition) fd.append("composition", p.composition);
  if (p.background) fd.append("background", p.background);
  if (p.petImage) fd.append("pet_image", p.petImage);
  const r = await fetch(`${API_BASE}/tryon`, { method: "POST", body: fd, headers: authHeaders() });
  if (!r.ok) throw await apiError(r, "tryon create failed");
  return r.json();
}

/** 서버 응답 에러를 detail 메시지 + status 로 감싸서 던진다(횟수 제한 402/401 표시용). */
async function apiError(r: Response, fallback: string): Promise<Error> {
  let detail = fallback;
  try { detail = (await r.json())?.detail || fallback; } catch { /* ignore */ }
  const e = new Error(detail) as Error & { status?: number };
  e.status = r.status;
  return e;
}

/** 인생네컷(2x2): 한 장 사진 → 4포즈 컷 → 합성. tryon 과 동일하게 폴링. */
export async function createFourcut(p: {
  productId: number;
  size: string;
  petId?: number;
  provider?: Provider;
  petImage?: File;
  style?: Style;
}): Promise<TryOnJob> {
  const fd = new FormData();
  fd.append("product_id", String(p.productId));
  fd.append("size", p.size);
  if (p.petId != null) fd.append("pet_id", String(p.petId));
  if (p.provider) fd.append("provider", p.provider);
  if (p.style) fd.append("style", p.style);
  if (p.petImage) fd.append("pet_image", p.petImage);
  const r = await fetch(`${API_BASE}/tryon/fourcut`, { method: "POST", body: fd, headers: authHeaders() });
  if (!r.ok) throw await apiError(r, "fourcut create failed");
  return r.json();
}

export type Generations = { unlimited: boolean; remaining: number | null; granted: number | null; used: number };
export async function fetchGenerations(): Promise<Generations | null> {
  if (!getToken()) return null;
  const r = await fetch(`${API_BASE}/me/generations`, { headers: authHeaders() });
  return r.ok ? r.json() : null;
}

export async function runFourcut(p: {
  productId: number;
  size: string;
  petId?: number;
  provider?: Provider;
  petImage?: File;
  style?: Style;
}): Promise<TryOnJob> {
  let job = await createFourcut(p);
  // 4컷 동시 생성 → 합성. 실모델이면 수십 초. 넉넉히 폴링(최대 ~160초).
  for (let i = 0; i < 80; i++) {
    if (job.status === "done" || job.status === "failed") return job;
    await new Promise((res) => setTimeout(res, 2000));
    job = await getTryOn(job.id);
  }
  return job;
}

export async function getTryOn(jobId: string): Promise<TryOnJob> {
  const r = await fetch(`${API_BASE}/tryon/${jobId}`);
  if (!r.ok) throw new Error("tryon get failed");
  return r.json();
}

/** 잡 생성 후 done/failed 까지 폴링. */
export async function runTryOn(p: TryOnParams): Promise<TryOnJob> {
  let job = await createTryOn(p);
  // gpt-image-2 생성은 15~40초+ 걸릴 수 있어 충분히 폴링한다(최대 ~160초)
  for (let i = 0; i < 80; i++) {
    if (job.status === "done" || job.status === "failed") return job;
    await new Promise((res) => setTimeout(res, 2000));
    job = await getTryOn(job.id);
  }
  return job;
}
