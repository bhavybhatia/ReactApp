import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vitejs.dev/config/
// The backend host/port can be overridden via env vars at start time, e.g.:
//   BACKEND_HOST=127.0.0.1 BACKEND_PORT=8000 npm run dev
// Defaults to localhost:8000, which is correct for the common case where
// the frontend and backend run as two processes on the same server.
const BACKEND_HOST = process.env.BACKEND_HOST || "localhost";
const BACKEND_PORT = process.env.BACKEND_PORT || "8000";
const BACKEND_TARGET = `http://${BACKEND_HOST}:${BACKEND_PORT}`;

export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0", // listen on all network interfaces, not just localhost
    port: 5173,
    proxy: {
      "/api": {
        target: BACKEND_TARGET,
        changeOrigin: true,
      },
    },
  },
  preview: {
    // Same settings, used when running `vite preview` after `npm run build`
    host: "0.0.0.0",
    port: 5173,
    proxy: {
      "/api": {
        target: BACKEND_TARGET,
        changeOrigin: true,
      },
    },
  },
});
