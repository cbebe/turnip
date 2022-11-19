@module("predictor")
external predict: (. int, string, int) => Js.TypedArray2.Float32Array.t = "predict"

module Prediction = {
  type t = {pattern: Pattern.t, probability: float, prices: array<int>}
}

type t = {predictions: array<Prediction.t>, time: float}

let sendPredictions = (res, len, time) => {
  let predictions = []
  for i in 0 to len / 26 - 1 {
    open Js.TypedArray2.Float32Array
    open Prediction
    let pattern = Pattern.fromInt(res->unsafe_get(i * 26)->Obj.magic)
    let probability = res->unsafe_get(i * 26 + 1)->Obj.magic

    let prices = Js.Array2.from(res->slice(~start=i * 26 + 2, ~end_=(i + 1) * 26)->Obj.magic)
    predictions->Js.Array2.push({probability, pattern, prices})->ignore
  }
  Ok({predictions, time})
}

let predict = (buyPrice: int, sellPrices: array<option<int>>, patternInt: int) => {
  try {
    let start = Js.Date.now()
    let res = predict(. buyPrice, sellPrices->Js.Array2.joinWith(","), patternInt)
    let time = Js.Date.now() -. start
    switch res->Js.TypedArray2.Float32Array.length {
    | len if mod(len, 26) == 0 => sendPredictions(res, len, time)
    | len => Error(`bad buffer length: ${Belt.Int.toString(len)}`)
    }
  } catch {
  | Js.Exn.Error(obj) => Error(obj->Obj.magic)
  }
}
