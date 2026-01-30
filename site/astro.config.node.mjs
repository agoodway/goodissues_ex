import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';
import partytown from '@astrojs/partytown';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://your-domain.com', // UPDATE THIS

  // CRITICAL: Always use trailing slashes to prevent nginx port leakage
  trailingSlash: 'always',

  integrations: [
    react(),
    sitemap(),
    partytown({
      config: {
        forward: ['dataLayer.push'],
      },
    }),
  ],

  vite: {
    plugins: [tailwindcss()],
  },
});
