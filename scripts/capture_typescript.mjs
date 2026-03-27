// capture_typescript.mjs
// Playwright automation script to capture screenshots from the Wolf3D TypeScript port
// Usage: Start Vite dev server first (npx vite --port 3000), then run:
//   node scripts/capture_typescript.mjs

import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const CAPTURE_DIR = 'comparison_output/typescript_frames';
fs.mkdirSync(CAPTURE_DIR, { recursive: true });

// Collect browser console output and errors
const browserLogs = [];
const browserErrors = [];

console.log('Launching Chromium...');
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1024, height: 768 } });

// Listen for browser console messages and errors
page.on('console', msg => {
    const text = `[${msg.type()}] ${msg.text()}`;
    browserLogs.push(text);
    console.log(`BROWSER: ${text}`);
});
page.on('pageerror', err => {
    browserErrors.push(err.message);
    console.log(`PAGE ERROR: ${err.message}`);
});

// Navigate to the game
console.log('Navigating to http://localhost:3000 ...');
await page.goto('http://localhost:3000', { waitUntil: 'domcontentloaded' });

// Wait for canvas to appear
try {
    await page.waitForSelector('canvas', { timeout: 15000 });
    console.log('Canvas element found.');
} catch (e) {
    console.error('ERROR: Canvas element not found within 15 seconds.');
    console.error('Browser logs:', browserLogs.join('\n'));
    await browser.close();
    process.exit(1);
}

// Wait for initial rendering / game init to settle
await page.waitForTimeout(3000);

// Capture canvas pixels as a PNG, with diagnostics
async function captureCanvas(name) {
    // First, get the canvas data URL
    const dataUrl = await page.evaluate(() => {
        const canvas = document.querySelector('canvas');
        if (!canvas) return null;
        return canvas.toDataURL('image/png');
    });

    if (!dataUrl) {
        console.log(`FAILED to capture: ${name} (no canvas found)`);
        return false;
    }

    const base64 = dataUrl.replace(/^data:image\/png;base64,/, '');
    const buffer = Buffer.from(base64, 'base64');
    const filePath = path.join(CAPTURE_DIR, `${name}.png`);
    fs.writeFileSync(filePath, buffer);

    // Analyze the canvas pixels
    const pixelInfo = await page.evaluate(() => {
        const canvas = document.querySelector('canvas');
        if (!canvas) return null;
        const ctx = canvas.getContext('2d');
        if (!ctx) return null;
        const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
        let nonBlack = 0;
        let uniqueColors = new Set();
        for (let i = 0; i < data.length; i += 4) {
            const r = data[i], g = data[i+1], b = data[i+2];
            if (r > 0 || g > 0 || b > 0) nonBlack++;
            if (i % 400 === 0) {
                uniqueColors.add(`${r},${g},${b}`);
            }
        }
        return {
            width: canvas.width,
            height: canvas.height,
            totalPixels: data.length / 4,
            nonBlackPixels: nonBlack,
            uniqueColorsSampled: uniqueColors.size
        };
    });

    const status = pixelInfo?.nonBlackPixels > 0 ? 'HAS CONTENT' : 'ALL BLACK';
    console.log(`Captured: ${name}.png [${status}] (${pixelInfo?.width}x${pixelInfo?.height}, ` +
        `${pixelInfo?.nonBlackPixels} non-black pixels, ` +
        `${pixelInfo?.uniqueColorsSampled} unique colors sampled)`);

    // Also take a full page screenshot for debugging (shows error messages, loading state, etc.)
    await page.screenshot({ path: path.join(CAPTURE_DIR, `${name}_fullpage.png`) });

    return pixelInfo?.nonBlackPixels > 0;
}

// Diagnostic: inspect the internal game state via Vite's HMR module system
async function diagnoseGameState() {
    console.log('\n=== Game State Diagnostics ===');

    const diag = await page.evaluate(() => {
        // Try to access the game's internal state through the module system
        // Since Vite uses ESM, we can try window.__wolf3d or exposed globals
        const canvas = document.querySelector('canvas');
        const info = {
            canvasExists: !!canvas,
            canvasWidth: canvas?.width,
            canvasHeight: canvas?.height,
            loadingVisible: document.getElementById('loading')?.style.display !== 'none',
            loadingText: document.getElementById('loading')?.textContent,
            documentTitle: document.title,
            bodyChildCount: document.body.children.length,
        };

        // Check canvas has any non-transparent pixels at all
        if (canvas) {
            const ctx = canvas.getContext('2d');
            if (ctx) {
                const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
                let hasAlpha = false;
                let hasColor = false;
                for (let i = 0; i < data.length; i += 4) {
                    if (data[i+3] > 0) hasAlpha = true;
                    if (data[i] > 0 || data[i+1] > 0 || data[i+2] > 0) hasColor = true;
                    if (hasAlpha && hasColor) break;
                }
                info.canvasHasAlphaPixels = hasAlpha;
                info.canvasHasColorPixels = hasColor;
            }
        }

        return info;
    });

    for (const [key, value] of Object.entries(diag)) {
        console.log(`  ${key}: ${JSON.stringify(value)}`);
    }
}

