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

#let tebdgate(x, i, j, label, name: "T") = {
  import draw: *
  circle((x, i), radius: 0.05, fill: black, stroke: none, name: name + "c1")
  circle((x, j), radius: 0.05, fill: black, stroke: none, name: name + "c2")
  ngate((x, (i + j) / 2), 1, name, text: text(8pt)[#label], gap-y: 0.8, width: 0.6)
  line(name + "c1", name + ".t")
  line(name + "c2", name + ".b")
}

#figure(canvas({
  import draw: *
  let dy = 0.8
  let n = 4
  let ysep = (n + 0.5) * dy
  // Single combined input tensor for all qubits
  // Use a manually drawn rect to span all qubit lines with a gap
  let ytop = dy / 2
  let ybot = -ysep - (n - 1) * dy - dy / 2
  let xc = -2.5
  let hw = 0.35
  rect((xc - hw, ybot), (xc + hw, ytop), fill: white, name: "img")
  content("img", [$bold(x)$])
  // Dashed separator inside the input block between row and column qubits
  line((xc - hw, -(n - 0.25) * dy), (xc + hw, -(n - 0.25) * dy), stroke: (dash: "dashed", paint: gray))
  // Draw qubit lines and labels
  for i in range(n) {
    line((xc + hw, -i * dy), (9.5, -i * dy), stroke: gray)
    content((-3.3, -i * dy), [$|x_#(i + 1) angle.r$])
    content((9.9, -i * dy), [$x'_#(i + 1)$])
    line((xc + hw, -ysep - i * dy), (9.5, -ysep - i * dy), stroke: gray)
    content((-3.3, -ysep - i * dy), [$|y_#(i + 1) angle.r$])
    content((9.9, -ysep - i * dy), [$y'_#(i + 1)$])
  }
  // Dashed separator between row and column qubits on the circuit
  line((-3.5, -(n - 0.25) * dy), (9.5, -(n - 0.25) * dy), stroke: (dash: "dashed", paint: gray))
  // Hadamard gates for all qubits
  for i in range(n) {
    ngate((-1.0, -i * dy), 1, "Hx" + str(i), text:[$H$], gap-y: dy, width: 0.5)
    ngate((-1.0, -ysep - i * dy), 1, "Hy" + str(i), text:[$H$], gap-y: dy, width: 0.5)
  }
  // Row ring: nearest-neighbor controlled-phase gates (staircase pattern)
  tebdgate(0.8, 0, -dy, [$T_(x 1)$], name: "Tx1")
  tebdgate(2.2, -dy, -2 * dy, [$T_(x 2)$], name: "Tx2")
  tebdgate(3.6, -2 * dy, -3 * dy, [$T_(x 3)$], name: "Tx3")
  // Wrap-around gate closing the row ring
  tebdgate(5.5, 0, -3 * dy, [$T_(x 4)$], name: "Tx4")
  // Column ring: nearest-neighbor controlled-phase gates
  tebdgate(0.8, -ysep, -ysep - dy, [$T_(y 1)$], name: "Ty1")
  tebdgate(2.2, -ysep - dy, -ysep - 2 * dy, [$T_(y 2)$], name: "Ty2")
  tebdgate(3.6, -ysep - 2 * dy, -ysep - 3 * dy, [$T_(y 3)$], name: "Ty3")
  // Wrap-around gate closing the column ring
  tebdgate(5.5, -ysep, -ysep - 3 * dy, [$T_(y 4)$], name: "Ty4")
}))
