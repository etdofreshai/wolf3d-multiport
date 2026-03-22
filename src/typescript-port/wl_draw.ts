// WL_DRAW.TS
// Ported from WL_DRAW.C - 3D rendering engine (raycaster)

import * as VL from './id_vl';
import * as PM from './id_pm';
import {
    MAXVIEWWIDTH, MAXSCALEHEIGHT, ANGLES, FINEANGLES, GLOBAL1, TILEGLOBAL,
    TILESHIFT, MAPSIZE, MINDIST, ANG90, ANG180, ANG270, ANG360,
    SCREENWIDTH, SCREENSIZE,
    objtype, classtype, activetype, FL_VISABLE,
    tilemap, spotvis, actorat,
} from './wl_def';
import {
    viewwidth, viewheight, focallength, centerx,
    sintable, costable, finetangent, pixelangle,
    heightnumerator, screenloc, freelatch,
    scale,
} from './wl_main';
import { player } from './wl_play';

//===========================================================================
// Global variables
//===========================================================================

export let lasttimecount: number = 0;
export let frameon: number = 0;
export let fizzlein = false;

export const wallheight: Uint32Array = new Uint32Array(MAXVIEWWIDTH);

// Refresh variables
export let viewx: number = 0;
export let viewy: number = 0;
export let viewangle: number = 0;
export let viewsin: number = 0;
export let viewcos: number = 0;

export let postsource: Uint8Array | null = null;
export let postx: number = 0;
export let postwidth: number = 0;

// Wall textures
export const horizwall: number[] = new Array(MAPSIZE * MAPSIZE).fill(0);
export const vertwall: number[] = new Array(MAPSIZE * MAPSIZE).fill(0);

export let pwallpos: number = 0;

//===========================================================================
// FixedByFrac - fixed point multiply
//===========================================================================

export function FixedByFrac(a: number, b: number): number {
    return ((a * b) >> 16) | 0;
}

//===========================================================================
// TransformActor
//===========================================================================

export function TransformActor(ob: objtype): void {
    // Transform actor position to view space
    const gx = ob.x - viewx;
    const gy = ob.y - viewy;

    // Rotate around view angle
    const gxt = FixedByFrac(gx, viewcos) - FixedByFrac(gy, viewsin);
    const gyt = FixedByFrac(gy, viewcos) + FixedByFrac(gx, viewsin);

    ob.transx = gxt;
    ob.transy = gyt;

    // Calculate screen column
    if (gxt >= MINDIST) {
        ob.viewx = centerx + ((gyt * scale / gxt) | 0);
        ob.viewheight = ((heightnumerator / gxt) >> 16) | 0;
    } else {
        ob.viewheight = 0;
    }
}

//===========================================================================
// BuildTables (called from WL_MAIN)
//===========================================================================

export function BuildTables(): void {
    // Already built in wl_main.ts
}

//===========================================================================
// ClearScreen
//===========================================================================

export function ClearScreen(): void {
    // Clear the 3D view area
    // Top half = ceiling color, bottom half = floor color
    const ceiling = 0x1d;  // Dark gray
    const floor = 0x19;    // Dark brown

    const startY = (200 - 40 - viewheight) >> 1;
    const midY = startY + (viewheight >> 1);
    const endY = startY + viewheight;

    for (let y = startY; y < midY; y++) {
        VL.screenbuf.fill(ceiling, y * 320, y * 320 + 320);
    }
    for (let y = midY; y < endY; y++) {
        VL.screenbuf.fill(floor, y * 320, y * 320 + 320);
    }
}

//===========================================================================
// CalcRotate
//===========================================================================

export function CalcRotate(ob: objtype): number {
    let angle = Math.atan2(ob.transx, ob.transy);
    angle = (angle * (ANGLES / (2 * Math.PI))) | 0;
    angle -= ob.angle;
    if (angle >= ANGLES) angle -= ANGLES;
    if (angle < 0) angle += ANGLES;

    // 8 rotation frames
    const rotation = ((angle + ANGLES / 16) % ANGLES) / (ANGLES / 8);
    return (rotation | 0) & 7;
}

//===========================================================================
// ScalePost - draw a single vertical wall strip
//===========================================================================

function ScalePost(x: number, height: number, source: Uint8Array, sourceOfs: number): void {
    if (height <= 0 || x < 0 || x >= viewwidth) return;

    const startY = ((200 - 40 - height) >> 1);
    const endY = startY + height;

    const step = (64 << 16) / height;
    let frac = 0;

    const baseX = ((320 - viewwidth) >> 1) + x;

    for (let y = Math.max(startY, 0); y < Math.min(endY, 200); y++) {
        const texY = (frac >> 16) & 63;
        frac += step;
        const pixel = source[sourceOfs + texY];
        if (pixel !== 0) {
            VL.screenbuf[y * 320 + baseX] = pixel;
        }
    }
}

//===========================================================================
// DrawScaleds - draw all visible sprites
//===========================================================================

export function DrawScaleds(): void {
    // Iterate through visible objects and draw them
    // This would use ScaleShape from wl_scale.ts
}

//===========================================================================
// FixOfs
//===========================================================================

export function FixOfs(): void {
    VL.setBufferOfs(screenloc[0]);
    VL.setDisplayOfs(screenloc[0]);
}

//===========================================================================
// ThreeDRefresh - main 3D rendering function
//===========================================================================

