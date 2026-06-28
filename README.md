# PetFit (펫핏)

반려동물(강아지·고양이·토끼)을 위한 모바일 AI 쇼핑 플랫폼.
핵심 차별점은 **AI 가상 피팅** — 반려동물 사진 한 장을 올리면 옷을 입은 모습을 미리 보고 체형 기반 사이즈를 추천받는다.

## 모노레포 구조

```
pet/
├─ docs/            기획 문서 (개요·기능·IA·스택·로드맵·디자인 시스템)
├─ design-system/   프론트엔드 — 디자인 토큰·컴포넌트 + 화면 프로토타입(React/Vite)
│                   (examples/PetFitApp.tsx = 6화면 구현)
└─ backend/         API 서버 (FastAPI) — 상품·펫·AI 피팅 잡 + 프로바이더 추상화(mock)
```

## 빠른 시작

### 프론트엔드 프로토타입
```bash
cd design-system
npm install
npm run dev        # http://localhost:5173
```

### 백엔드 API
```bash
cd backend
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000   # http://localhost:8000/docs
```

## 기술 스택

- **프론트(앱)**: Flutter 셸 + 네이티브 모듈 + 웹뷰 (현재 프로토타입은 React/Vite)
- **백엔드**: FastAPI · Pydantic
- **AI 피팅**: 프로바이더 추상화(`backend/app/providers`) — 현재 Mock, 추후 실제 이미지 모델
- 자세한 내용은 [docs/](docs/) 참고

## 디자인

화면 디자인은 **Claude Design**에서 만들고 코드로 구현한다. 디자인 시스템 토큰·철학은
[docs/07_DESIGN_SYSTEM.md](docs/07_DESIGN_SYSTEM.md) 및 `design-system/`의 토큰을 따른다.
