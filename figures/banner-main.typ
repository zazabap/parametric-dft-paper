#import "@preview/cetz:0.4.2": canvas, draw

#set page(width: 2172pt, height: 1650pt, margin: 44pt)
#set text(size: 30pt, fill: rgb("#1f2937"))

#let ink = rgb("#1f2937")
#let muted = rgb("#64748b")
#let border = rgb("#cbd5e1")
#let panel-bg = rgb("#ffffff")
#let soft-bg = white
#let purple = rgb("#7f00ff")
#let circuit-stroke = (paint: black, thickness: 1.1pt)
#let circuit-stroke-purple = (paint: purple, thickness: 1.1pt)
#let circuit-dash = (paint: gray, thickness: 0.8pt, dash: "dashed")
#let circuit-overlap-dash = (paint: black, thickness: 1.1pt, dash: "dashed")
#let circuit-gate-stroke = (paint: black, thickness: 0.9pt)

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

#let gate-box(pos, label, name, width: 0.56, height: 0.46, color: ink, label-dy: 0) = {
  import draw: *
  rect((pos.at(0) - width / 2, pos.at(1) - height / 2), (pos.at(0) + width / 2, pos.at(1) + height / 2), fill: white, stroke: (paint: color, thickness: 0.9pt), name: name)
  content((pos.at(0), pos.at(1) + label-dy), text(size: 16pt, weight: "bold", fill: color)[#label])
}

#let multi-gate(x, y1, y2, label, name, width: 0.88, label-dy: 0) = {
  import draw: *
  rect((x - width / 2, y2 - 0.32), (x + width / 2, y1 + 0.32), fill: white, stroke: circuit-gate-stroke, name: name)
  content((x, (y1 + y2) / 2 + label-dy), text(size: 16pt, weight: "bold")[#label])
}

#let cphase(x, y1, y2, label, name) = {
  import draw: *
  circle((x, y1), radius: 0.055, fill: black, stroke: none, name: name + "a")
  circle((x, y2), radius: 0.055, fill: black, stroke: none, name: name + "b")
  line((x, y1), (x, y2), stroke: circuit-stroke)
  gate-box((x, (y1 + y2) / 2), label, name + "m", width: 0.52, height: 0.4)
}

#let egate(x, y1, y2, label, name) = {
  import draw: *
  circle((x, y1), radius: 0.055, fill: purple, stroke: none)
  circle((x, y2), radius: 0.055, fill: purple, stroke: none)
  line((x, y1), (x, y2), stroke: circuit-stroke-purple)
  gate-box((x, (y1 + y2) / 2), label, name, width: 0.52, height: 0.4, color: purple)
}

