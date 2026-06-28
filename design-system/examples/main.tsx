import React from "react";
import { createRoot } from "react-dom/client";
import { PetFitApp } from "./PetFitApp";

const el = document.getElementById("root")!;
createRoot(el).render(
  <React.StrictMode>
    <div style={{ display: "flex", justifyContent: "center", padding: "28px 0 48px" }}>
      <PetFitApp />
    </div>
  </React.StrictMode>
);