export function ThreeDRefresh(): void {
    if (!player) return;

    frameon++;

    // Set up view variables
    viewx = player.x;
    viewy = player.y;
    viewangle = player.angle;

    if (viewangle >= 0 && viewangle < sintable.length) {
        viewsin = sintable[viewangle];
        viewcos = costable[viewangle] || sintable[viewangle + 90] || 0;
    }

    // Clear the view
    ClearScreen();

    // Clear spotvis
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            spotvis[x][y] = 0;
        }
    }

    // Cast rays for each column
    WallRefresh();

    // Draw sprites
    DrawScaleds();

    // Present
    VL.VL_UpdateScreen();
}

//===========================================================================
// WallRefresh - cast rays and draw walls
//===========================================================================

function WallRefresh(): void {
    // For each screen column, cast a ray and find the nearest wall
    for (let col = 0; col < viewwidth; col++) {
        const angle = (viewangle + pixelangle[col] + FINEANGLES) % FINEANGLES;

        // Simple DDA raycaster
        const rayAngle = ((viewangle * FINEANGLES / ANGLES) + pixelangle[col] + FINEANGLES) % FINEANGLES;
        const rayRad = (rayAngle / FINEANGLES) * Math.PI * 2;

        const dirX = Math.cos(rayRad);
        const dirY = -Math.sin(rayRad);

        // Player position in tile space
        const posX = viewx / TILEGLOBAL;
        const posY = viewy / TILEGLOBAL;

        let mapX = posX | 0;
        let mapY = posY | 0;

        // Delta distances
        const deltaDistX = Math.abs(1 / (dirX || 0.0001));
        const deltaDistY = Math.abs(1 / (dirY || 0.0001));

        let stepX: number, stepY: number;
        let sideDistX: number, sideDistY: number;

        if (dirX < 0) {
            stepX = -1;
            sideDistX = (posX - mapX) * deltaDistX;
        } else {
            stepX = 1;
            sideDistX = (mapX + 1.0 - posX) * deltaDistX;
        }
        if (dirY < 0) {
            stepY = -1;
            sideDistY = (posY - mapY) * deltaDistY;
        } else {
            stepY = 1;
            sideDistY = (mapY + 1.0 - posY) * deltaDistY;
        }

        // DDA
        let hit = false;
        let side = 0;
        let maxSteps = 64;

        while (!hit && maxSteps-- > 0) {
            if (sideDistX < sideDistY) {
                sideDistX += deltaDistX;
                mapX += stepX;
                side = 0;
            } else {
                sideDistY += deltaDistY;
                mapY += stepY;
                side = 1;
            }

            if (mapX < 0 || mapX >= MAPSIZE || mapY < 0 || mapY >= MAPSIZE) break;

            if (tilemap[mapX][mapY] > 0) {
                hit = true;
            }
        }

        if (hit) {
            // Calculate perpendicular distance
            let perpWallDist: number;
            if (side === 0)
                perpWallDist = (mapX - posX + (1 - stepX) / 2) / (dirX || 0.0001);
            else
                perpWallDist = (mapY - posY + (1 - stepY) / 2) / (dirY || 0.0001);

            perpWallDist = Math.abs(perpWallDist);

            // Calculate wall height
            let lineHeight = ((viewheight / perpWallDist) | 0);
            if (lineHeight > 500) lineHeight = 500;

            wallheight[col] = lineHeight;

            // Calculate texture coordinate
            let wallX: number;
            if (side === 0)
                wallX = posY + perpWallDist * dirY;
            else
                wallX = posX + perpWallDist * dirX;
            wallX -= Math.floor(wallX);

            // Get wall texture from VSWAP
            const tileVal = tilemap[mapX][mapY];
            const texNum = (tileVal - 1) * 2 + side;

            // Draw the column using the wall texture
            const texPage = PM.PM_GetPage(texNum);
            if (texPage) {
                const texX = (wallX * 64) | 0;
                const drawStart = ((200 - 40 - lineHeight) >> 1);
                const drawEnd = drawStart + lineHeight;
                const step = 64.0 / lineHeight;
                let texPos = 0;

                const baseX = ((320 - viewwidth) >> 1) + col;

                for (let y = Math.max(0, drawStart); y < Math.min(200, drawEnd); y++) {
                    if (y < drawStart) continue;
                    const texY = (texPos | 0) & 63;
                    texPos += step;
                    const pixel = texPage[texX * 64 + texY];

                    // Apply shading for side walls
                    VL.screenbuf[y * 320 + baseX] = pixel;
                }
            } else {
                // No texture - draw solid color based on tile
                const color = side === 0 ? (tileVal + 1) : (tileVal + 17);
                const drawStart = Math.max(0, ((200 - 40 - lineHeight) >> 1));
                const drawEnd = Math.min(200, drawStart + lineHeight);
                const baseX = ((320 - viewwidth) >> 1) + col;
                for (let y = drawStart; y < drawEnd; y++) {
                    VL.screenbuf[y * 320 + baseX] = color & 0xff;
                }
            }

            // Mark this tile as visible
            if (mapX >= 0 && mapX < MAPSIZE && mapY >= 0 && mapY < MAPSIZE)
                spotvis[mapX][mapY] = 1;
        }
    }
}

//===========================================================================
// FarScalePost
//===========================================================================

export function FarScalePost(): void {
    // Stub - used for far wall rendering
}
