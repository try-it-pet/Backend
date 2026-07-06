import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { PetFitApp } from "./PetFitApp";

// 실제 앱(Capacitor)에서는 데모용 여백 없이 풀스크린 (?native=1 = 개발용 토글)
const isNativeApp =
  !!(window as unknown as { Capacitor?: { isNativePlatform?: () => boolean } }).Capacitor?.isNativePlatform?.() ||
  new URLSearchParams(window.location.search).has("native");

// 데스크톱(넓은 화면)에서만 아이폰 목업을 가운데 정렬해 여백을 준다.
// 실제 모바일(≤480px)·네이티브는 뷰포트를 꽉 채우므로 래퍼 여백 없이 풀스크린.
function Mount() {
  const [wide, setWide] = useState(() => window.innerWidth > 480);
  useEffect(() => {
    const onResize = () => setWide(window.innerWidth > 480);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);
  const desktopMockup = !isNativeApp && wide;
  return (
    <div style={desktopMockup ? { display: "flex", justifyContent: "center", padding: "28px 0 48px" } : undefined}>
      <PetFitApp />
    </div>
  );
}

const el = document.getElementById("root")!;
createRoot(el).render(
  <React.StrictMode>
    <Mount />
  </React.StrictMode>
);
