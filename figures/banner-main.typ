#import "@preview/cetz:0.4.2": canvas, draw
#import "@preview/quill:0.7.1": *

#set page(width: 2172pt, height: 1650pt, margin: 44pt)
#set text(font: "TeX Gyre Bonum", size: 30pt, fill: rgb("#1f2937"))
#show math.equation: set text(font: "TeX Gyre DejaVu Math")

#let ink = rgb("#1f2937")
#let muted = rgb("#64748b")
#let border = rgb("#cbd5e1")
#let panel-bg = rgb("#ffffff")
#let soft-bg = white
#let purple = rgb("#7f00ff")
#let circuit-stroke = (paint: black, thickness: 1.25pt)
#let circuit-stroke-purple = (paint: purple, thickness: 1.25pt)
#let circuit-dash = (paint: gray, thickness: 0.9pt, dash: "dashed")
#let circuit-overlap-dash = (paint: black, thickness: 1.25pt, dash: "dashed")
#let circuit-gate-stroke = (paint: black, thickness: 1.15pt)
#let gate-font = "DejaVu Sans"
#let h-label = [H]
#let m-label(n) = [M#sub[#n]]
#let t-label(n) = [T#sub[#n]]
#let e-label(n) = [E#sub[#n]]
#let u4-label = [U#super[(4)]]

#let panel(title, subtitle: none, body) = block(
  width: 100%,
  fill: panel-bg,
  stroke: 2pt + border,
  radius: 10pt,
  inset: (x: 22pt, y: 18pt),
)[
  #text(size: 34pt, weight: "bold", fill: ink)[#title]
  #if subtitle != none [
    #v(4pt)
    #text(size: 22pt, fill: muted)[#subtitle]
  ]
  #v(14pt)
  #body
]

#let gate-box(pos, label, name, width: 0.46, height: 0.46, color: ink, label-dy: 0, label-size: 15pt) = {
  import draw: *
  rect((pos.at(0) - width / 2, pos.at(1) - height / 2), (pos.at(0) + width / 2, pos.at(1) + height / 2), fill: white, stroke: (paint: color, thickness: 1.15pt), name: name)
  content((pos.at(0), pos.at(1) + label-dy), text(font: gate-font, size: label-size, weight: "bold", fill: color)[#label])
}

#let multi-gate(x, y1, y2, label, name, width: 0.54, label-dy: 0, label-size: 13pt) = {
  import draw: *
  rect((x - width / 2, y2 - 0.4), (x + width / 2, y1 + 0.4), fill: white, stroke: circuit-gate-stroke, name: name)
  content((x, (y1 + y2) / 2 + label-dy), text(font: gate-font, size: label-size, weight: "bold")[#label])
}

#let cphase(x, y1, y2, label, name) = {
  import draw: *
  circle((x, y1), radius: 0.055, fill: black, stroke: none, name: name + "a")
  circle((x, y2), radius: 0.055, fill: black, stroke: none, name: name + "b")
  line((x, y1), (x, y2), stroke: circuit-stroke)
  gate-box((x, (y1 + y2) / 2), label, name + "m", width: 0.54, height: 0.54, label-size: 15pt)
}

#let egate(x, y1, y2, label, name) = {
  import draw: *
  circle((x, y1), radius: 0.055, fill: purple, stroke: none)
  circle((x, y2), radius: 0.055, fill: purple, stroke: none)
  line((x, y1), (x, y2), stroke: circuit-stroke-purple)
  gate-box((x, (y1 + y2) / 2), label, name, width: 0.54, height: 0.54, color: purple, label-size: 15pt)
}

#let blank-box(height, stroke: border, inset: 0pt) = block(
  width: 100%,
  height: height,
  fill: white,
  stroke: 1.5pt + stroke,
  radius: 6pt,
  inset: inset,
)[]

#let stage-shell(body) = block(
  width: 100%,
  height: 100%,
  fill: white,
  stroke: 1.5pt + border,
  radius: 8pt,
  inset: 18pt,
)[#body]

#let stage-heading(title, subtitle) = block(width: 100%)[
  #text(size: 34pt, weight: "bold", fill: ink)[#title]
  #v(5pt)
  #text(size: 21pt, fill: rgb("#0f766e"))[#subtitle]
]