// Schedule of actions: captures and key presses to navigate through game screens
// The TypeScript port's DemoLoop shows: TITLEPIC -> waits for key -> clears screen
// Since the palette may not be loaded (known issue), all frames may appear black.
const schedule = [
    { time: 0,     action: 'capture', name: '01_initial' },
    { time: 1000,  action: 'key',     key: 'Space' },      // Dismiss signon / title screen
    { time: 2000,  action: 'capture', name: '02_after_signon' },
    { time: 3000,  action: 'key',     key: 'Space' },      // Dismiss PC-13 screen
    { time: 5000,  action: 'capture', name: '03_after_pc13' },
    { time: 6000,  action: 'key',     key: 'Space' },      // Dismiss title screen
    { time: 8000,  action: 'capture', name: '04_title_or_menu' },
    { time: 9000,  action: 'key',     key: 'Space' },      // Extra dismiss
    { time: 10000, action: 'capture', name: '05_menu' },
    { time: 11000, action: 'key',     key: 'Enter' },      // Select "New Game"
    { time: 13000, action: 'capture', name: '06_episode_select' },
    { time: 14000, action: 'key',     key: 'Enter' },      // Select first episode
    { time: 16000, action: 'capture', name: '07_difficulty' },
    { time: 17000, action: 'key',     key: 'Enter' },      // Select difficulty
    { time: 20000, action: 'capture', name: '08_get_psyched' },
    { time: 23000, action: 'capture', name: '09_gameplay' },
    // Move forward in game
    { time: 24000, action: 'keydown', key: 'ArrowUp' },
    { time: 26000, action: 'keyup',   key: 'ArrowUp' },
    { time: 26500, action: 'capture', name: '10_gameplay_moved' },
];

console.log('\nStarting capture schedule...\n');
let startTime = Date.now();
let anyHasContent = false;

for (const event of schedule) {
    const elapsed = Date.now() - startTime;
    const wait = event.time - elapsed;
    if (wait > 0) await page.waitForTimeout(wait);

    if (event.action === 'capture') {
        const hasContent = await captureCanvas(event.name);
        if (hasContent) anyHasContent = true;
    } else if (event.action === 'key') {
        await page.keyboard.press(event.key);
        console.log(`Key press: ${event.key} (at ${event.time}ms)`);
    } else if (event.action === 'keydown') {
        await page.keyboard.down(event.key);
        console.log(`Key down: ${event.key} (at ${event.time}ms)`);
    } else if (event.action === 'keyup') {
        await page.keyboard.up(event.key);
        console.log(`Key up: ${event.key} (at ${event.time}ms)`);
    }
}

// Final summary capture
await page.waitForTimeout(1000);
const finalHasContent = await captureCanvas('11_final');
if (finalHasContent) anyHasContent = true;

// Run diagnostics
await diagnoseGameState();

await browser.close();

// Summary
console.log('\n=== Capture Summary ===');
const files = fs.readdirSync(CAPTURE_DIR).filter(f => f.endsWith('.png') && !f.includes('fullpage'));
console.log(`Total canvas PNG files in ${CAPTURE_DIR}: ${files.length}`);
files.forEach(f => {
    const stats = fs.statSync(path.join(CAPTURE_DIR, f));
    console.log(`  ${f} (${stats.size} bytes)`);
});

if (browserErrors.length > 0) {
    console.log(`\nBrowser errors encountered: ${browserErrors.length}`);
    browserErrors.forEach(e => console.log(`  ERROR: ${e}`));
} else {
    console.log('\nNo browser errors encountered.');
}

if (!anyHasContent) {
    console.log('\nWARNING: All captured frames are black/blank.');
    console.log('This is likely because the TypeScript port has an incomplete rendering pipeline.');
    console.log('Known issues:');
    console.log('  - The VGA palette is initialized to all zeros (black) in VL_Startup()');
    console.log('  - DemoLoop loads TITLEPIC into screenbuf but does not set the game palette');
    console.log('  - The game loop ("GameLoop") is not yet implemented');
    console.log('  - VL_UpdateScreen() maps screenbuf through the palette, producing all black');
    console.log('\nThe capture infrastructure is working correctly. The TypeScript port needs');
    console.log('the palette loading and full game loop to be implemented for visible output.');
}

console.log('\nDone!');
