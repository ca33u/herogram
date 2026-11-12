// Crop page logic outside the browser: node tests/crop_test.mjs
import { readFileSync } from "node:fs";
const html = readFileSync(new URL("../Crop.html", import.meta.url), "utf8");
const src = html.split("// <logic>")[1].split("// </logic>")[0];
const { FORMATS, findCard, pickFormat, snap, decodeTGA, steps } =
  new Function(src + "; return { FORMATS, findCard, pickFormat, snap, decodeTGA, steps };")();

let total = 0, fails = 0;
const check = (cond, msg) => { total++; if (!cond) fails++; console.log((cond ? "ok    " : "FAIL  ") + msg); };

// A screenshot: black screen with JPEG-like noise, a dark card with a
// darker vignette edge and brighter middle.
function shot(W, H, card, seed = 1) {
  let s = seed;
  const rnd = () => ((s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
  const px = new Uint8ClampedArray(W * H * 4);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = (y * W + x) * 4;
    const inCard = x >= card.x && x < card.x + card.w && y >= card.y && y < card.y + card.h;
    let v = inCard ? 18 : 0;
    if (inCard && x > card.x + card.w * 0.2 && x < card.x + card.w * 0.8 && y > card.y + card.h * 0.2 && y < card.y + card.h * 0.8) v = 120;
    const n = Math.round((rnd() - 0.5) * 8);
    px[i] = v + n; px[i + 1] = v + n; px[i + 2] = v + 6 + n; px[i + 3] = 255;
  }
  return px;
}

const W = 1512, H = 982;
for (const f of FORMATS) {
  const k = Math.min(W * 0.96 / f.w, H * 0.96 / f.h);
  const cw = Math.round(f.w * k), ch = Math.round(f.h * k);
  const card = { x: Math.round((W - cw) / 2), y: Math.round((H - ch) / 2), w: cw, h: ch };
  const box = findCard(shot(W, H, card, f.w), W, H);
  check(box.found && Math.abs(box.x - card.x) <= 1 && Math.abs(box.y - card.y) <= 1 && Math.abs(box.w - cw) <= 2 && Math.abs(box.h - ch) <= 2,
    `${f.key}: card found on the black screen`);
  const fmt = pickFormat(box.w, box.h);
  check(fmt.key === f.key, `${f.key}: format recognised by its shape`);
  const sn = snap(box, fmt, W, H);
  check(Math.abs(sn.w / sn.h - fmt.w / fmt.h) < 0.005 && sn.x >= 0 && sn.y >= 0 && sn.x + sn.w <= W && sn.y + sn.h <= H,
    `${f.key}: crop has the exact shape and stays inside`);
}

const plain = new Uint8ClampedArray(500 * 300 * 4).fill(90);
const none = findCard(plain, 500, 300);
check(!none.found && none.w === 500 && none.h === 300, "no black border: the whole picture, marked as not found");
const sn = snap(none, pickFormat(500, 300), 500, 300);
check(sn.w <= 500 && sn.h <= 300 && Math.abs(sn.w / sn.h - 16 / 9) < 0.01, "then a centred crop of the nearest shape");
check(!findCard(new Uint8ClampedArray(40 * 40 * 4), 40, 40).found, "all black: nothing found");

// TGA: 2x2, 24 bit, bottom-left origin, raw and RLE
const header = (type, desc) => [0, 0, type, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 24, desc];
const bgr = [[0, 0, 255], [0, 255, 0], [255, 0, 0], [255, 255, 255]]; // red green / blue white (bottom row first)
const raw = decodeTGA(new Uint8Array([...header(2, 0), ...bgr.flat()]).buffer);
check(raw.w === 2 && raw.px[0] === 0 && raw.px[2] === 255 && raw.px[8] === 255 && raw.px[9] === 0, "TGA: bottom-left rows flipped to the top");
const rle = decodeTGA(new Uint8Array([...header(10, 0x20), 0x83, 10, 20, 30]).buffer);
check([...rle.px].join(",") === "30,20,10,255,".repeat(4).slice(0, -1), "TGA: run-length packets");
let threw = false;
try { decodeTGA(new Uint8Array([0, 1, 1, ...new Array(15).fill(0)]).buffer); } catch { threw = true; }
check(threw, "TGA with a palette is refused with a message");

check(steps(4000, 1080).join(",") === "2000,1080" && steps(900, 1080).join(",") === "1080", "resize steps halve, never more than 2x at once");

console.log(`crop_test: ${total} checks, ${fails} failed`);
process.exit(fails ? 1 : 0);
