import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';
import partytown from '@astrojs/partytown';
import tailwindcss from '@tailwindcss/vite';
import tidewave from 'tidewave/vite-plugin';

export default defineConfig({
  site: 'https://your-domain.com', // UPDATE THIS
  trailingSlash: 'always',

  integrations: [
    react(),
    sitemap(),
    partytown({
      config: {
        forward: ['dataLayer.push'], // Required for Google Analytics
      },
    }),
  ],

  vite: {
    plugins: [
      tailwindcss(),
      tidewave(), // AI agent integration (dev only)
    ],
  },
});
