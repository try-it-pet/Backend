import { defineConfig } from "tsup";

// dist/index.es.js (ESM) + dist/index.d.ts 를 생성한다.
// /design-sync 컨버터는 package.json 의 module/main(= dist/index.es.js)과
// 타입(dist/index.d.ts)을 읽어 번들·prop 추출에 사용한다.
export default defineConfig({
  entry: { index: "src/index.ts" },
  format: ["esm"],
  dts: true,
  clean: true,
  sourcemap: false,
  external: ["react", "react-dom", "react/jsx-runtime"],
  outExtension() {
    return { js: ".es.js" };
  },
});
