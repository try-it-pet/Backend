# PetFit API (backend)

반려동물 AI 쇼핑 **PetFit**의 백엔드. FastAPI 기반, AI 가상 피팅을 중심으로 한 프로토타입.
AI 생성은 현재 **Mock 프로바이더**(실제 모델 없이 종단 플로우 검증) — 추후 실제 이미지 모델로 교체.

## 실행

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # (mac/linux: source .venv/bin/activate)
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

- API 문서(Swagger): http://localhost:8000/docs
- 헬스체크: http://localhost:8000/health

## 엔드포인트

| 메서드 | 경로 | 설명 |
| --- | --- | --- |
| GET | `/products` · `/products/{id}` | 상품 목록·상세 (더미) |
| POST/GET | `/pets` · `/pets/{id}` | 펫 프로필 등록·조회 |
| POST | `/tryon` | 피팅 잡 생성 (multipart: `product_id`, `size`, `pet_id?`, `pet_image?`) → `202` + jobId |
| GET | `/tryon/{job_id}` | 잡 상태/결과 폴링 (`queued→processing→done`) |
| GET | `/tryon/{job_id}/preview.svg` | Mock 결과 이미지(SVG) |

## 피팅 플로우 (예시)

```bash
# 1) 잡 생성
curl -F product_id=0 -F size=M http://localhost:8000/tryon
# → {"id":"<jobId>","status":"queued",...}

# 2) 폴링 (1~2초 후 done)
curl http://localhost:8000/tryon/<jobId>
# → {"status":"done","result":{"image_url":"/tryon/<jobId>/preview.svg","fit_score":96,"recommended_size":"M",...}}
```

## 구조

```
backend/app/
├─ main.py            FastAPI 앱 · CORS · 라우터
├─ config.py          설정(PETFIT_PROVIDER 등 env)
├─ models.py          Pydantic 스키마
├─ data.py            더미 상품
├─ store.py           인메모리 저장소(펫·잡) — 추후 PostgreSQL/Redis
├─ routers/           products · pets · tryon
└─ providers/         프로바이더 추상화
   ├─ base.py         TryOnProvider 인터페이스
   └─ mock.py         MockProvider (실제 모델 자리)
```

## 실제 모델로 교체

`providers/base.py`의 `TryOnProvider.generate()` 시그니처만 지키면 라우터는 그대로.
`providers/` 에 `RealProvider` 추가 → `providers/__init__.py`의 `get_provider()` 분기 +
`PETFIT_PROVIDER=real`, `PETFIT_MODEL_API_KEY` 설정.
