// main.ts
// Entry point for Wolfenstein 3-D TypeScript port
// Called from index.html on DOMContentLoaded

import { wolfMain } from './wl_main';

document.addEventListener('DOMContentLoaded', async () => {
    try {
        await wolfMain();
    } catch (err) {
        console.error('Wolf3D failed to start:', err);
        const loadingEl = document.getElementById('loading');
        if (loadingEl) {
            loadingEl.style.display = 'block';
            loadingEl.textContent = `Error: ${(err as Error).message}`;
        }
    }
});
