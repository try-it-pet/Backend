# 08. 구현 현황 & 이어서 작업 (Status & Handoff)

> 새 세션에서 이 문서 + 메모리(flutter-migration) 읽으면 이어서 작업 가능. (브랜드: PetFit → **Pawdy**)
> 최종 업데이트: **2026-07-07** (아래 최신 섹션부터 읽을 것. 그 아래 2026-07-06 이하는 히스토리)

---

# 🔴 다음 작업 = AI 이미지 **품질 개선** (2026-07-07 이 세션에서 넘김)

**현재 AI 피팅/인생네컷이 엔드투엔드로 완전히 동작함**(생성→R2 저장→앱 표시까지 OK). 그러나:
- **결과 퀄리티가 낮음** (예: replicate 지브리 룩 — 귀엽지만 시그니처 완성도 부족).
- **인생네컷 4컷 중 일부만 생성**됨(2/4 등, 나머지 빈 셀) → 컷 실패/재시도 안정화 필요.

## 품질 개선 레버 (우선순위)
1. **학습 데이터 = 품질의 8할** (제일 중요): 시그니처 룩 **LoRA 재학습**. "적지만 완벽하게 일관된" 15~30장(조명·색보정·구도·분위기 통일). **Kontext before/after 20쌍** 방식이 펫 정체성 보존에 유리. 지금 gpt-image-2로 뽑은 "대박 컷"만 큐레이션해 시드로.
   - 학습 파이프라인 이미 있음: `backend/scripts/{train_lora.py, train_lora_fal.py, build_dataset.py, rehost_lora.py}` + 가이드 `backend/scripts/README.md`.
   - 학습 후 → **R2에 호스팅**(`rehost_lora.py`, R2 이제 붙음) → env `PETFIT_LOOK_MODELS`/`PETFIT_LOOK_LORAS`/`PETFIT_LOOK_TRIGGERS` 등록 → replicate+해당 룩으로 활성화. (등록 안 하면 프롬프트 폴백.)
2. **추론 env 튜닝**(학습 없이 즉시 체감): `PETFIT_LORA_STRENGTH`(0.9→0.7~1.1), `PETFIT_LORA_STEPS`(40↑=디테일), `PETFIT_LORA_OUTPUT_QUALITY`(100). 프롬프트는 `backend/app/providers/looks.py`.
3. **출력 업스케일 단계 추가**(Real-ESRGAN 등) — 해상도/디테일 ↑.
4. **입력 펫 사진 전처리**(리사이즈·크롭) — bad input=bad output.
5. **인생네컷 4컷 안정화**: 일부 컷 실패 원인(429/생성실패) — `tryon.py _process_fourcut`의 동시성(Semaphore 2)·재시도 조정, 실패 셀 재생성.
6. (장기) 좋아요·공유 많은 컷 자동 수집 → 다음 LoRA 학습 데이터 선순환.

---

# 🟢 현재 스택 (2026-07-07 대전환: React/Capacitor → Flutter)

- **프론트 = Flutter 네이티브** (`pawdy_flutter/`). 기존 React/Vite(`design-system/`) + Capacitor(`App/`)에서 **전면 이관**. **웹 서비스는 접음**(Flutter 단일). 상세·이유는 메모리 `flutter-migration`.
- **백엔드 = FastAPI** (`backend/`), Railway 배포, **Postgres** + **Cloudflare R2**(생성 이미지 영구저장).
- **레거시**(패리티 확인 후 제거 예정, 지금은 유지): `design-system/`·`App/`·Vercel 웹.

## Flutter 빌드/실행
- Flutter SDK = `C:\src\flutter` (PATH 미등록 → **PowerShell로 `flutter.bat` 호출**). Android SDK/JBR(Java21) 있음.
- 컴파일 검증(빠름): `cd pawdy_flutter && flutter build web`
- APK: `flutter build apk --debug --dart-define=BUILD_TAG=<태그>` → `pawdy_flutter/build/app/outputs/flutter-apk/app-debug.apk`
  - **BUILD_TAG**: 설치 후 앱 **마이>설정>앱 버전**에 `1.0.0 (태그)` 표시 → 최신 APK 설치됐는지 확인용.
- (한글 경로 대응 `android.overridePathCheck=true` 이미 설정.)

## Flutter 구현 완료
- 화면: 인트로 스플래시 · 홈(카카오프로필·장바구니아이콘) · 카테고리(검색·종필터) · 상세(리뷰·별점·사이즈선택·AI피팅CTA) · **AI피팅**(프로바이더·감성룩·구도·사진선택·입혀보기·인생네컷·quota표시) · 찜 · 마이 · 설정(잔여횟수·로그아웃·빌드태그) · 주문내역 · 리뷰관리(카드→상품) · **AI피팅기록 갤러리**(탭→확대) · **장바구니+결제**
- 인증: **카카오 네이티브 딥링크**(`pawdy://login`, 콜백 HTML 인터스티셜) + dev-login(둘러보기)
- 공유상태 `AppState`(상품·찜·인증·장바구니), **Pretendard 폰트** 번들
- 백엔드 신규(이 세션): **reviews**(테이블+`GET /products/{id}/reviews`·`/me/reviews`), **fittings 이력**(테이블+`GET /me/fittings`, mock 제외 저장), **R2 storage**, 카카오 콜백 인터스티셜, `pawdy://` 복귀 허용

## 🌐 배포/설정 (2026-07-07)
- 백엔드: https://pawdy-api-production.up.railway.app (`/health` → `storage:r2`, `db:postgresql`)
- 레포: https://github.com/try-it-pet/Backend (main 에 backend+pawdy_flutter+design-system+docs)
- **R2**: 버킷 `pawdy`, `PETFIT_R2_PUBLIC_BASE=https://pub-25ee006c84d843a0a749182747a5dd0b.r2.dev` **(⚠️ `pub-` 하이픈 필수! 빠지면 이미지 500)**. 엔드포인트/키 4개 Railway Variables.
- ⚠️ 운영 `PETFIT_ALLOW_DEV_LOGIN=0` → QA 시 둘러보기·피팅 폴백 403. 필요 시 1로.

## 🐛 이 세션에서 잡은 주요 버그 (재발 참고)
- **생성 항상 실패**: 클라가 생성접수 `202`를 실패처리 → `200/202` 허용(`api/client.dart _createJob`).
- **R2 이미지 500**: `PETFIT_R2_PUBLIC_BASE` 하이픈 누락(`pub25ee…`→`pub-25ee…`).
- **로그인 후 마이/카테고리/찜 탭 갱신 안됨**: `const` 위젯이 canonical 단일 인스턴스라 리빌드 스킵 → non-const(`main.dart` IndexedStack).
- **마이 좋아요 수 동기화**: `stats.likes` 스냅샷 → `likedIds.length` 실시간.
- **텍스트 노란 밑줄**: Material 조상 없음(인트로·pushed FitScreen) → `Material`로 감쌈.
- **오버플로우**: 상품카드 `childAspectRatio 0.72→0.66`, 하단탭 AI피팅 `Column→Stack(Clip.none)`.
- **createPet 201 오처리**, 카카오 딥링크(크롬이 커스텀스킴 자동리다이렉트 차단→HTML 인터스티셜+버튼).

---

## 🆕 2026-07-06 진행 (히스토리, 당시 Capacitor 기준)
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
