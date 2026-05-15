// RichBasis circuit at QuickDraw geometry (m = n = 5, 8×8 inner U(4) gates).
// Standalone source for figures/diagrams/circuit_rich.pdf.

#set page(width: auto, height: auto, margin: 0.4cm)
#set text(size: 11pt, font: "New Computer Modern")

#import "@preview/quill:0.7.1": *

#align(center, quantum-circuit(
  scale: 80%, row-spacing: 0.55em, column-spacing: 0.45em,
  lstick($x_1$), gate($I$), 1, 1, 1, 1, 1, 1, [\ ],
  lstick($x_2$), gate($I$), 1, 1, 1, 1, 1, 1, [\ ],
  lstick($x_3$), 1, $H$, mqgate($U^((4))$, n: 2), 1, mqgate($U^((4))$, n: 3), 1, 1, [\ ],
  lstick($x_4$), 1, 1, 1, 1, 1, $H$, mqgate($U^((4))$, n: 2), [\ ],
  lstick($x_5$), 1, 1, 1, 1, 1, 1, 1, 1, [\ ],
  lstick($y_1$), gate($I$), 1, 1, 1, 1, 1, 1, [\ ],
  lstick($y_2$), gate($I$), 1, 1, 1, 1, 1, 1, [\ ],
  lstick($y_3$), 1, $H$, mqgate($U^((4))$, n: 2), 1, mqgate($U^((4))$, n: 3), 1, 1, [\ ],
  lstick($y_4$), 1, 1, 1, 1, 1, $H$, mqgate($U^((4))$, n: 2), [\ ],
  lstick($y_5$), 1, 1, 1, 1, 1, 1, 1, 1,
))
