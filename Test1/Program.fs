module X =
  let func x = x + 1

let testval = FileTwo.NewObjectType()

let val2 = X.func 2

let p = X.func 2

let q = 2

let val3a = testval.Terrific "hello"
let val3b = testval.Terrific 2

let val4 : FileTwo.NewObjectType = testval

let val5 : int = 2332

let val6 : int = 2

let val7 : string = ""

// let val5 = X.func 4

[<EntryPoint>]
let main args =
    printfn "Hello %d" val5
    0
