import React from "react";
import { createRoot } from "react-dom/client";
import { PetFitApp } from "./PetFitApp";

// 실제 앱(Capacitor)에서는 데모용 여백 없이 풀스크린 (?native=1 = 개발용 토글)
const isNativeApp =
  !!(window as unknown as { Capacitor?: { isNativePlatform?: () => boolean } }).Capacitor?.isNativePlatform?.() ||
  new URLSearchParams(window.location.search).has("native");

const el = document.getElementById("root")!;
createRoot(el).render(
  <React.StrictMode>
    <div style={isNativeApp ? undefined : { display: "flex", justifyContent: "center", padding: "28px 0 48px" }}>
      <PetFitApp />
    </div>
  </React.StrictMode>
);
