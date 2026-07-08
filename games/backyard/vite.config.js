import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// three@0.128.0 is pinned — the game's renderer relies on r128 APIs
// (LinearEncoding output, onBeforeCompile injection, geometry APIs).
// Never bump it casually; colors/wind/clouds visibly break on newer three.
export default defineConfig({
  plugins: [react()],
  build: {
    // The game is one intentionally-huge component (~740 KB with embedded
    // audio/logo). Raise the warning limit so builds stay quiet.
    chunkSizeWarningLimit: 2500,
  },
});
