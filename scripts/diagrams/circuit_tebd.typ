// TEBD-style ring circuit at QuickDraw geometry (m = n = 5).
// Standalone source for figures/diagrams/circuit_tebd.pdf.

#set page(width: auto, height: auto, margin: 0.4cm)
#set text(size: 11pt, font: "New Computer Modern")

#import "@preview/quill:0.7.1": *

#align(center)[
  #text(size: 9pt, weight: "bold", fill: rgb("#0a3d8c"))[#raw("tebd")] #h(0.3em)
  #text(size: 8pt, fill: gray)[NN ring $+$ wrap, 50p]
]
#v(0.3em)

#align(center, quantum-circuit(
  scale: 55%, row-spacing: 0.55em, column-spacing: 0.45em,
  lstick($x_1$), $H$, ctrl(1), 1, 1, 1, $T$, [\ ],
  lstick($x_2$), $H$, $T$,    ctrl(1), 1, 1, 1, [\ ],
  lstick($x_3$), $H$, 1,      $T$,    ctrl(1), 1, 1, [\ ],
  lstick($x_4$), $H$, 1,      1,      $T$,    ctrl(1), 1, [\ ],
  lstick($x_5$), $H$, 1,      1,      1,      $T$, ctrl(-4), [\ ],
  lstick($y_1$), $H$, ctrl(1), 1, 1, 1, $T$, [\ ],
  lstick($y_2$), $H$, $T$,    ctrl(1), 1, 1, 1, [\ ],
  lstick($y_3$), $H$, 1,      $T$,    ctrl(1), 1, 1, [\ ],
  lstick($y_4$), $H$, 1,      1,      $T$,    ctrl(1), 1, [\ ],
  lstick($y_5$), $H$, 1,      1,      1,      $T$, ctrl(-4),
))
