#import "@preview/cetz:0.4.2": canvas, draw
#set page(width: auto, height: auto, margin: 5pt)

#let ngate(pos, n, name, text: none, width: 1, gap-y: 1, padding-y: 0.25) = {
  import draw: *
  let height = gap-y * (n - 1) + 2 * padding-y

  group(name: name, {
    rect((rel: (- width/2, -height/2), to: pos), (rel: (width/2, height/2), to: pos), fill: white, name: "body")
    if text != none{
      content("body", text)
    }

    // Define custom anchors
    for i in range(n){
      let y = height/2 - padding-y - i * gap-y
      anchor("i" + str(i), (rel: (-width/2, y), to: pos))
      anchor("o" + str(i), (rel: (width/2, y), to: pos))
    }
    anchor("b", (rel: (0, -height/2), to: pos))
    anchor("t", (rel: (0, height/2), to: pos))
  })
}

#let meragate(x, i, j, label, name: "M", gwidth: 0.6) = {
  import draw: *
  circle((x, i), radius: 0.05, fill: black, stroke: none, name: name + "c1")
  circle((x, j), radius: 0.05, fill: black, stroke: none, name: name + "c2")
  ngate((x, (i + j) / 2), 1, name, text: text(8pt)[#label], gap-y: 0.8, width: gwidth)
  line(name + "c1", name + ".t")
  line(name + "c2", name + ".b")
}

#figure(canvas({
  import draw: *
  let n = 8
  let dy = 0.6
  let ysep = (n + 0.5) * dy
  let xend = 12.5
  let gw = 0.6  // gate width (same for D and W)
  // Single combined input tensor
  let ytop = dy / 2
  let ybot = -ysep - (n - 1) * dy - dy / 2
  let xc = -2.5
  let hw = 0.35
  rect((xc - hw, ybot), (xc + hw, ytop), fill: white, name: "img")
  content("img", [$bold(x)$])
  line((xc - hw, -(n - 0.25) * dy), (xc + hw, -(n - 0.25) * dy), stroke: (dash: "dashed", paint: gray))
  // Draw qubit lines and labels
  for i in range(n) {
    line((xc + hw, -i * dy), (xend, -i * dy), stroke: gray)
    content((-3.3, -i * dy), [$x_#(i + 1)$])
    content((xend + 0.5, -i * dy), [$x'_#(i + 1)$])
    line((xc + hw, -ysep - i * dy), (xend, -ysep - i * dy), stroke: gray)
    content((-3.3, -ysep - i * dy), [$y_#(i + 1)$])
    content((xend + 0.5, -ysep - i * dy), [$y'_#(i + 1)$])
  }
  // Dashed separator on the circuit
  line((-3.5, -(n - 0.25) * dy), (xend, -(n - 0.25) * dy), stroke: (dash: "dashed", paint: gray))
  // Hadamard gates for all qubits
  for i in range(n) {
    ngate((-1.2, -i * dy), 1, "Hx" + str(i), text:[$H$], gap-y: dy, width: 0.45)
    ngate((-1.2, -ysep - i * dy), 1, "Hy" + str(i), text:[$H$], gap-y: dy, width: 0.45)
  }
  // === Row MERA (8 qubits, 3 layers) ===
  // Layer 1 (s=1, 4 pairs)
  //   Disentanglers: (2,3), (4,5), (6,7) at x1d; wrap-around (8,1) at x1d2
  let x1d = 1.0
  meragate(x1d, -1 * dy, -2 * dy, [$D$], name: "xD1", gwidth: gw)
  meragate(x1d, -3 * dy, -4 * dy, [$D$], name: "xD2", gwidth: gw)
  meragate(x1d, -5 * dy, -6 * dy, [$D$], name: "xD3", gwidth: gw)
  // Wrap-around D gate (8,1) — placed at its own x to avoid overlap
  let x1d2 = 2.2
  meragate(x1d2, -7 * dy, 0, [$D$], name: "xD4", gwidth: gw)
  //   Isometries: (1,2), (3,4), (5,6), (7,8)
  let x1w = 3.4
  meragate(x1w, 0, -1 * dy, [$W$], name: "xW1", gwidth: gw)
  meragate(x1w, -2 * dy, -3 * dy, [$W$], name: "xW2", gwidth: gw)
  meragate(x1w, -4 * dy, -5 * dy, [$W$], name: "xW3", gwidth: gw)
  meragate(x1w, -6 * dy, -7 * dy, [$W$], name: "xW4", gwidth: gw)
  // Layer 2 (s=2, 2 pairs)
  //   Disentanglers: (2,4), (6,8)
  let x2d = 5.5
  meragate(x2d, -1 * dy, -3 * dy, [$D$], name: "xD5", gwidth: gw)
  meragate(x2d, -5 * dy, -7 * dy, [$D$], name: "xD6", gwidth: gw)
  //   Isometries: (1,3), (5,7)
  let x2w = 7.2
  meragate(x2w, 0, -2 * dy, [$W$], name: "xW5", gwidth: gw)
  meragate(x2w, -4 * dy, -6 * dy, [$W$], name: "xW6", gwidth: gw)
  // Layer 3 (s=4, 1 pair) — compressed
  //   Disentangler: (2,6)
  let x3d = 9.0
  meragate(x3d, -1 * dy, -5 * dy, [$D$], name: "xD7", gwidth: gw)
  //   Isometry: (1,5)
  let x3w = 10.5
  meragate(x3w, 0, -4 * dy, [$W$], name: "xW7", gwidth: gw)
  // === Column MERA (8 qubits, 3 layers) ===
  // Layer 1
  meragate(x1d, -ysep - 1 * dy, -ysep - 2 * dy, [$D$], name: "yD1", gwidth: gw)
  meragate(x1d, -ysep - 3 * dy, -ysep - 4 * dy, [$D$], name: "yD2", gwidth: gw)
  meragate(x1d, -ysep - 5 * dy, -ysep - 6 * dy, [$D$], name: "yD3", gwidth: gw)
  meragate(x1d2, -ysep - 7 * dy, -ysep, [$D$], name: "yD4", gwidth: gw)
  meragate(x1w, -ysep, -ysep - 1 * dy, [$W$], name: "yW1", gwidth: gw)
  meragate(x1w, -ysep - 2 * dy, -ysep - 3 * dy, [$W$], name: "yW2", gwidth: gw)
  meragate(x1w, -ysep - 4 * dy, -ysep - 5 * dy, [$W$], name: "yW3", gwidth: gw)
  meragate(x1w, -ysep - 6 * dy, -ysep - 7 * dy, [$W$], name: "yW4", gwidth: gw)
  // Layer 2
  meragate(x2d, -ysep - 1 * dy, -ysep - 3 * dy, [$D$], name: "yD5", gwidth: gw)
  meragate(x2d, -ysep - 5 * dy, -ysep - 7 * dy, [$D$], name: "yD6", gwidth: gw)
  meragate(x2w, -ysep, -ysep - 2 * dy, [$W$], name: "yW5", gwidth: gw)
  meragate(x2w, -ysep - 4 * dy, -ysep - 6 * dy, [$W$], name: "yW6", gwidth: gw)
  // Layer 3
  meragate(x3d, -ysep - 1 * dy, -ysep - 5 * dy, [$D$], name: "yD7", gwidth: gw)
  meragate(x3w, -ysep, -ysep - 4 * dy, [$W$], name: "yW7", gwidth: gw)
  // Layer labels
  content((2.2, 1.2), text(8pt)[Layer 1])
  content((6.3, 1.2), text(8pt)[Layer 2])
  content((9.7, 1.2), text(8pt)[Layer 3])
  line((0.2, 0.9), (4.2, 0.9), stroke: gray)
  line((4.8, 0.9), (7.8, 0.9), stroke: gray)
  line((8.3, 0.9), (11.2, 0.9), stroke: gray)
}))
