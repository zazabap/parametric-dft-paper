#import "@preview/cetz:0.4.2": canvas, draw
#set page(width: auto, height: auto, margin: 5pt)

#let ngate(pos, n, name, text: none, width: 1, gap-y: 1, padding-y: 0.25) = {
  import draw: *
  let height = gap-y * (n - 1) + 2 * padding-y

  // Gate rectangles are drawn on layer 1 so they always sit on top of the
  // wires, independent of the order in which gates and wires are issued.
  on-layer(1, {
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
  })
}

#let tebdgate(x, i, j, label, name: "T") = {
  import draw: *
  circle((x, i), radius: 0.05, fill: black, stroke: none, name: name + "c1")
  circle((x, j), radius: 0.05, fill: black, stroke: none, name: name + "c2")
  ngate((x, (i + j) / 2), 1, name, text: text(7pt)[#label], gap-y: 0.6, width: 0.55, padding-y: 0.18)
  line(name + "c1", name + ".t")
  line(name + "c2", name + ".b")
}

#figure(canvas({
  import draw: *
  let dy = 0.6
  let n = 8
  let ysep = (n + 0.5) * dy
  // Single combined input tensor spanning both registers
  let ytop = dy / 2
  let ybot = -ysep - (n - 1) * dy - dy / 2
  let xc = -2.5
  let hw = 0.35
  let xend = 10.5
  rect((xc - hw, ybot), (xc + hw, ytop), fill: white, name: "img")
  content("img", [$bold(x)$])
  // Draw qubit lines and labels
  for i in range(n) {
    line((xc + hw, -i * dy), (xend, -i * dy), stroke: gray)
    content((-3.3, -i * dy), text(8pt)[$x_#(i + 1)$])
    content((xend + 0.45, -i * dy), text(8pt)[$x'_#(i + 1)$])
    line((xc + hw, -ysep - i * dy), (xend, -ysep - i * dy), stroke: gray)
    content((-3.3, -ysep - i * dy), text(8pt)[$y_#(i + 1)$])
    content((xend + 0.45, -ysep - i * dy), text(8pt)[$y'_#(i + 1)$])
  }
  // Hadamard gates for all qubits
  for i in range(n) {
    ngate((-1.0, -i * dy), 1, "Hx" + str(i), text:[$H$], gap-y: dy, width: 0.45, padding-y: 0.18)
    ngate((-1.0, -ysep - i * dy), 1, "Hy" + str(i), text:[$H$], gap-y: dy, width: 0.45, padding-y: 0.18)
  }
  // Row ring: 7 nearest-neighbor staircase gates + 1 wrap-around
  tebdgate(0.5,  0 * dy,  -1 * dy, [$T_(x 1)$], name: "Tx1")
  tebdgate(1.4, -1 * dy,  -2 * dy, [$T_(x 2)$], name: "Tx2")
  tebdgate(2.3, -2 * dy,  -3 * dy, [$T_(x 3)$], name: "Tx3")
  tebdgate(3.2, -3 * dy,  -4 * dy, [$T_(x 4)$], name: "Tx4")
  tebdgate(4.1, -4 * dy,  -5 * dy, [$T_(x 5)$], name: "Tx5")
  tebdgate(5.0, -5 * dy,  -6 * dy, [$T_(x 6)$], name: "Tx6")
  tebdgate(5.9, -6 * dy,  -7 * dy, [$T_(x 7)$], name: "Tx7")
  // Wrap-around gate closing the row ring
  tebdgate(7.8,  0 * dy,  -7 * dy, [$T_(x 8)$], name: "Tx8")
  // Column ring: same structure
  tebdgate(0.5, -ysep - 0 * dy, -ysep - 1 * dy, [$T_(y 1)$], name: "Ty1")
  tebdgate(1.4, -ysep - 1 * dy, -ysep - 2 * dy, [$T_(y 2)$], name: "Ty2")
  tebdgate(2.3, -ysep - 2 * dy, -ysep - 3 * dy, [$T_(y 3)$], name: "Ty3")
  tebdgate(3.2, -ysep - 3 * dy, -ysep - 4 * dy, [$T_(y 4)$], name: "Ty4")
  tebdgate(4.1, -ysep - 4 * dy, -ysep - 5 * dy, [$T_(y 5)$], name: "Ty5")
  tebdgate(5.0, -ysep - 5 * dy, -ysep - 6 * dy, [$T_(y 6)$], name: "Ty6")
  tebdgate(5.9, -ysep - 6 * dy, -ysep - 7 * dy, [$T_(y 7)$], name: "Ty7")
  // Wrap-around gate closing the column ring
  tebdgate(7.8, -ysep - 0 * dy, -ysep - 7 * dy, [$T_(y 8)$], name: "Ty8")
}))
