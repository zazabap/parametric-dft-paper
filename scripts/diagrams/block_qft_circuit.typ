#import "@preview/cetz:0.4.2": canvas, draw
#set page(width: auto, height: auto, margin: 8pt)

// Block-wrapper diagram. The full image is reshaped into a grid of B x B blocks,
// each transformed by the same parametric inner circuit U(theta), and the
// coefficients are reassembled into the same shape as the input.
//
// Three panels read left-to-right:
//   (a) image -> grid of blocks (reshape)
//   (b) within-block parametric circuit (applied identically to every block)
//   (c) reassembled coefficient grid

#figure(canvas({
  import draw: *

  // ------------------------------------------------------------------
  // Panel (a): full image, with block grid overlay.
  // ------------------------------------------------------------------
  let img_x = 0.0
  let img_y = 0.0
  let img_size = 2.4
  rect(
    (img_x, img_y),
    (img_x + img_size, img_y + img_size),
    fill: rgb("#eef2f8"),
    stroke: (thickness: 0.7pt),
    name: "img",
  )
  // Coarse grid lines (4x4 grid for visual clarity, representing the 32x32 tiling)
  let n_grid = 4
  let step = img_size / n_grid
  for i in range(1, n_grid) {
    line(
      (img_x + i * step, img_y),
      (img_x + i * step, img_y + img_size),
      stroke: (thickness: 0.4pt, paint: gray, dash: "dotted"),
    )
    line(
      (img_x, img_y + i * step),
      (img_x + img_size, img_y + i * step),
      stroke: (thickness: 0.4pt, paint: gray, dash: "dotted"),
    )
  }
  // Highlight one representative block
  rect(
    (img_x + step, img_y + 2 * step),
    (img_x + 2 * step, img_y + 3 * step),
    fill: rgb("#ffd9b3"),
    stroke: (thickness: 0.8pt, paint: rgb("#a55")),
  )
  content(
    (img_x + img_size / 2, img_y - 0.45),
    text(9pt)[image $bold(x) in RR^(N times N)$],
  )
  content(
    (img_x + img_size / 2, img_y - 0.85),
    text(8pt, fill: gray)[reshape into $(N\/b)^2$ blocks of side $b$],
  )

  // L-shaped arrow from the highlighted block: first horizontal right,
  // then vertical down to point at the inner circuit panel.
  let block_cx = img_x + 1.5 * step
  let block_cy = img_y + 2.5 * step
  let block_right_x = img_x + 2 * step
  let elbow_x = img_x + img_size + 0.9
  let circuit_top_y = 0.55
  // Horizontal segment
  line(
    (block_right_x, block_cy),
    (elbow_x, block_cy),
    stroke: (thickness: 0.9pt),
  )
  // Vertical segment with arrow head landing at the top of the inner circuit
  line(
    (elbow_x, block_cy),
    (elbow_x, circuit_top_y + 0.05),
    mark: (end: "straight"),
    stroke: (thickness: 0.9pt),
  )
  content(
    (elbow_x + 0.45, (block_cy + circuit_top_y) / 2 + 0.2),
    anchor: "west",
    text(8pt, fill: gray)[same $U(theta)$ \ per block],
  )

  // ------------------------------------------------------------------
  // Panel (b): within-block parametric circuit.
  // We sketch a 3-qubit (b = 8) circuit: H on each qubit + CP chain.
  // ------------------------------------------------------------------
  let cb_x = img_x + img_size + 1.6
  let dy = 0.7
  let m = 3
  // Wires
  for i in range(m) {
    let y = -i * dy
    line(
      (cb_x, y),
      (cb_x + 3.4, y),
      stroke: (thickness: 0.5pt),
    )
    content((cb_x - 0.3, y), text(8pt)[$q_#i$])
    content((cb_x + 3.7, y), text(8pt)[$q'_#i$])
  }
  // Hadamard gates
  for i in range(m) {
    let y = -i * dy
    rect(
      (cb_x + 0.2 + i * 0.0, y - 0.22),
      (cb_x + 0.65, y + 0.22),
      fill: white,
      stroke: 0.7pt,
    )
    content((cb_x + 0.42, y), text(8pt)[$H$])
  }
  // Controlled-phase chain (q0 with q1, q2; q1 with q2)
  let cp_xs = (1.2, 1.9, 2.6)
  let pairs = ((0, 1), (0, 2), (1, 2))
  let cp_idx = 1
  for (xp, pair) in cp_xs.zip(pairs) {
    let (a, b) = pair
    let ya = -a * dy
    let yb = -b * dy
    line((cb_x + xp, ya), (cb_x + xp, yb), stroke: 0.7pt)
    circle((cb_x + xp, ya), radius: 0.06, fill: black, stroke: none)
    rect(
      (cb_x + xp - 0.18, (ya + yb) / 2 - 0.18),
      (cb_x + xp + 0.18, (ya + yb) / 2 + 0.18),
      fill: white,
      stroke: 0.7pt,
    )
    content((cb_x + xp, (ya + yb) / 2), text(7pt)[$M$])
  }

  // Frame around the inner circuit, labelled U(theta)
  rect(
    (cb_x - 0.1, -2 * dy - 0.5),
    (cb_x + 3.5, 0.5),
    stroke: (thickness: 0.6pt, paint: rgb("#a55"), dash: "dashed"),
  )
  content(
    (cb_x + 1.7, -2 * dy - 0.85),
    text(9pt, fill: rgb("#a55"))[shared inner $U(theta) in U(2^m)$],
  )

  // Arrow from circuit panel to output panel
  let out_x = cb_x + 4.0
  line(
    (cb_x + 3.6, -dy),
    (out_x - 0.2, -dy),
    mark: (end: "straight"),
    stroke: (thickness: 0.9pt),
  )

  // ------------------------------------------------------------------
  // Panel (c): coefficient grid.
  // ------------------------------------------------------------------
  let coef_x = out_x
  let coef_y = -dy - img_size / 2
  rect(
    (coef_x, coef_y),
    (coef_x + img_size, coef_y + img_size),
    fill: rgb("#f4ece2"),
    stroke: (thickness: 0.7pt),
    name: "coef",
  )
  for i in range(1, n_grid) {
    line(
      (coef_x + i * step, coef_y),
      (coef_x + i * step, coef_y + img_size),
      stroke: (thickness: 0.4pt, paint: gray, dash: "dotted"),
    )
    line(
      (coef_x, coef_y + i * step),
      (coef_x + img_size, coef_y + i * step),
      stroke: (thickness: 0.4pt, paint: gray, dash: "dotted"),
    )
  }
  // Concentrate small dark dots in one corner of each block
  for ix in range(n_grid) {
    for iy in range(n_grid) {
      let bx = coef_x + ix * step
      let by = coef_y + iy * step + step
      circle((bx + 0.12, by - 0.12), radius: 0.06, fill: rgb("#222"), stroke: none)
      circle((bx + 0.30, by - 0.12), radius: 0.04, fill: rgb("#555"), stroke: none)
      circle((bx + 0.12, by - 0.30), radius: 0.04, fill: rgb("#555"), stroke: none)
    }
  }
  content(
    (coef_x + img_size / 2, coef_y - 0.45),
    text(9pt)[coefficients $bold(y) = U(theta)(bold(x))$],
  )
  content(
    (coef_x + img_size / 2, coef_y - 0.85),
    text(8pt, fill: gray)[per-block compaction (top-left of each tile)],
  )
}))
