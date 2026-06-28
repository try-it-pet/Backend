import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// examples/HomeScreen 등 프리뷰용 dev 서버.
// 라이브러리 빌드(tsup)와 별개이며, dist/ 를 건드리지 않도록 outDir 분리.
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, host: true },
  build: { outDir: "preview-dist" },
});