#let relaxation-card(accent, equation, line-a, line-b) = block(
  width: 100%,
  height: 100%,
  fill: white,
  stroke: (paint: accent, thickness: 1.6pt, dash: "dashed"),
  radius: 8pt,
  inset: (x: 14pt, y: 8pt),
)[
  #align(center + horizon)[
    #block(
      fill: white,
      stroke: 1.2pt + accent,
      radius: 6pt,
      inset: (x: 16pt, y: 7pt),
    )[
      #text(size: 24pt, weight: "bold", fill: accent)[#equation]
    ]
    #v(9pt)
    #text(size: 17pt, fill: ink)[#line-a]
    #v(2pt)
    #text(size: 17pt, fill: ink)[#line-b]
  ]
]

#let qft-legend() = block(
  width: 100%,
  height: 112pt,
  fill: white,
  stroke: 1.5pt + border,
  radius: 8pt,
  inset: (x: 18pt, y: 12pt),
)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 24pt,
    [
      #align(center + horizon)[
        #box(width: 34pt, height: 30pt, stroke: 1pt + ink, inset: 0pt)[
          #align(center + horizon)[#text(size: 18pt)[$H$]]
        ]
        #h(12pt)
        #text(size: 18pt, fill: ink)[Hadamard-role gate]
      ]
    ],
    [
      #align(center + horizon)[
        #box(width: 40pt, height: 30pt, stroke: 1pt + ink, inset: 0pt)[
          #align(center + horizon)[#text(size: 17pt)[$M_k$]]
        ]
        #h(12pt)
        #text(size: 18pt, fill: ink)[controlled-phase gate]
      ]
    ],
  )
]

#let qft-circuit(length: 27pt) = canvas(length: length, {
  import draw: *
  let bold-stroke = (paint: black, thickness: 1.9pt)
  let bold-dash = (paint: gray, thickness: 1.15pt, dash: "dashed")
  let bold-gate-stroke = (paint: black, thickness: 1.35pt)
  let qgate(pos, label, name, width: 0.58, height: 0.58, label-size: 18pt) = {
    rect((pos.at(0) - width / 2, pos.at(1) - height / 2), (pos.at(0) + width / 2, pos.at(1) + height / 2), fill: white, stroke: bold-gate-stroke, name: name)
    content((pos.at(0), pos.at(1)), text(font: gate-font, size: label-size, weight: "bold", fill: ink)[#label])
  }
  let qcphase(x, y1, y2, label, name) = {
    circle((x, y1), radius: 0.08, fill: black, stroke: none, name: name + "a")
    circle((x, y2), radius: 0.08, fill: black, stroke: none, name: name + "b")
    line((x, y1), (x, y2), stroke: bold-stroke)
    qgate((x, (y1 + y2) / 2), label, name + "m", width: 0.62, height: 0.62, label-size: 18pt)
  }
  let ys = (0, -0.8, -1.6, -3.2, -4.0, -4.8)
  let right = 5.0
  rect((-3.2, -5.25), (-2.55, 0.45), fill: white, stroke: bold-gate-stroke, name: "bq-img")
  content("bq-img", text(size: 20pt, weight: "bold")[$bold(x)$])
  line((-3.2, -2.4), (-2.55, -2.4), stroke: bold-dash)
  for i in range(6) {
    line((-2.55, ys.at(i)), (right, ys.at(i)), stroke: bold-stroke)
  }
  line((-3.25, -2.4), (right, -2.4), stroke: bold-dash)

  qgate((-2.0, -1.6), h-label, "bqx-hx2")
  qgate((0.0, -0.8), h-label, "bqx-hx1")
  qgate((4.2, 0), h-label, "bqx-hx0")
  qgate((-2.0, -4.8), h-label, "bqy-hy2")
  qgate((0.0, -4.0), h-label, "bqy-hy1")
  qgate((4.2, -3.2), h-label, "bqy-hy0")

  qcphase(-1.0, -0.8, -1.6, m-label(1), "bqx-mx21")
  qcphase(1.4, 0, -1.6, m-label(2), "bqx-mx12")
  qcphase(2.6, 0, -0.8, m-label(1), "bqx-mx11")

  qcphase(-1.0, -4.0, -4.8, m-label(1), "bqy-my21")
  qcphase(1.4, -3.2, -4.8, m-label(2), "bqy-my12")
  qcphase(2.6, -3.2, -4.0, m-label(1), "bqy-my11")
})

#let stage-arrow() = block(width: 100%, height: 100%)[
  #align(center + horizon)[
    #polygon(
      fill: rgb("#0f766e"),
      stroke: none,
      (0pt, 11pt),
      (26pt, 11pt),
      (26pt, 2pt),
      (42pt, 18pt),
      (26pt, 34pt),
      (26pt, 25pt),
      (0pt, 25pt),
    )
  ]
]

#let stage-gap() = block(width: 100%, height: 100%)[]

