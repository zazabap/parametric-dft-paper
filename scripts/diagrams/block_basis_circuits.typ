// Inner-circuit variants for the 8x8 within-block transform.
// Adapted from pdft-benchmarks/diagrams/circuits.typ (the source of truth);
// trimmed to just the three circuit pictures so the figure fits one column.

#import "@preview/quill:0.6.0": *

#set page(width: auto, height: auto, margin: 6pt)
#set text(font: "New Computer Modern", size: 9pt)

#stack(
  spacing: 0.6em,

  // ----- RichBasis -----
  align(center)[#text(weight: "bold")[RichBasis: $H + U^((4))$ \u{2014} 57 real params/dim]],
  align(center)[
    #quantum-circuit(
      scale: 110%,
      row-spacing: 0.85em,
      column-spacing: 0.55em,
      lstick($q_1$), gate($H$), mqgate($U^((4))$, n: 2), 1, mqgate($U^((4))$, n: 3), 1, 1, 1, [\ ],
      lstick($q_2$), 1, 1, 1, 1, gate($H$), mqgate($U^((4))$, n: 2), 1, [\ ],
      lstick($q_3$), 1, 1, 1, 1, 1, 1, gate($H$),
    )
  ],

  // ----- RealRichBasis -----
  align(center)[#text(weight: "bold")[RealRichBasis: $H + O^((4))$ \u{2014} 21 real params/dim]],
  align(center)[
    #quantum-circuit(
      scale: 110%,
      row-spacing: 0.85em,
      column-spacing: 0.55em,
      lstick($q_1$), gate($H$), mqgate($O^((4))$, n: 2), 1, mqgate($O^((4))$, n: 3), 1, 1, 1, [\ ],
      lstick($q_2$), 1, 1, 1, 1, gate($H$), mqgate($O^((4))$, n: 2), 1, [\ ],
      lstick($q_3$), 1, 1, 1, 1, 1, 1, gate($H$),
    )
  ],

  // ----- Blocked QFT (H + diagonal CP) -----
  align(center)[#text(weight: "bold")[Blocked QFT: $H + $ diag $M$ \u{2014} 15 real params/dim (3 H + 3 phases)]],
  align(center)[
    #quantum-circuit(
      scale: 110%,
      row-spacing: 0.85em,
      column-spacing: 0.55em,
      lstick($q_1$), gate($H$), ctrl(1), 1, ctrl(2), 1, 1, 1, [\ ],
      lstick($q_2$), 1, gate($M_1$), 1, 1, gate($H$), ctrl(1), 1, [\ ],
      lstick($q_3$), 1, 1, 1, gate($M_2$), 1, gate($M_1$), gate($H$),
    )
  ],
)
