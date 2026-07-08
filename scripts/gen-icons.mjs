// Generates DeskMate PWA icons as real PNGs (no external deps).
// Draws the Toss-blue app tile with a white calendar glyph.
import { deflateSync } from 'node:zlib'
import { writeFileSync, mkdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'icons')
mkdirSync(OUT, { recursive: true })

const BLUE = [49, 130, 246]
const WHITE = [255, 255, 255]

function crc32(buf) {
  let c = ~0
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i]
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1))
  }
  return ~c >>> 0
}
function chunk(type, data) {
  const len = Buffer.alloc(4)
  len.writeUInt32BE(data.length)
  const td = Buffer.concat([Buffer.from(type), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(td))
  return Buffer.concat([len, td, crc])
}
function encodePNG(w, h, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(w, 0)
  ihdr.writeUInt32BE(h, 4)
  ihdr[8] = 8 // bit depth
  ihdr[9] = 6 // RGBA
  const raw = Buffer.alloc((w * 4 + 1) * h)
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4)
  }
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

function make(size, maskable = false) {
  const buf = Buffer.alloc(size * size * 4)
  const set = (x, y, [r, g, b], a = 255) => {
    if (x < 0 || y < 0 || x >= size || y >= size) return
    const i = (y * size + x) * 4
    // simple over-blend on existing
    const ia = a / 255
    buf[i] = r * ia + buf[i] * (1 - ia)
    buf[i + 1] = g * ia + buf[i + 1] * (1 - ia)
    buf[i + 2] = b * ia + buf[i + 2] * (1 - ia)
    buf[i + 3] = Math.max(buf[i + 3], a)
  }
  const rr = (x0, y0, w, h, rad, col) => {
    for (let y = 0; y < h; y++)
      for (let x = 0; x < w; x++) {
        const dx = Math.min(x, w - 1 - x)
        const dy = Math.min(y, h - 1 - y)
        if (dx < rad && dy < rad) {
          const d = Math.hypot(rad - dx, rad - dy)
          if (d > rad) continue
        }
        set(x0 + x, y0 + y, col)
      }
  }

  // Background tile. Maskable => full bleed; regular => rounded square.
  if (maskable) rr(0, 0, size, size, 0, BLUE)
  else rr(0, 0, size, size, Math.round(size * 0.22), BLUE)

  // Calendar glyph (white) centered, ~52% of tile.
  const g = Math.round(size * 0.5)
  const gx = Math.round((size - g) / 2)
  const gy = Math.round((size - g) / 2) + Math.round(size * 0.03)
  const r = Math.round(g * 0.14)
  rr(gx, gy, g, g, r, WHITE)
  // top binding tabs
  const tabW = Math.round(g * 0.12)
  const tabH = Math.round(g * 0.16)
  rr(gx + Math.round(g * 0.24), gy - Math.round(tabH * 0.5), tabW, tabH, Math.round(tabW / 2), WHITE)
  rr(gx + Math.round(g * 0.64), gy - Math.round(tabH * 0.5), tabW, tabH, Math.round(tabW / 2), WHITE)
  // header band (blue)
  rr(gx, gy, g, Math.round(g * 0.26), r, BLUE)
  rr(gx, gy + Math.round(g * 0.16), g, Math.round(g * 0.1), 0, BLUE)
  // one highlighted day (blue dot) to echo "my shift"
  const cell = Math.round(g * 0.16)
  rr(
    gx + Math.round(g * 0.56),
    gy + Math.round(g * 0.52),
    cell,
    cell,
    Math.round(cell / 2),
    BLUE
  )
  return encodePNG(size, size, buf)
}

writeFileSync(join(OUT, 'icon-192.png'), make(192))
writeFileSync(join(OUT, 'icon-512.png'), make(512))
writeFileSync(join(OUT, 'icon-512-maskable.png'), make(512, true))
console.log('Icons written to', OUT)
