#import "@preview/cetz:0.4.2": canvas, draw
#set page(width: auto, height: auto, margin: 10pt)

// 4-qubit parametric QFT circuit in the same tensor-network style as
// Figure 1d (cooley_tukey_to_qft). Schematic illustration of the frozen-
// gate phenomenon observed when load_basis("trained_qft.json") is loaded
// into the circuit: some Hadamard-role gates collapse to Z (no
// superposition), and are highlighted here with a violet border. The
// actual trained basis on DIV2K 256x256 uses m = n = 8 per dimension with
// the same qualitative pattern (4 of 8 Hadamards freeze per dimension).

#let frozen_color = rgb("#7a3e99")

#let ngate(pos, n, name, text: none, width: 1, gap-y: 0.8, padding-y: 0.25,
           box-stroke: 0.7pt + black) = {
  import draw: *
  let height = gap-y * (n - 1) + 2 * padding-y
  group(name: name, {
    rect((rel: (-width/2, -height/2), to: pos),
         (rel: (width/2, height/2), to: pos),
         fill: white, stroke: box-stroke, name: "body")
    if text != none { content("body", text) }
    for i in range(n) {
      let y = height/2 - padding-y - i * gap-y
      anchor("i" + str(i), (rel: (-width/2, y), to: pos))
      anchor("o" + str(i), (rel: (width/2, y), to: pos))
    }
    anchor("b", (rel: (0, -height/2), to: pos))
    anchor("t", (rel: (0, height/2), to: pos))
  })
}

#let cphase(x, y_i, y_j, name) = {
  import draw: *
  draw.on-layer(1, {
    circle((x, y_i), radius: 0.05, fill: black, stroke: none, name: name + "c1")
    circle((x, y_j), radius: 0.05, fill: black, stroke: none, name: name + "c2")
    ngate((x, (y_i + y_j) / 2), 1, name, text: text(7pt)[$M$],
          gap-y: 0.3, width: 0.45, padding-y: 0.25)
    line(name + "c1", name + ".t")
    line(name + "c2", name + ".b")
  })
}

// 4-qubit QFT: H_3 (leftmost), CP(q_2,q_3), H_2, CP(q_1,q_2), CP(q_1,q_3),
//   H_1, CP(q_0,q_1), CP(q_0,q_2), CP(q_0,q_3), H_0 (rightmost).
#let h_positions_4q = (1, 3, 6, 10)       // step indices for H_3, H_2, H_1, H_0
#let cphase_list_4q = (
  (2, 2, 3),
  (4, 1, 2), (5, 1, 3),
  (7, 0, 1), (8, 0, 2), (9, 0, 3),
)

#let draw_qft4(ox, y_top, gap_y, step, h_labels, id_prefix) = {
  import draw: *

  let wire_x0 = ox - 0.25
  let wire_x1 = ox + 11 * step
  for i in range(4) {
    let y = y_top - i * gap_y
    line((wire_x0, y), (wire_x1, y), stroke: 0.5pt)
    content((wire_x0 - 0.35, y), text(7pt)[$q_#i$])
  }

  for (i, step_idx) in h_positions_4q.enumerate() {
    let qi = 3 - i
    let lbl = h_labels.at(qi)
    let is_frozen = lbl != "H"
    let gate_stroke = if is_frozen {
      1.6pt + frozen_color
    } else {
      0.7pt + black
    }
    let gx = ox + step_idx * step
    let gy = y_top - qi * gap_y
    on-layer(1, {
      ngate((gx, gy), 1, id_prefix + "_h" + str(i),
            text: text(9pt)[#lbl],
            gap-y: gap_y, width: 0.55, padding-y: 0.25,
            box-stroke: gate_stroke)
    })
  }

  for (i, cp) in cphase_list_4q.enumerate() {
    let step_idx = cp.at(0)
    let qctrl = cp.at(1)
    let qtgt = cp.at(2)
    let gx = ox + step_idx * step
    let y_ctrl = y_top - qctrl * gap_y
    let y_tgt = y_top - qtgt * gap_y
    cphase(gx, y_ctrl, y_tgt, id_prefix + "_cp" + str(i))
  }
}

#figure(canvas({
  import draw: *

  let gap_y = 0.8
  let step = 0.7
  let y_top = 1.2                           // q_0 at 1.2, q_3 at -1.2
  let panel_span = 11 * step                // wire extent per panel
  let title_y = y_top + 0.55

  let pa_ox = 0.8
  let pb_ox = pa_ox + panel_span + 1.1

  // Panel (a): Before training
  content((pa_ox + panel_span / 2 - 0.1, title_y), anchor: "south",
          text(10pt, weight: "bold")[(a) Before training])
  draw_qft4(pa_ox, y_top, gap_y, step,
            ("H", "H", "H", "H"), "a")

  // Panel (b): After training (q_2 and q_3 frozen to Z, violet border)
  content((pb_ox + panel_span / 2 - 0.1, title_y), anchor: "south",
          text(10pt, weight: "bold")[(b) After training])
  draw_qft4(pb_ox, y_top, gap_y, step,
            ("H", "H", "Z", "Z"), "b")
}))
