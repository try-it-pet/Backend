# design-sync NOTES — petfit-design-system

- 손으로 만든 소형 패키지(6 컴포넌트). 빌드: `npm run build` (tsup) → `dist/index.es.js` + `dist/index.d.ts`.
- 컨버터 entry: `./dist/index.es.js`. `--node-modules`는 이 패키지의 `node_modules`(react 설치됨)를 가리키면 됨.
- 컴포넌트는 **인라인 스타일(JS 토큰 값) 기반** — 별도 컴포넌트 CSS 없음. validate에서 `[CSS_RUNTIME]`(self-styling, non-blocking)이 떠도 정상.
- 디자인 토큰은 `tokens.css`(CSS 변수) + `src/tokens.ts`(JS) 양쪽에 동일하게 존재. `cfg.cssEntry = tokens.css`.
- 원본 디자인 규칙: `../docs/07_DESIGN_SYSTEM.md`.

## Re-sync risks
- 토큰을 바꿀 때는 `tokens.css`와 `src/tokens.ts` **둘 다** 갱신해야 함(단일 소스 분리됨).
- 인증은 대화형 터미널에서 `/design-login` 필요(코워크/GUI 세션에선 불가).
