# 08. 구현 현황 & 이어서 작업 (Status & Handoff)

> 새 세션에서 이 문서만 읽으면 이어서 작업 가능. (브랜드: **PetFit → Pawdy** 로 변경됨)
> 최종 업데이트: 2026-07-06 (상세 최신 이력은 세션 메모리 pawdy-launch-plan 참고)

## 🆕 2026-07-06 진행 (출시 D-7)
- **실상품 카탈로그**: data.py 18종 전부 해외직구 실브랜드(maxbone·Ruffwear·Little Beast·earthbath·Greenies·Open Farm·PureBites·ibiyaya·Outward Hound·Zesty Paws·Catit·MEOWFIA)·실가격·실상품컷(`/static/products/`)·구매링크(`Product.url`). 패션 6종 ref_image=실상품 플랫레이(AI 피팅 반영).
- **사이즈 분류**: `Product.sizes`(의류만 XS~XL, 그 외 null=Free 단일). 상세 화면 Free 칩·카테고리별 상품정보 문구.
- **로그인 연결**: 찜/장바구니/펫등록/생성 401 → 로그인 바텀시트(카카오+둘러보기). 비로그인 가짜 찜 제거.
- **안드로이드 앱**: `App/`(별도 레포 try-it-pet/App)에 Capacitor 8 셸. `npm run build:web → npx cap sync android → npm run apk`. 함정: 한글 경로(overridePathCheck), Java 21(JBR). 네이티브에서 아이폰 목업 크롬 제거(웹 데모는 유지, `?native=1` 토글). 백엔드 CORS에 `https://localhost` 허용.
- **펫 실연동**: 등록 펫 이름/pet_id/가슴둘레가 홈·피팅·추천사이즈에 반영 (등록 API `POST /me/pets`는 기존부터 있음).
- **카카오 로그인**: redirect_uri 요청 호스트 자동 유도 + `?next=` 복귀 + 클라이언트 시크릿 지원(`PETFIT_KAKAO_CLIENT_SECRET`). 콘솔 새 REST API 키 `1ff0a...` + URI 등록 + Railway env 갱신 완료. **E2E 최종 확인만 남음**(KOE006 재발 시 콘솔 저장 여부 확인). 앱 내 카카오는 미완결(웹 복귀) → 딥링크 필요.
- **남은 TODO**: 카카오 E2E 확인 → 시크릿 재발급, 인앱 결제, 새 샵 입점 푸시, winter LoRA R2 재호스팅, 홈 카테고리 '배치' 피팅, 릴리스(서명) 빌드.

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
- **감성 룩 + 구도 옵션**: `/tryon` 에 `style`(winter·studio·lifestyle·film·snap) / `composition`(front_full·side·closeup·sitting) / `background` Form 필드. 룩/구도/배경 프리셋 단일 출처 = `app/providers/looks.py`. **winter=겨울 감성**은 배경까지 연출하는 `SCENE_LOOKS`(studio/keep 무시). 프론트 "감성 룩/구도" 칩(`PetFitApp.tsx`), 기본=겨울 감성. 옷 선택만으로 자동 생성 X → **'입혀보기' 버튼**으로만 트리거.
- **인생네컷(2x2)**: `POST /tryon/fourcut` — 한 장의 펫 사진 → 4포즈/표정 컷(정면·갸웃·활짝·얼빡, `looks.FOURCUT_POSES`)을 `asyncio.gather`로 동시 생성 → `app/fourcut.py`가 Pillow로 포토부스풍 2x2 합성(크림 프레임·둥근 셀·Pawdy 워드마크). 감성 룩(style)·상품 옷 함께 반영, mock/실패 컷은 플레이스홀더. 결과는 tryon과 동일하게 폴링, `/tryon/{id}/result` PNG. 프론트 피팅 화면에 **입혀보기 + 인생네컷** 버튼(`runFourcut`), 결과는 같은 preview 영역에 표시. (mock E2E 검증됨)
- **Replicate LoRA 파인튜닝 구조**: 감성 룩 = 학습된 Replicate 모델 1개로 매핑. `PETFIT_LOOK_MODELS`(JSON, 룩→`owner/name:version`) 등록 시 그 LoRA 모델로 생성, 없으면 **프롬프트 폴백**(코드 변경 0). 기본 편집 모델 `flux-kontext-dev`(LoRA 가능한 오픈웨이트). 학습 스크립트 `backend/scripts/train_lora.py` + 데이터셋 가이드 `backend/scripts/README.md`. `looks.py`의 `look_model()/look_trigger()`가 env에서 해석. 학습 시 프롬프트는 트리거 단어로 대체(과지시 방지).
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
