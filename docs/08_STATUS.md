# 08. 구현 현황 & 이어서 작업 (Status & Handoff)

> 새 세션에서 이 문서만 읽으면 이어서 작업 가능. (브랜드: **PetFit → Pawdy** 로 변경됨)
> 최종 업데이트: 2026-06-30

## 🌐 라이브 (배포됨)
- **프론트(Vercel)**: https://backend-delta-flame-87.vercel.app
- **백엔드(Railway)**: https://pawdy-api-production.up.railway.app (`/docs` Swagger, `/health`)
- **레포(GitHub)**: https://github.com/try-it-pet/Backend (모노레포; 이름은 Backend지만 프론트+문서 포함)
- 프론트는 빌드 시 `VITE_API_BASE`(Vercel 환경변수)로 Railway 백엔드를 가리킴. CORS는 `*.vercel.app` 허용.

## 📁 구조 (모노레포)
```
pet/
├─ docs/            기획·현황 문서 (이 파일 = 08)
├─ design-system/   프론트(React/Vite). 핵심: examples/PetFitApp.tsx (6화면), examples/api.ts
└─ backend/         FastAPI. app/{main,config,models,data,store,auth,vision}.py, app/routers/*, app/providers/*
```

## ▶️ 로컬 실행
```bash
# 백엔드 (키는 backend/.env, .env.example 참고)
cd backend && python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --port 8000        # app/config.py 가 .env 자동 로드(load_dotenv)
# 프론트
cd design-system && npm install && npm run dev   # http://localhost:5173
```
> ⚠️ uvicorn `--reload`는 Windows에서 좀비 프로세스가 남으니 데모/테스트 땐 빼는 게 편함.

## 🔑 환경변수 (backend/.env — git 제외)
`PETFIT_OPENAI_API_KEY`(sk-), `PETFIT_REPLICATE_TOKEN`(r8-), `PETFIT_KAKAO_REST_API_KEY`,
`PETFIT_PROVIDER`(기본 mock; 배포는 openai), `PETFIT_OPENAI_MODEL=gpt-image-2`,
`PETFIT_VISION_MODEL=gpt-4o-mini`, `PETFIT_JWT_SECRET`, `PETFIT_FRONTEND_URL`.
(Railway는 동일 변수를 Variables 탭에 설정. 로컬·배포 모두 같은 키.)

## ✅ 구현 완료
- **브랜드 Pawdy** + 5탭(홈/카테고리/AI피팅/찜/마이), 멀티샵 카탈로그 18종 + 5 대분류(데일리케어·패션·액티브·웰니스·홈).
- **AI 가상 피팅(핵심)**: `POST /tryon`(비동기 잡 → 폴링). 프로바이더 추상화 = **mock / openai(gpt-image-2) / replicate(flux-kontext)**, 요청별 `provider`로 A/B 비교.
  - gpt-image-2 **멀티이미지 edit**: 펫 사진 + **상품 레퍼런스 옷 이미지**(의류 6종 `ref_image`) → 실제 그 옷을 입힘. 검증됨.
  - **펫 사진 사전 검증**(`vision.py` detect_pet, gpt-4o-mini): 강아지/고양이 아니면 생성 전 친절히 실패(이유 표시).
  - 프론트 폴링 **160초**(gpt-image-2는 15~40초 — 과거 12초 타임아웃이 "생성 실패" 원인이었음).
- **상품 이미지**: 18종 모두 gpt-image-2로 생성한 깔끔한 상품컷 = `backend/app/static/garments/{id}.png`, `/static`로 서빙. `Product.image`(카드)·`ref_image`(피팅 옷). "입혀볼 옷"은 `fittable`만 노출.
- **구도/사진풍 옵션**: `/tryon` 에 `style`(studio·lifestyle·film·snap) / `composition`(front_full·side·closeup·sitting) / `background`(studio 교체·keep 원본유지) Form 필드. 프리셋은 `openai_provider.STYLE/COMPOSITION/BACKGROUND_PRESETS` 단일 출처(replicate도 재사용), `_build_prompt`에 주입. 프론트 피팅 화면에 "사진풍/구도" 칩 UI(`PetFitApp.tsx`), `background`는 style에서 파생(studio→교체, 그 외→원본 유지).
- **인증/계정**: 카카오 OAuth + JWT + dev-login(둘러보기). 사용자 기준 `/me/likes·cart·orders·pets·stats`.
- **배포**: 프론트 정적(Vercel) + 백엔드(Railway Docker). 백엔드 없을 때 프론트 데모 폴백.

## ⚠️ 한계/주의
- 데이터 **인메모리**(서버 재시작 시 로그인·찜·주문·생성결과 초기화). → DB(PostgreSQL/Redis) + 이미지 스토리지(S3) 필요.
- Railway 무료면 콜드스타트(첫 요청 ~30초).
- 상품 `ref_image`(피팅 옷)은 의류 6종(id 0~5)만. 홈·인테리어 "배치" 피팅은 미구현.

## 🔜 다음 작업 (우선순위)

### 1. ✅ 구도/사진풍 옵션 생성 — **완료** (2026-06-30)
구현됨(위 ✅ 구현 완료 참고). 남은 확장 아이디어: 결과 **여러 장 비교(갤러리)** — 한 번에 여러 style/composition 조합을 보내 썸네일로 나열. 현재는 칩 변경 시 단일 결과만 재생성.

### 2. 프롬프트 품질 ↑ / 홈·인테리어 "배치" 피팅
- 의류 외에 캣타워·숨숨집 등 **배치(placement)** 프롬프트 분기(`category=="home"`이면 "place the item next to the pet in a room").

### 3. 데이터 영구화
- 인메모리 → PostgreSQL(상품·유저·찜·주문·펫), 생성 이미지 → S3/CDN. (현재 결과는 `store.RESULTS` 인메모리.)

### 4. 정리
- Vercel/Railway 프로젝트·도메인 이름을 `pawdy`로. 카카오 redirect URI 등록(`<백엔드>/auth/kakao/callback`)으로 실제 카카오 로그인.
- docs 00~07(구 PetFit 기획) 일부 stale — 필요시 Pawdy로 갱신.

## 🧰 자주 쓰는 검증
```bash
curl https://pawdy-api-production.up.railway.app/health        # providers 키 로드 확인
# 배포 백엔드로 생성 테스트(펫 사진 필요):
curl -F product_id=0 -F provider=openai -F pet_image=@dog.jpg <백엔드>/tryon
```