#let quill_panel(body) = block(width: 100%, height: 100%)[
  #set text(size: 11pt, font: "New Computer Modern", fill: black)
  #align(center + horizon)[#body]
]

#let qft_fig10(scale: 150%, column-spacing: 0.7em) = quill_panel[
  #quantum-circuit(
    scale: scale,
    row-spacing: 0.58em,
    column-spacing: column-spacing,
    lstick($x_1$), $H$, ctrl(1), ctrl(2), 1, 1, 1, [\ ],
    lstick($x_2$), 1,   $M$,     1,       $H$, ctrl(1), 1, [\ ],
    lstick($x_3$), 1,   1,       $M$,     1,   $M$,     $H$, [\ ],
    lstick($y_1$), $H$, ctrl(1), ctrl(2), 1, 1, 1, [\ ],
    lstick($y_2$), 1,   $M$,     1,       $H$, ctrl(1), 1, [\ ],
    lstick($y_3$), 1,   1,       $M$,     1,   $M$,     $H$,
  )
]

#let tebd_fig10(scale: 165%) = quill_panel[
  #quantum-circuit(
    scale: scale,
    row-spacing: 0.58em,
    column-spacing: 0.74em,
    lstick($x_1$), $H$, ctrl(1), 1,      $T$, [\ ],
    lstick($x_2$), $H$, $T$,    ctrl(1), 1,   [\ ],
    lstick($x_3$), $H$, 1,      $T$,     ctrl(-2), [\ ],
    lstick($y_1$), $H$, ctrl(1), 1,      $T$, [\ ],
    lstick($y_2$), $H$, $T$,    ctrl(1), 1,   [\ ],
    lstick($y_3$), $H$, 1,      $T$,     ctrl(-2),
  )
]

#let entangled_qft_fig10(scale: 150%) = quill_panel[
  #quantum-circuit(
    scale: scale,
    row-spacing: 0.58em,
    column-spacing: 0.5em,
    lstick($x_1$), $H$, ctrl(1), ctrl(2), 1, 1, 1, ctrl(3), 1, 1, [\ ],
    lstick($x_2$), 1,   $M$,     1,       $H$, ctrl(1), 1, 1, ctrl(3), 1, [\ ],
    lstick($x_3$), 1,   1,       $M$,     1,   $M$,     $H$, 1, 1, ctrl(3), [\ ],
    lstick($y_1$), $H$, ctrl(1), ctrl(2), 1, 1, 1, $E$, 1, 1, [\ ],
    lstick($y_2$), 1,   $M$,     1,       $H$, ctrl(1), 1, 1, $E$, 1, [\ ],
    lstick($y_3$), 1,   1,       $M$,     1,   $M$,     $H$, 1, 1, $E$,
  )
]

#let richbasis_fig10(scale: 165%) = quill_panel[
  #quantum-circuit(
    scale: scale,
    row-spacing: 0.58em,
    column-spacing: 0.66em,
    lstick($x_1$), $H$, mqgate($U^((4))$, n: 2), 1, mqgate($U^((4))$, n: 3), 1, 1, [\ ],
    lstick($x_2$), 1,   1,                         1, 1,                         $H$, mqgate($U^((4))$, n: 2), [\ ],
    lstick($x_3$), 1,   1,                         1, 1,                         1,   1,                         [\ ],
    lstick($y_1$), $H$, mqgate($U^((4))$, n: 2), 1, mqgate($U^((4))$, n: 3), 1, 1, [\ ],
    lstick($y_2$), 1,   1,                         1, 1,                         $H$, mqgate($U^((4))$, n: 2), [\ ],
    lstick($y_3$), 1,   1,                         1, 1,                         1,   1,
  )
]

