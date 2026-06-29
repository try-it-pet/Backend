// PetFit 백엔드 API 클라이언트 (FastAPI, 기본 http://localhost:8000)
const API_BASE: string =
  (import.meta as unknown as { env?: { VITE_API_BASE?: string } }).env?.VITE_API_BASE ||
  "http://localhost:8000";

export const apiBase = API_BASE;

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

export async function createTryOn(p: {
  productId: number;
  size: string;
  petId?: number;
  provider?: Provider;
  petImage?: File;
}): Promise<TryOnJob> {
  const fd = new FormData();
  fd.append("product_id", String(p.productId));
  fd.append("size", p.size);
  if (p.petId != null) fd.append("pet_id", String(p.petId));
  if (p.provider) fd.append("provider", p.provider);
  if (p.petImage) fd.append("pet_image", p.petImage);
  const r = await fetch(`${API_BASE}/tryon`, { method: "POST", body: fd });
  if (!r.ok) throw new Error("tryon create failed");
  return r.json();
}

export async function getTryOn(jobId: string): Promise<TryOnJob> {
  const r = await fetch(`${API_BASE}/tryon/${jobId}`);
  if (!r.ok) throw new Error("tryon get failed");
  return r.json();
}

/** 잡 생성 후 done/failed 까지 폴링. */
export async function runTryOn(p: {
  productId: number;
  size: string;
  petId?: number;
  provider?: Provider;
  petImage?: File;
}): Promise<TryOnJob> {
  let job = await createTryOn(p);
  for (let i = 0; i < 30; i++) {
    if (job.status === "done" || job.status === "failed") return job;
    await new Promise((res) => setTimeout(res, 400));
    job = await getTryOn(job.id);
  }
  return job;
}
