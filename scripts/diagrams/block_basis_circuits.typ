// Inner-circuit variants for the 8x8 within-block transform, organized as a
// hierarchy: RealRichBasis (headline) at the top, with the other variants
// recovered by extending or collapsing its two-qubit gates. Compact layout
// that fits within a single column.
// Adapted from pdft-benchmarks/diagrams/circuits.typ.

#import "@preview/quill:0.6.0": *

#set page(width: auto, height: auto, margin: 4pt)
#set text(font: "New Computer Modern", size: 9pt)

#stack(
  spacing: 0.35em,

  // ----- RealRichBasis (headline) -----
  align(center)[#text(weight: "bold", size: 9pt)[
    RealRichBasis (headline): $H + O^((4))$, 21 real params/dim
  ]],
  align(center)[
    #quantum-circuit(
      scale: 100%,
      row-spacing: 0.55em,
      column-spacing: 0.45em,
      lstick($q_1$), gate($H$), mqgate($O^((4))$, n: 2), 1, mqgate($O^((4))$, n: 3), 1, 1, 1, [\ ],
      lstick($q_2$), 1, 1, 1, 1, gate($H$), mqgate($O^((4))$, n: 2), 1, [\ ],
      lstick($q_3$), 1, 1, 1, 1, 1, 1, gate($H$),
    )
  ],

  // ----- RichBasis -----
  align(center)[#text(weight: "bold", size: 9pt)[
    RichBasis: $H + U^((4))$, 57 params/dim \u{2003}#text(style: "italic", weight: "regular", size: 8pt)[(extend $O^((4)) \u{2192} U^((4))$)]
  ]],
  align(center)[
    #quantum-circuit(
      scale: 100%,
      row-spacing: 0.55em,
      column-spacing: 0.45em,
      lstick($q_1$), gate($H$), mqgate($U^((4))$, n: 2), 1, mqgate($U^((4))$, n: 3), 1, 1, 1, [\ ],
      lstick($q_2$), 1, 1, 1, 1, gate($H$), mqgate($U^((4))$, n: 2), 1, [\ ],
      lstick($q_3$), 1, 1, 1, 1, 1, 1, gate($H$),
    )
  ],

  // ----- Blocked QFT -----
  align(center)[#text(weight: "bold", size: 9pt)[
    Blocked QFT: $H + $ diag $M$, 15 params/dim \u{2003}#text(style: "italic", weight: "regular", size: 8pt)[(collapse $U^((4)) \u{2192} $ diag $M$)]
  ]],
  align(center)[
    #quantum-circuit(
      scale: 100%,
      row-spacing: 0.55em,
      column-spacing: 0.45em,
      lstick($q_1$), gate($H$), ctrl(1), 1, ctrl(2), 1, 1, 1, [\ ],
      lstick($q_2$), 1, gate($M_1$), 1, 1, gate($H$), ctrl(1), 1, [\ ],
      lstick($q_3$), 1, 1, 1, gate($M_2$), 1, gate($M_1$), gate($H$),
    )
  ],
)
