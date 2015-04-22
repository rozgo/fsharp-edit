module FileTwo

type Foo =
  | Bar
  | Qux

let addition x y = x + y

let add x y = x + y

type NewObjectType() =

  static member Simple (p) = p

  member x.P = 32

  member x.Terrific (y : int) : int =
    y

  member x.Terrific (y : string) : string =
    y