#let banner-skeleton() = block(width: 100%, height: 695pt)[
  #grid(
    columns: (0.86fr, 44pt, 2.1fr, 44pt, 1.9fr, 44pt, 1.72fr),
    gutter: 12pt,
    rows: (100%),
    [
      #stage-shell[
        #grid(
          columns: (1fr,),
          rows: (58pt, 1fr, 24pt, 1fr),
          gutter: 18pt,
          [#blank-box(58pt)],
          [#blank-box(100%)],
          [#blank-box(24pt)],
          [#blank-box(100%)],
        )
      ]
    ],
    [#stage-gap()],
    [
      #stage-shell[
        #grid(
          columns: (1fr,),
          rows: (76pt, 1fr),
          gutter: 18pt,
          [
            #stage-heading(
              [FFT -> relaxed QFT],
              [Cooley-Tukey circuit gates become trainable unitaries],
            )
          ],
          [
            #grid(
              columns: (1fr,),
              rows: (1.36fr, 0.64fr),
              gutter: 18pt,
              [
                #block(width: 100%, height: 100%, fill: white, stroke: 1.5pt + border, radius: 8pt)[
                  #qft_fig10(scale: 190%, column-spacing: 0.92em)
                ]
              ],
              [
                #grid(
                  columns: (1fr, 1fr),
                  rows: (1fr),
                  gutter: 18pt,
                  [
                    #relaxation-card(
                      rgb("#0f766e"),
                      [$H -> U(2)$],
                      [Hadamard-role gates],
                      [become trainable unitaries],
                    )
                  ],
                  [
                    #relaxation-card(
                      rgb("#a16207"),
                      [$M_k -> U(1)^4$],
                      [controlled-phase gates],
                      [become trainable phases],
                    )
                  ],
                )
              ],
            )
          ],
        )
      ]
    ],
    [#stage-gap()],
    [
      #stage-shell[
        #grid(
          columns: (1fr, 1fr),
          rows: (1fr),
          gutter: 20pt,
          [
            #grid(
              columns: (1fr,),
              rows: (0.86fr, 48pt, 0.86fr, 48pt, 0.86fr),
              gutter: 18pt,
              [#blank-box(100%)],
              [#blank-box(48pt)],
              [#blank-box(100%)],
              [#blank-box(48pt)],
              [#blank-box(100%)],
            )
          ],
          [
            #blank-box(100%)
          ],
        )
      ]
    ],
    [#stage-gap()],
    [
      #stage-shell[
        #grid(
          columns: (0.9fr, 0.7fr, 0.9fr, 0.9fr),
          rows: (1fr, 1fr),
          gutter: 18pt,
          [#blank-box(100%)],
          [#blank-box(100%)],
          [#blank-box(100%)],
          [#blank-box(100%)],
          [#blank-box(100%)],
          [#blank-box(100%)],
          [#blank-box(100%)],
          [#blank-box(100%)],
        )
      ]
    ],
  )
]

#let tebd(length: 52pt) = canvas(length: length, {
  import draw: *
  let ys = (0, -0.8, -1.6, -3.2, -4.0, -4.8)
  let right = 4.65
  rect((-3.2, -5.25), (-2.55, 0.45), fill: white, stroke: circuit-gate-stroke, name: "tebd-img")
  content("tebd-img", text(size: 18pt, weight: "bold")[$bold(x)$])
  line((-3.2, -2.4), (-2.55, -2.4), stroke: circuit-dash)
  for i in range(6) {
    line((-2.55, ys.at(i)), (right, ys.at(i)), stroke: circuit-stroke)
  }
  line((-3.25, -2.4), (right, -2.4), stroke: circuit-dash)

  for i in range(3) {
    gate-box((-2.0, ys.at(i)), h-label, "txh" + str(i))
    gate-box((-2.0, ys.at(i + 3)), h-label, "tyh" + str(i))
  }

  cphase(-0.65, 0, -0.8, t-label(1), "tx01")
  cphase(0.95, -0.8, -1.6, t-label(2), "tx12")
  cphase(3.35, 0, -1.6, t-label(3), "tx20")

  cphase(-0.65, -3.2, -4.0, t-label(4), "ty01")
  cphase(0.95, -4.0, -4.8, t-label(5), "ty12")
  cphase(3.35, -3.2, -4.8, t-label(6), "ty20")
})

#let entangled-qft(length: 77pt) = canvas(length: length, {
  import draw: *
  let ys = (0, -0.8, -1.6, -3.2, -4.0, -4.8)
  let right = 6.0
  rect((-3.2, -5.7), (-2.55, 0.9), fill: white, stroke: circuit-gate-stroke, name: "img")
  content("img", text(size: 18pt, weight: "bold")[$bold(x)$])
  line((-3.2, -2.4), (-2.55, -2.4), stroke: circuit-dash)
  for i in range(6) {
    line((-2.55, ys.at(i)), (right, ys.at(i)), stroke: circuit-stroke)
  }
  line((-3.25, -2.4), (right, -2.4), stroke: circuit-dash)

  gate-box((-2.0, -1.6), h-label, "hx2")
  gate-box((0.0, -0.8), h-label, "hx1")
  gate-box((4.2, 0), h-label, "hx0")
  gate-box((-2.0, -4.8), h-label, "hy2")
  gate-box((0.0, -4.0), h-label, "hy1")
  gate-box((4.2, -3.2), h-label, "hy0")

  cphase(-1.0, -0.8, -1.6, m-label(1), "mx21")
  cphase(1.4, 0, -1.6, m-label(2), "mx12")
  cphase(2.6, 0, -0.8, m-label(1), "mx11")

  cphase(-1.0, -4.0, -4.8, m-label(1), "my21")
  cphase(1.4, -3.2, -4.8, m-label(2), "my12")
  cphase(2.6, -3.2, -4.0, m-label(1), "my11")

  egate(-1.55, -1.6, -4.8, e-label(3), "e3")
  egate(0.7, -0.8, -4.0, e-label(2), "e2")
  egate(5.2, 0, -3.2, e-label(1), "e1")
})

#let richbasis(length: 77pt) = canvas(length: length, {
  import draw: *
  let ys = (0, -0.8, -1.6, -3.2, -4.0, -4.8)
  let right = 4.55
  rect((-3.2, -5.25), (-2.55, 0.45), fill: white, stroke: circuit-gate-stroke, name: "rich-img")
  content("rich-img", text(size: 18pt, weight: "bold")[$bold(x)$])
  line((-3.2, -2.4), (-2.55, -2.4), stroke: circuit-dash)
  for i in range(6) {
    line((-2.55, ys.at(i)), (right, ys.at(i)), stroke: circuit-stroke)
  }
  line((-3.25, -2.4), (right, -2.4), stroke: circuit-dash)

  gate-box((-1.75, -0.8), h-label, "rxh1", label-dy: 0.06)
  multi-gate(-0.75, -0.8, -1.6, u4-label, "rxu12", label-dy: 0.2)
  multi-gate(0.55, 0, -1.6, u4-label, "rxu123", label-dy: 0.2)
  line((0.28, -0.8), (0.82, -0.8), stroke: circuit-overlap-dash)
  gate-box((1.85, -1.6), h-label, "rxh2", label-dy: 0.06)
  multi-gate(3.05, -0.8, -1.6, u4-label, "rxu23", label-dy: 0.2)
  gate-box((4.1, 0), h-label, "rxh3", label-dy: 0.06)

  gate-box((-1.75, -4.0), h-label, "ryh1", label-dy: 0.06)
  multi-gate(-0.75, -4.0, -4.8, u4-label, "ryu12", label-dy: 0.2)
  multi-gate(0.55, -3.2, -4.8, u4-label, "ryu123", label-dy: 0.2)
  line((0.28, -4.0), (0.82, -4.0), stroke: circuit-overlap-dash)
  gate-box((1.85, -4.8), h-label, "ryh2", label-dy: 0.06)
  multi-gate(3.05, -4.0, -4.8, u4-label, "ryu23", label-dy: 0.2)
  gate-box((4.1, -3.2), h-label, "ryh3", label-dy: 0.06)
})

#let raw-section(title, subtitle: none, body) = grid(
  columns: (1fr,),
  rows: (600pt, 105pt),
  gutter: 14pt,
  [
    #block(width: 100%, height: 600pt)[#align(center + horizon)[#body]]
  ],
  [
    #block(width: 100%)[
      #text(size: 34pt, weight: "bold", fill: ink)[#title]
      #v(4pt)
      #if subtitle != none [
        #text(size: 22pt, fill: muted)[#subtitle]
      ]
    ]
  ],
)

#rect(width: 100%, height: 100%, fill: soft-bg, stroke: none)[
  #grid(
    columns: (1fr,),
    rows: (800pt, 1fr),
    gutter: 24pt,
    [
      #block(width: 100%)[
        #text(size: 38pt, weight: "bold", fill: ink)[End-to-end training process]
        #v(8pt)
        #text(size: 24pt, fill: muted)[Dataset to learned sparse transform to reconstruction]
        #v(14pt)
        #banner-skeleton()
      ]
    ],
    [
      #grid(
        columns: (0.95fr, 1.1fr, 0.95fr),
        gutter: 12pt,
        [
          #raw-section(
            [TEBD],
            subtitle: [Nearest-neighbor ring topology with wrap-around gates],
          )[
            #tebd_fig10(scale: 220%)
          ]
        ],
        [
          #raw-section(
            [Entangled-QFT],
            subtitle: [Full-image separable transform plus row-column entanglement gates],
          )[
            #entangled_qft_fig10(scale: 200%)
          ]
        ],
        [
          #raw-section(
            [Block-wrapped RichBasis],
            subtitle: [The learned within-block transform used in the main comparison],
          )[
            #richbasis_fig10(scale: 220%)
          ]
        ],
      )
    ],
  )
]
