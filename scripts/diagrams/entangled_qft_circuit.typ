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

#let cphase(x, i, j, k, name: "CP") = {
  import draw: *
  circle((x, i), radius: 0.05, fill: black, stroke: none, name: name + "ctrl1")
  circle((x, j), radius: 0.05, fill: black, stroke: none, name: name + "ctrl2")
  ngate((x, (i+j)/2), 1, name, text:text(8pt)[$M_(#(k+1))$], gap-y: 0.8, width: 0.5)
  line(name + "ctrl1", name+".t")
  line(name + "ctrl2", name+".b")
}

#let egate(x, i, j, k, name: "E") = {
  import draw: *
  circle((x, i), radius: 0.05, fill: black, stroke: none, name: name + "ctrl1")
  circle((x, j), radius: 0.05, fill: black, stroke: none, name: name + "ctrl2")
  ngate((x, (i+j)/2), 1, name, text:text(8pt)[$E_(#k)$], gap-y: 0.8, width: 0.5)
  line(name + "ctrl1", name+".t")
  line(name + "ctrl2", name+".b")
}

#figure(canvas({
  import draw: *
  let n = 4
  let dy = 0.8
  let ysep = (n + 0.5) * dy
  // Single combined input tensor
  let ytop = dy / 2
  let ybot = -ysep - (n - 1) * dy - dy / 2
  let xc = -3
  let hw = 0.35
  rect((xc - hw, ybot), (xc + hw, ytop), fill: white, name: "img")
  content("img", [$bold(x)$])
  // Dashed separator inside the input block
  line((xc - hw, -(n - 0.25) * dy), (xc + hw, -(n - 0.25) * dy), stroke: (dash: "dashed", paint: gray))

  // Row qubit x_0 (topmost, y=0)
  ngate((7.0, 0), 1, "Hx0", text:[$H$], gap-y: dy, width: 0.5)
  line((xc + hw, 0), "Hx0.i0")
  line("Hx0.o0", (9.4, 0))
  cphase(6.2, 0, -dy, 1, name: "Mx01")
  cphase(5.4, 0, -2 * dy, 2, name: "Mx02")
  cphase(4.6, 0, -3 * dy, 3, name: "Mx03")

  // Row qubit x_1 (y=-dy)
  ngate((3.2, -dy), 1, "Hx1", text:[$H$], gap-y: dy, width: 0.5)
  line("Hx1.o0", "Mx01ctrl2")
  line("Mx01ctrl2", (9.4, -dy))
  line((xc + hw, -dy), "Hx1.i0")
  cphase(2.4, -dy, -2 * dy, 1, name: "Mx11")
  cphase(1.6, -dy, -3 * dy, 2, name: "Mx12")

  // Row qubit x_2 (y=-2dy)
  ngate((0.2, -2 * dy), 1, "Hx2", text:[$H$], gap-y: dy, width: 0.5)
  line("Hx2.o0", "Mx11ctrl2")
  line("Mx11ctrl2", "Mx02ctrl2")
  line("Mx02ctrl2", (9.4, -2 * dy))
  line((xc + hw, -2 * dy), "Hx2.i0")
  cphase(-0.6, -2 * dy, -3 * dy, 1, name: "Mx21")

  // Row qubit x_3 (bottommost row qubit, y=-3dy)
  ngate((-2.0, -3 * dy), 1, "Hx3", text:[$H$], gap-y: dy, width: 0.5)
  line("Hx3.o0", "Mx21ctrl2")
  line("Mx21ctrl2", "Mx12ctrl2")
  line("Mx12ctrl2", "Mx03ctrl2")
  line("Mx03ctrl2", (9.4, -3 * dy))
  line((xc + hw, -3 * dy), "Hx3.i0")

  // Column qubit y_0 (y=-ysep)
  ngate((7.0, -ysep), 1, "Hy0", text:[$H$], gap-y: dy, width: 0.5)
  line((xc + hw, -ysep), "Hy0.i0")
  line("Hy0.o0", (9.4, -ysep))
  cphase(6.2, -ysep, -ysep - dy, 1, name: "My01")
  cphase(5.4, -ysep, -ysep - 2 * dy, 2, name: "My02")
  cphase(4.6, -ysep, -ysep - 3 * dy, 3, name: "My03")

  // Column qubit y_1 (y=-ysep-dy)
  ngate((3.2, -ysep - dy), 1, "Hy1", text:[$H$], gap-y: dy, width: 0.5)
  line("Hy1.o0", "My01ctrl2")
  line("My01ctrl2", (9.4, -ysep - dy))
  line((xc + hw, -ysep - dy), "Hy1.i0")
  cphase(2.4, -ysep - dy, -ysep - 2 * dy, 1, name: "My11")
  cphase(1.6, -ysep - dy, -ysep - 3 * dy, 2, name: "My12")

  // Column qubit y_2 (y=-ysep-2dy)
  ngate((0.2, -ysep - 2 * dy), 1, "Hy2", text:[$H$], gap-y: dy, width: 0.5)
  line("Hy2.o0", "My11ctrl2")
  line("My11ctrl2", "My02ctrl2")
  line("My02ctrl2", (9.4, -ysep - 2 * dy))
  line((xc + hw, -ysep - 2 * dy), "Hy2.i0")
  cphase(-0.6, -ysep - 2 * dy, -ysep - 3 * dy, 1, name: "My21")

  // Column qubit y_3 (y=-ysep-3dy)
  ngate((-2.0, -ysep - 3 * dy), 1, "Hy3", text:[$H$], gap-y: dy, width: 0.5)
  line("Hy3.o0", "My21ctrl2")
  line("My21ctrl2", "My12ctrl2")
  line("My12ctrl2", "My03ctrl2")
  line("My03ctrl2", (9.4, -ysep - 3 * dy))
  line((xc + hw, -ysep - 3 * dy), "Hy3.i0")

  // Qubit labels
  for i in range(n) {
    content((-3.8, -i * dy), [$x_#i$])
    content((9.8, -i * dy), [$x'_#i$])
    content((-3.8, -ysep - i * dy), [$y_#i$])
    content((9.8, -ysep - i * dy), [$y'_#i$])
  }
  // Dashed separator on the circuit
  line((-4.0, -(n - 0.25) * dy), (9.4, -(n - 0.25) * dy), stroke: (dash: "dashed", paint: gray))

  // Entanglement gates E_k connecting x_{n-k} with y_{n-k}
  egate(-1.4, -3 * dy, -ysep - 3 * dy, 4, name: "E4")
  egate(0.8, -2 * dy, -ysep - 2 * dy, 3, name: "E3")
  egate(3.8, -dy, -ysep - dy, 2, name: "E2")
  egate(8.2, 0, -ysep, 1, name: "E1")
}))
