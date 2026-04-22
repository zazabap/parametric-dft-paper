#import "@preview/cetz:0.4.2": canvas, draw
#set page(width: auto, height: auto, margin: 8pt)

// Horizontal axis showing classical transforms (FFT, DCT, QFT-learned, BlockDCT)
// positioned by effective block side, annotated with 20%-keep PSNR.
//
// Convention: the x-coordinate is -log2(block_side / 256) = log2(256 / block_side).
// So block 256 -> x=0, block 128 -> x=1, block 64 -> x=2, ..., block 8 -> x=5.
// Reading left-to-right: "full image" on the left, "smallest block" on the right.

#canvas({
  import draw: *

  // ----------------------------------------------------------------
  // Axis
  // ----------------------------------------------------------------
  let x0 = 0.0
  let x1 = 10.0
  // x positions along the axis
  let x_fft  = 0.5
  let x_dct  = 1.5
  let x_qft  = 6.0
  let x_bdct = 8.5
  let y_axis = 0.0

  // Horizontal arrow (axis)
  line((x0, y_axis), (x1, y_axis), mark: (end: "straight"), stroke: (thickness: 1pt))
  content((x1, y_axis), padding: 0.15, anchor: "west", text(9pt, weight: "bold")[block side $arrow.r$])
  content((x0, y_axis), padding: 0.15, anchor: "east", text(9pt)[full image])

  // Axis tick labels (block side in pixels)
  let ticks = (
    (x_fft,  "256 px"),
    (x_qft,  "16 px"),
    (x_bdct, "8 px"),
  )
  for (xp, lbl) in ticks {
    line((xp, y_axis - 0.1), (xp, y_axis + 0.1), stroke: 0.8pt)
    content((xp, y_axis - 0.35), text(8pt)[#lbl])
  }

  // ----------------------------------------------------------------
  // Marker boxes for each transform, sitting above the axis.
  // Each box: colored fill, centered on x, label + PSNR.
  // ----------------------------------------------------------------
  let marker(xp, title, psnr, fill_color, y_offset: 1.4) = {
    // Vertical tether from the axis up to the marker
    line((xp, y_axis + 0.1), (xp, y_offset - 0.45), stroke: (dash: "dashed", thickness: 0.5pt))
    // Marker box
    rect((xp - 0.75, y_offset - 0.45), (xp + 0.75, y_offset + 0.55),
         fill: fill_color, stroke: (thickness: 0.8pt), radius: 0.08)
    content((xp, y_offset + 0.25), text(9pt, weight: "bold", fill: black)[#title])
    content((xp, y_offset - 0.15), text(8pt, fill: black)[#psnr])
  }

  marker(x_fft,  [FFT],          [25.5 dB],         rgb("#e6f0ff"))
  marker(x_dct,  [DCT],          [26.8 dB],         rgb("#e6f0ff"))
  marker(x_qft,  [QFT (learned)],[29.4 dB],         rgb("#fff1cc"))
  marker(x_bdct, [BlockDCT 8×8], [31.3 dB],         rgb("#ffe1d6"))

  // A second badge noting "learned" above QFT and "hand-designed" above others.
  let badge(xp, txt, y_offset: 2.6) = {
    content((xp, y_offset), text(7pt, style: "italic", fill: rgb("#555"))[#txt])
  }
  badge(x_fft,  [hand-designed])
  badge(x_qft,  [emergent from training])
  badge(x_bdct, [hand-designed])

  // Arrow from initialization (FFT) to trained QFT, annotated "training".
  bezier((x_fft + 0.2, 1.75), (x_qft - 0.2, 1.75),
         (x_fft + 2.0, 3.2), (x_qft - 2.0, 3.2),
         stroke: (thickness: 0.9pt, paint: rgb("#c85")),
         mark: (end: "straight"))
  content(((x_fft + x_qft) / 2, 2.85), text(8.5pt, fill: rgb("#a63"), weight: "bold")[end-to-end training])

  // Bracket noting "+1.3 dB: basis" and "+4.5 dB: block size" under the axis,
  // to reinforce the thesis that block size is the dominant effect.
  let bracket_y = y_axis - 0.85
  let br_lw = 0.7pt
  // FFT -> DCT
  line((x_fft, bracket_y + 0.15), (x_fft, bracket_y), stroke: br_lw)
  line((x_fft, bracket_y), (x_dct, bracket_y), stroke: br_lw)
  line((x_dct, bracket_y), (x_dct, bracket_y + 0.15), stroke: br_lw)
  content(((x_fft + x_dct)/2, bracket_y - 0.25), text(7.5pt)[+1.3 dB (basis)])
  // DCT -> BDCT
  line((x_dct, bracket_y + 0.15), (x_dct, bracket_y), stroke: br_lw)
  line((x_dct, bracket_y), (x_bdct, bracket_y), stroke: br_lw)
  line((x_bdct, bracket_y), (x_bdct, bracket_y + 0.15), stroke: br_lw)
  content(((x_dct + x_bdct)/2, bracket_y - 0.25), text(7.5pt, weight: "bold")[+4.5 dB (block size)])
})
