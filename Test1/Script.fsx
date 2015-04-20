#load "FileTwo.fs"

module XA =
  let funky x = x + 1

let val99 = XA.funky 21

let people = XA.funky ""

let p = FileTwo.NewObjectType()
