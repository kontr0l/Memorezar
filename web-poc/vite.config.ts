import { defineConfig } from 'vite';

export default defineConfig({
  // Use repo name as base path for GitHub Pages
  base: process.env.BASE_URL || '/',
  build: {
    outDir: 'dist',
  },
});
