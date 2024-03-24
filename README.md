Useful for inspecting ahk objects and other values.
Requires [Arrays.ahk](https://github.com/lawkaita/Arrays.ahk).

## Usage
```ahk
str := dig.dig(thing, booleanSearchEveryPropertyWhichThingHasAccesTo?)
```
## Example
code
```ahk
obj := {
  a: 1,
  b: {},
  c: [1,2, ,4],
  d: MsgBox,
  x: Map(1,2,3,4, "foo", "bar"),
}
obj.c.push(obj.c)
x := 12345
obj.f := &x
obj.e := &obj

MsgBox(dig.dig(obj))
```
result
```
Object {
  a: 1,
  b: Object {},
  c: Array [
    1,
    2,
    unset,
    4,
    <self referred> Array
  ],
  d: built-in Func MsgBox(a1?, a2?, a3?),
  e: VarRef ~> <self referred> Object,
  f: VarRef ~> 12345,
  x: Map {
    1 -> 2,
    3 -> 4,
    "foo" -> "bar"
  }
}
```
## Search every property a thing has access to
code
```ahk
MsgBox(dig.dig({}))
```
result
```
Object {}
```
code
```ahk
MsgBox(dig.dig({}), true)
```
result
```
Object {
  Clone: built-in Func Object.Prototype.Clone(this),
  DefineProp: built-in Func Object.Prototype.DefineProp(this, a2, a3),
  DeleteProp: built-in Func Object.Prototype.DeleteProp(this, a2),
  GetMethod: built-in Func GetMethod(a1, a2?, a3?),
  GetOwnPropDesc: built-in Func Object.Prototype.GetOwnPropDesc(this, a2),
  HasBase: built-in Func HasBase(a1, a2),
  HasMethod: built-in Func HasMethod(a1, a2?, a3?),
  HasOwnProp: built-in Func Object.Prototype.HasOwnProp(this, a2),
  HasProp: built-in Func HasProp(a1, a2),
  OwnProps: built-in Func Object.Prototype.OwnProps(this),
  __Class: "Object",
  base: Object.Prototype {
    __Class: "Object",
    Clone: built-in Func Object.Prototype.Clone(this),
    DefineProp: built-in Func Object.Prototype.DefineProp(this, a2, a3),
    DeleteProp: built-in Func Object.Prototype.DeleteProp(this, a2),
    GetOwnPropDesc: built-in Func Object.Prototype.GetOwnPropDesc(this, a2),
    HasOwnProp: built-in Func Object.Prototype.HasOwnProp(this, a2),
    OwnProps: built-in Func Object.Prototype.OwnProps(this)
  }
}
```
## Expand .__Enums.
code
```ahk
RegExMatch("foo := bar(baz, quux)", "^(\w+)[ ]*:=[ ]*(\w+)\((\w+),[ ]*(\w+)\)", &SubPat)
dig.recurse__Enum := false
MsgBox dig.dig(SubPat)
```
result
```
RegExMatchInfo {
  blah blah...
  __Enum: built-in Func RegExMatchInfo.Prototype.__Enum(this, a2?),
  blah blah...
}
```
code
```ahk
RegExMatch("foo := bar(baz, quux)", "^(\w+)[ ]*:=[ ]*(\w+)\((\w+),[ ]*(\w+)\)", &SubPat)
dig.recurse__Enum := true
MsgBox dig.dig(SubPat)
```
result
```
RegExMatchInfo {
  blah blah...
  __Enum: built-in Func RegExMatchInfo.Prototype.__Enum(this, a2?)
  `--> built-in Enumerator <anonymous>(&a1?, &a2?) {
    0 -> "foo := bar(baz, quux)",
    1 -> "foo",
    2 -> "bar",
    3 -> "baz",
    4 -> "quux"
  },
  blah blah...
}
```
