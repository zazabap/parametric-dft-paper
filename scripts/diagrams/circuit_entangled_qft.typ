// Entangled QFT circuit at QuickDraw geometry (m = n = 5).
// Standalone source for figures/diagrams/circuit_entangled_qft.pdf.

#set page(width: auto, height: auto, margin: 0.4cm)
#set text(size: 11pt, font: "New Computer Modern")

#import "@preview/quill:0.7.1": *

#align(center)[
  #text(size: 9pt, weight: "bold", fill: rgb("#0a3d8c"))[#raw("entangled_qft")] #h(0.3em)
  #text(size: 8pt, fill: gray)[QFT $+$ 5 $E_k$, 115p]
]
#v(0.3em)

#align(center, quantum-circuit(
  scale: 55%, row-spacing: 0.55em, column-spacing: 0.22em,
  lstick($x_1$), $H$, ctrl(1), ctrl(2), ctrl(3), ctrl(4), 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ctrl(5), 1, 1, 1, 1, [\ ],
  lstick($x_2$), 1,   $M$,     1,       1,       1,       $H$, ctrl(1), ctrl(2), ctrl(3), 1, 1, 1, 1, 1, 1, 1, ctrl(5), 1, 1, 1, [\ ],
  lstick($x_3$), 1,   1,       $M$,     1,       1,       1,   $M$,     1,       1,       $H$, ctrl(1), ctrl(2), 1, 1, 1, 1, 1, ctrl(5), 1, 1, [\ ],
  lstick($x_4$), 1,   1,       1,       $M$,     1,       1,   1,       $M$,     1,       1,   $M$,     1,       $H$, ctrl(1), 1, 1, 1, 1, ctrl(5), 1, [\ ],
  lstick($x_5$), 1,   1,       1,       1,       $M$,     1,   1,       1,       $M$,     1,   1,       $M$,     1,   $M$,     $H$, 1, 1, 1, 1, ctrl(5), [\ ],
  lstick($y_1$), $H$, ctrl(1), ctrl(2), ctrl(3), ctrl(4), 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, $E$, 1, 1, 1, 1, [\ ],
  lstick($y_2$), 1,   $M$,     1,       1,       1,       $H$, ctrl(1), ctrl(2), ctrl(3), 1, 1, 1, 1, 1, 1, 1, $E$, 1, 1, 1, [\ ],
  lstick($y_3$), 1,   1,       $M$,     1,       1,       1,   $M$,     1,       1,       $H$, ctrl(1), ctrl(2), 1, 1, 1, 1, 1, $E$, 1, 1, [\ ],
  lstick($y_4$), 1,   1,       1,       $M$,     1,       1,   1,       $M$,     1,       1,   $M$,     1,       $H$, ctrl(1), 1, 1, 1, 1, $E$, 1, [\ ],
  lstick($y_5$), 1,   1,       1,       1,       $M$,     1,   1,       1,       $M$,     1,   1,       $M$,     1,   $M$,     $H$, 1, 1, 1, 1, $E$,
))
