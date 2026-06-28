# PetFit Design System

반려동물 AI 쇼핑 앱 **PetFit**의 디자인 시스템 패키지.
Claude Design의 `/design-sync`가 읽는 **토큰 + React 컴포넌트** 소스입니다.

> 디자인 규칙 원문: [`../docs/07_DESIGN_SYSTEM.md`](../docs/07_DESIGN_SYSTEM.md)

## 구조

```
design-system/
├─ tokens.css            CSS 변수 토큰
├─ src/
│  ├─ tokens.ts          TS 토큰(색·폰트·간격·라운딩·그림자)
│  ├─ index.ts           진입점
│  └─ components/
│     ├─ Button.tsx      primary / secondary / outline
│     ├─ Chip.tsx        카테고리·필터 칩
│     ├─ Input.tsx       텍스트 인풋
│     ├─ AIBadge.tsx     'AI 생성 이미지' 배지
│     ├─ ProductCard.tsx 상품 카드
│     └─ BottomTab.tsx   하단 5탭(중앙 AI FAB)
```

## Claude Design에 올리기

이 폴더에서 Claude Code로 아래를 실행하면 토큰·컴포넌트를 읽어 디자인 시스템으로 업로드합니다.

```
cd design-system
claude
/design-sync
```

완료되면 Claude Design의 **Design systems** 목록에 **PetFit**으로 나타납니다.

## 참고

이 컴포넌트는 **웹 프로토타입용(React)**. 실제 앱은 Flutter로 구현하되,
색·간격·라운딩 등 **토큰 값은 1:1로 공유**한다(단일 소스).
