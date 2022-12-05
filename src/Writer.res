open Webapi.Dom

@inline
let select = query => document->Document.querySelector(query)->Belt.Option.getUnsafe

let cmpFloat: (float, float) => int = %raw(`(a, b) => a > b ? -1 : a < b ? 1 : 0 `)

@inline
let setText = (el, text) => {
  el->Element.setTextContent("")
  let t = {
    let p = document->Document.createElement("p")
    p->Element.setTextContent(text)
    p
  }
  el->Element.appendChild(~child=t)
  el
}

// WARNING: This assumes that the Pattern enum will never change.
// Adding an extra variant/reordering will mess up everything.
external toInt: Pattern.t => int = "%identity"

@inline
let sortPredictions = res => {
  open Predictor
  let categoryProbs = Belt.Array.make(4, 0.)
  for i in 0 to res.predictions->Js.Array2.length - 1 {
    let pred = res.predictions[i]
    let idx = pred.pattern->toInt
    categoryProbs[idx] = categoryProbs[idx] +. pred.probability
  }
  let predictions = res.predictions->Js.Array2.sortInPlaceWith((a, b) => {
    switch (a, b) {
    | ({pattern: ap, probability: ab}, {pattern: bp, probability: bb}) if ap == bp =>
      cmpFloat(ab, bb)
    | ({pattern: ap}, {pattern: bp}) => cmpFloat(categoryProbs[ap->toInt], categoryProbs[bp->toInt])
    }
  })

  (predictions, categoryProbs)
}

let writeError = (text: string) => select("#result")->setText(`error: ${text}`)->ignore

type table = ShowAll | Hide | ShowOne(Pattern.t)

let filterPredictions = (predictions: array<Predictor.Prediction.t>, table: table) => {
  switch table {
  | ShowAll => predictions
  | Hide => []
  | ShowOne(pattern) => predictions->Js.Array2.filter(p => p.pattern == pattern)
  }
}

let createButton = (label: string, action: table, predictions: array<Predictor.Prediction.t>) => {
  let button = document->Document.createElement("button")
  button->Element.setTextContent(label->Obj.magic)
  button->Element.addEventListener("click", _ => {
    Table.remove()
    let predictions = filterPredictions(predictions, action)
    if predictions->Js.Array2.length > 0 {
      select("#result")->Element.appendChild(~child=Table.make(predictions))
    }
  })
  button
}

let displayResults = (res: Predictor.t) => {
  let (predictions, categories) = sortPredictions(res)

  let result =
    select("#result")->setText(
      `Took ${res.time->Belt.Float.toString} ms to calculate ${res.predictions
        ->Js.Array2.length
        ->Belt.Int.toString} predictions`,
    )

  for i in 0 to 3 {
    if categories[i] > 0. {
      let pattern = i->Obj.magic
      let label = `${pattern->Pattern.toString} (${Table.formatPercent(categories[i])}%)`
      let button = createButton(label, ShowOne(pattern), predictions)
      result->Element.appendChild(~child=button)
    }
  }
  let showAll = createButton("Show All", ShowAll, predictions)
  let hideAll = createButton("Hide", Hide, predictions)
  result->Element.appendChild(~child=showAll)
  result->Element.appendChild(~child=hideAll)
}
