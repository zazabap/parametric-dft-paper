#import "@preview/cetz:0.4.2": canvas, draw
#set page(width: auto, height: auto, margin: 8pt)

// Before/after of the 8 Hadamard-role gates on one dimension of the QFT circuit
// at init vs after training on DIV2K 256x256. Mapping from the per-qubit
// classification (row dim / generalized run): q0..q3 stay H, q4..q7 freeze to
// Z-like (with a single X-like in the column dim — shown as a side-note).

#let gate_box(pos, label, fill_color, stroke_color) = {
  import draw: *
  rect((rel: (-0.35, -0.35), to: pos), (rel: (0.35, 0.35), to: pos),
       fill: fill_color, stroke: (paint: stroke_color, thickness: 1pt), radius: 0.06)
  content(pos, text(10pt, weight: "bold", fill: stroke_color)[#label])
}

#canvas({
  import draw: *

  // --------- Panel A: Before training (initialization = all H) ---------
  let panel_a_x = 0.0
  let panel_a_y = 0.0

  content((panel_a_x + 3.5, panel_a_y + 2.3),
          text(10pt, weight: "bold")[Before training: 8 Hadamards (QFT init)])

  // Draw 8 qubit wires horizontally, one H gate per wire.
  let wire_x0 = panel_a_x + 0.6
  let wire_x1 = panel_a_x + 6.4
  for i in range(8) {
    let y = panel_a_y + 1.6 - i * 0.4
    line((wire_x0, y), (wire_x1, y), stroke: 0.6pt)
    content((wire_x0 - 0.35, y), text(8pt)[$q_#i$])
    gate_box((panel_a_x + 3.5, y), [H], rgb("#e6f0ff"), rgb("#2a4b7a"))
  }

  // --------- Arrow: training ---------
  let arrow_y = panel_a_y - 1.0
  line((panel_a_x + 3.5, panel_a_y - 1.8), (panel_a_x + 3.5, panel_a_y - 2.8),
       mark: (end: "straight"), stroke: (thickness: 1.2pt, paint: rgb("#c85")))
  content((panel_a_x + 3.5, panel_a_y - 2.3), padding: 0.2, anchor: "west",
          text(9.5pt, weight: "bold", fill: rgb("#a63"))[end-to-end training])

  // --------- Panel B: After training ---------
  let panel_b_y = panel_a_y - 5.4

  content((panel_a_x + 3.5, panel_b_y + 2.3),
          text(10pt, weight: "bold")[After training: 4 H + 4 frozen gates])

  // Gate classifications (row dim, generalized run):
  // q0, q1, q2, q3 -> H; q4, q5, q6, q7 -> Z-like (frozen)
  let classifications = ("H", "H", "H", "H", "Z", "Z", "Z", "Z")
  for (i, cls) in classifications.enumerate() {
    let y = panel_b_y + 1.6 - i * 0.4
    line((wire_x0, y), (wire_x1, y), stroke: 0.6pt)
    content((wire_x0 - 0.35, y), text(8pt)[$q_#i$])
    let fill_c = if cls == "H" { rgb("#e6f0ff") } else { rgb("#ffd9d9") }
    let stroke_c = if cls == "H" { rgb("#2a4b7a") } else { rgb("#8a1f1f") }
    gate_box((panel_a_x + 3.5, y), [#cls], fill_c, stroke_c)
  }

  // --------- Right-side annotations ---------
  // Bracket around q0..q3 (mixing)
  let br_x = wire_x1 + 0.35
  let br_top_h = panel_b_y + 1.6 + 0.18
  let br_bot_h = panel_b_y + 1.6 - 3 * 0.4 - 0.18
  line((br_x, br_top_h), (br_x + 0.15, br_top_h), stroke: 0.7pt)
  line((br_x + 0.15, br_top_h), (br_x + 0.15, br_bot_h), stroke: 0.7pt)
  line((br_x + 0.15, br_bot_h), (br_x, br_bot_h), stroke: 0.7pt)
  content((br_x + 0.4, (br_top_h + br_bot_h) / 2), anchor: "west",
          text(8.5pt)[mixing qubits (superposition, intra-block FFT)])

  // Bracket around q4..q7 (frozen)
  let br_top_f = panel_b_y + 1.6 - 4 * 0.4 + 0.18
  let br_bot_f = panel_b_y + 1.6 - 7 * 0.4 - 0.18
  line((br_x, br_top_f), (br_x + 0.15, br_top_f), stroke: 0.7pt)
  line((br_x + 0.15, br_top_f), (br_x + 0.15, br_bot_f), stroke: 0.7pt)
  line((br_x + 0.15, br_bot_f), (br_x, br_bot_f), stroke: 0.7pt)
  content((br_x + 0.4, (br_top_f + br_bot_f) / 2), anchor: "west",
          text(8.5pt, fill: rgb("#8a1f1f"), weight: "bold")[4 frozen qubits = 2⁴ block indices])

  // Effective-block readout
  content((panel_a_x + 3.5, panel_b_y - 2.0),
          text(10pt, weight: "bold")[Effective block side: 2⁴ = 16 pixels])

  // Legend under the after-panel
  let legend_y = panel_b_y - 2.7
  gate_box((panel_a_x + 1.0, legend_y), [H], rgb("#e6f0ff"), rgb("#2a4b7a"))
  content((panel_a_x + 1.45, legend_y), padding: 0.05, anchor: "west",
          text(8pt)[Hadamard (mixing)])
  gate_box((panel_a_x + 4.2, legend_y), [Z], rgb("#ffd9d9"), rgb("#8a1f1f"))
  content((panel_a_x + 4.65, legend_y), padding: 0.05, anchor: "west",
          text(8pt)[$approx "diag"(+1, -1)$ (frozen)])
})
