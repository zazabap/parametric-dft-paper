#import "@preview/cetz:0.4.2": canvas, draw
#set page(width: auto, height: auto, margin: 10pt)

// Qubit coordinate convention: wire for q_j is at y = 1.2 - j * 0.8
// (q_0 = 1.2, q_1 = 0.4, q_2 = -0.4, q_3 = -1.2). Every wire is strictly
// horizontal and every inter-qubit link is strictly vertical.
//
// Z-order: wires are drawn on the default layer and gate boxes are drawn on
// layer 1 (on top), so wires terminate visually at the gate boundaries.

#let ngate(pos, n, name, text: none, width: 1, gap-y: 1, padding-y: 0.25) = {
  import draw: *
  let height = gap-y * (n - 1) + 2 * padding-y
  group(name: name, {
    rect((rel: (-width/2, -height/2), to: pos), (rel: (width/2, height/2), to: pos), fill: white, name: "body")
    if text != none {
      content("body", text)
    }
    for i in range(n) {
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
  // Whole cphase (dots + gate box + internal links) lives on layer 1 so it
  // sits on top of whatever horizontal wires pass through the region.
  draw.on-layer(1, {
    circle((x, i), radius: 0.05, fill: black, stroke: none, name: name + "ctrl1")
    circle((x, j), radius: 0.05, fill: black, stroke: none, name: name + "ctrl2")
    ngate((x, (i + j) / 2), 1, name, text: text(7pt)[$M_(#(k + 1))$], gap-y: 0.8, width: 0.45)
    line(name + "ctrl1", name + ".t")
    line(name + "ctrl2", name + ".b")
  })
}

#let harrow(from_x, to_x) = {
  import draw: *
  line((from_x, 0.0), (to_x, 0.0), mark: (end: "straight"), stroke: (thickness: 0.6pt, paint: gray.darken(20%)))
}

#let panel_title(x, txt) = {
  import draw: *
  content((x, 1.85), anchor: "south", text(9pt, weight: "bold")[#txt])
}

#let label_y = -2.2

#figure(canvas({
  import draw: *

  // ============================================================
  // Panel (a): Re-index  [x: 0 .. 2.2]
  // ============================================================
  let pa = 0.0
  panel_title(pa + 1.0, [(a) Re-index])
  on-layer(1, {
    ngate((pa + 0.4, 0.0), 4, "xa", text: [$bold(x)$], gap-y: 0.8, width: 0.6)
  })
  for i in range(4) {
    line("xa.o" + str(i), (rel: (0.7, 0)))
    content((rel: (0.3, 0)), text(7pt)[$q_#i$])
  }
  content((pa + 1.0, label_y), anchor: "north", text(8pt, style: "italic")[
    $bold(x)$ as rank-$k$ tensor
  ])
  harrow(pa + 2.3, pa + 3.0)

  // ============================================================
  // Panel (b): Recurse  [x: 3.2 .. 9.0]
  // ============================================================
  let pb = 3.2
  panel_title(pb + 2.8, [(b) Recurse])
  on-layer(1, {
    ngate((pb + 0.3, 0.0), 4, "xb", text: [$bold(x)$], gap-y: 0.8, width: 0.6)
    ngate((pb + 1.8, -0.4), 3, "Fhb", text: text(7pt)[$F_(n slash 2)$], gap-y: 0.8, width: 0.8)
    ngate((pb + 3.5, 0.0), 4, "IDb", text: text(6pt)[$mat(I, 0; 0, D_(n slash 2))$], gap-y: 0.8, width: 1.4)
    ngate((pb + 5.2, 1.2), 1, "Hb", text: [$H$], gap-y: 0.8, width: 0.45)
  })
  // Wires at default layer (below gate boxes).
  for i in range(3) {
    line("xb.o" + str(i + 1), "Fhb.i" + str(i))
    line("Fhb.o" + str(i), "IDb.i" + str(i + 1))
  }
  line("xb.o0", "IDb.i0")
  line("IDb.o0", "Hb.i0")
  for i in range(1, 4) {
    line("IDb.o" + str(i), (rel: (0.5, 0)))
  }
  line("Hb.o0", (rel: (0.3, 0)))
  content((pb + 2.8, label_y), anchor: "north", text(8pt, style: "italic")[
    one butterfly layer
  ])
  harrow(pb + 6.0, pb + 6.6)

  // ============================================================
  // Panel (c): Decompose  [x: 9.8 .. 15.6]
  // ============================================================
  let pc = 9.8
  panel_title(pc + 2.8, [(c) Decompose])
  on-layer(1, {
    ngate((pc + 0.3, 0.0), 4, "xc", text: [$bold(x)$], gap-y: 0.8, width: 0.6)
    ngate((pc + 1.8, -0.4), 3, "Fhc", text: text(7pt)[$F_(n slash 2)$], gap-y: 0.8, width: 0.8)
    ngate((pc + 5.1, 1.2), 1, "Hc", text: [$H$], gap-y: 0.8, width: 0.45)
  })
  // Wires at default layer.
  for i in range(3) {
    line("xc.o" + str(i + 1), "Fhc.i" + str(i))
  }
  line("xc.o0", "Hc.i0")
  for i in range(3) {
    line("Fhc.o" + str(i), (rel: (3.1, 0)))
  }
  line("Hc.o0", (rel: (0.3, 0)))
  // Controlled-phase chain coupling q_0 to q_1, q_2, q_3 (each cphase is on layer 1).
  cphase(pc + 4.4, 1.2,  0.4, 1, name: "cpc1")
  cphase(pc + 3.6, 1.2, -0.4, 2, name: "cpc2")
  cphase(pc + 2.8, 1.2, -1.2, 3, name: "cpc3")
  content((pc + 2.8, label_y), anchor: "north", text(8pt, style: "italic")[
    twiddle $arrow$ $M_j$ chain
  ])
  harrow(pc + 5.8, pc + 6.4)

  // ============================================================
  // Panel (d): Relax  [x: 16.0 .. 24.0]
  // ============================================================
  let pd = 16.0
  panel_title(pd + 3.9, [(d) Relax])
  on-layer(1, {
    ngate((pd, 0.0), 4, "xd", text: [$bold(x)$], gap-y: 0.8, width: 0.6)
    ngate((pd + 7.5, 1.2), 1, "H0d", text: [$H$], gap-y: 0.8, width: 0.45)
    ngate((pd + 4.7, 0.4), 1, "H1d", text: [$H$], gap-y: 0.8, width: 0.45)
    ngate((pd + 2.6, -0.4), 1, "H2d", text: [$H$], gap-y: 0.8, width: 0.45)
    ngate((pd + 1.2, -1.2), 1, "H3d", text: [$H$], gap-y: 0.8, width: 0.45)
  })
  // Controlled-phase gates (each internally on layer 1).
  cphase(pd + 6.8, 1.2,  0.4, 1, name: "dA1")
  cphase(pd + 6.1, 1.2, -0.4, 2, name: "dA2")
  cphase(pd + 5.4, 1.2, -1.2, 3, name: "dA3")
  cphase(pd + 4.0, 0.4, -0.4, 1, name: "dB1")
  cphase(pd + 3.3, 0.4, -1.2, 2, name: "dB2")
  cphase(pd + 1.9, -0.4, -1.2, 1, name: "dC1")
  // Wires at default layer.
  line("xd.o0", "H0d.i0")
  line("H0d.o0", (rel: (0.3, 0)))
  line("xd.o1", "H1d.i0")
  line("H1d.o0", "dA1ctrl2")
  line("dA1ctrl2", (pd + 7.9, 0.4))
  line("xd.o2", "H2d.i0")
  line("H2d.o0", "dB1ctrl2")
  line("dB1ctrl2", "dA2ctrl2")
  line("dA2ctrl2", (pd + 7.9, -0.4))
  line("xd.o3", "H3d.i0")
  line("H3d.o0", "dC1ctrl2")
  line("dC1ctrl2", "dB2ctrl2")
  line("dB2ctrl2", "dA3ctrl2")
  line("dA3ctrl2", (pd + 7.9, -1.2))
  content((pd + 3.9, label_y), anchor: "north", text(8pt, style: "italic")[
    $H in U(2), quad M_j in U(1)^4$
  ])
}))