#let entangled-qft() = canvas(length: 77pt, {
  import draw: *
  let ys = (0, -0.8, -1.6, -2.4, -4.0, -4.8, -5.6, -6.4)
  let labels = ($x_0$, $x_1$, $x_2$, $x_3$, $y_0$, $y_1$, $y_2$, $y_3$)
  rect((-3.2, -6.85), (-2.55, 0.45), fill: white, stroke: circuit-gate-stroke, name: "img")
  content("img", text(size: 16pt)[$bold(x)$])
  line((-3.2, -3.2), (-2.55, -3.2), stroke: circuit-dash)
  for i in range(8) {
    content((-3.75, ys.at(i)), text(size: 16pt)[#labels.at(i)])
    line((-2.55, ys.at(i)), (8.4, ys.at(i)), stroke: circuit-stroke)
  }
  line((-3.9, -3.2), (8.4, -3.2), stroke: circuit-dash)
  for i in range(4) {
    content((8.75, ys.at(i)), text(size: 16pt)[$x'_#i$])
    content((8.75, ys.at(i + 4)), text(size: 16pt)[$y'_#i$])
  }

  gate-box((-2.0, -2.4), $H$, "hx3")
  gate-box((0.2, -1.6), $H$, "hx2")
  gate-box((3.2, -0.8), $H$, "hx1")
  gate-box((7.0, 0), $H$, "hx0")
  gate-box((-2.0, -6.4), $H$, "hy3")
  gate-box((0.2, -5.6), $H$, "hy2")
  gate-box((3.2, -4.8), $H$, "hy1")
  gate-box((7.0, -4.0), $H$, "hy0")

  cphase(-0.55, -1.6, -2.4, $M_1$, "mx21")
  cphase(1.55, -0.8, -2.4, $M_2$, "mx12")
  cphase(2.35, -0.8, -1.6, $M_1$, "mx11")
  cphase(4.55, 0, -2.4, $M_3$, "mx03")
  cphase(5.35, 0, -1.6, $M_2$, "mx02")
  cphase(6.15, 0, -0.8, $M_1$, "mx01")

  cphase(-0.55, -5.6, -6.4, $M_1$, "my21")
  cphase(1.55, -4.8, -6.4, $M_2$, "my12")
  cphase(2.35, -4.8, -5.6, $M_1$, "my11")
  cphase(4.55, -4.0, -6.4, $M_3$, "my03")
  cphase(5.35, -4.0, -5.6, $M_2$, "my02")
  cphase(6.15, -4.0, -4.8, $M_1$, "my01")

  egate(-1.35, -2.4, -6.4, $E_4$, "e4")
  egate(0.8, -1.6, -5.6, $E_3$, "e3")
  egate(3.8, -0.8, -4.8, $E_2$, "e2")
  egate(8.0, 0, -4.0, $E_1$, "e1")
})

#let richbasis() = canvas(length: 77pt, {
  import draw: *
  let ys = (0, -0.8, -1.6, -2.4, -4.0, -4.8, -5.6, -6.4)
  let labels = ($x_0$, $x_1$, $x_2$, $x_3$, $y_0$, $y_1$, $y_2$, $y_3$)
  rect((-3.2, -6.85), (-2.55, 0.45), fill: white, stroke: circuit-gate-stroke, name: "rich-img")
  content("rich-img", text(size: 16pt)[$bold(x)$])
  line((-3.2, -3.2), (-2.55, -3.2), stroke: circuit-dash)
  for i in range(8) {
    content((-3.75, ys.at(i)), text(size: 16pt)[#labels.at(i)])
    line((-2.55, ys.at(i)), (8.4, ys.at(i)), stroke: circuit-stroke)
  }
  line((-3.9, -3.2), (8.4, -3.2), stroke: circuit-dash)
  for i in range(4) {
    content((8.75, ys.at(i)), text(size: 16pt)[$x'_#i$])
    content((8.75, ys.at(i + 4)), text(size: 16pt)[$y'_#i$])
  }

  gate-box((-1.45, -0.8), $H$, "rxh1", label-dy: 0.06)
  multi-gate(-0.55, -0.8, -1.6, $U^((4))$, "rxu12", label-dy: 0.22)
  multi-gate(1.05, -0.8, -2.4, $U^((4))$, "rxu123", label-dy: 0.22)
  line((0.61, -1.6), (1.49, -1.6), stroke: circuit-overlap-dash)
  gate-box((2.25, -1.6), $H$, "rxh2", label-dy: 0.06)
  multi-gate(3.15, -1.6, -2.4, $U^((4))$, "rxu23", label-dy: 0.22)
  gate-box((4.25, -2.4), $H$, "rxh3", label-dy: 0.06)

  gate-box((-1.45, -4.8), $H$, "ryh1", label-dy: 0.06)
  multi-gate(-0.55, -4.8, -5.6, $U^((4))$, "ryu12", label-dy: 0.22)
  multi-gate(1.05, -4.8, -6.4, $U^((4))$, "ryu123", label-dy: 0.22)
  line((0.61, -5.6), (1.49, -5.6), stroke: circuit-overlap-dash)
  gate-box((2.25, -5.6), $H$, "ryh2", label-dy: 0.06)
  multi-gate(3.15, -5.6, -6.4, $U^((4))$, "ryu23", label-dy: 0.22)
  gate-box((4.25, -6.4), $H$, "ryh3", label-dy: 0.06)
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
        #image("banner-main-hires.png", width: 100%)
      ]
    ],
    [
      #grid(
        columns: (1fr, 1fr),
        gutter: 48pt,
        [
          #raw-section(
            [Entangled-QFT],
            subtitle: [Full-image separable transform plus row-column entanglement gates],
          )[
            #align(center)[#entangled-qft()]
          ]
        ],
        [
          #raw-section(
            [Block-wrapped RichBasis],
            subtitle: [The learned within-block transform used in the main comparison],
          )[
            #align(center)[#richbasis()]
          ]
        ],
      )
    ],
  )
]
