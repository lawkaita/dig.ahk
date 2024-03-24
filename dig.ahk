#Requires AutoHotkey v2.0
#Include <v2/Arrays/Arrays>

class dig {

  static recurse__Enum := false
  static recurseVarRef := true
  static max_recurse := 100
  static openAll := []

  __New(x?, forceAll := false) {
    this.stack := []
    this.indent_modifier := 0
    this.result := this(x?, forceAll)
  }

  static dig(x?, forceAll := false) {
    return this(x?, forceAll).result
  }

  Call(x?, forceAll := false) {
    if this.stack.length > dig.max_recurse
      return '<recursion exceeded> ' type(x)
    if IsSet(x)
      if Arrays.includes(this.stack, x)
        return '<self referred> ' . type(x)
    this.stack.push(x?)
    if forceAll {
      result := this.openAll(x?)
    } else {
      idx := Arrays.findIndex(dig.spades, (fn => fn(x?)))
      if not idx {
        result :=  '<give up>'
      } else {
        blade := dig.spades[idx].blade
        if blade.hasProp('Call')
          if blade.minParams == 2
            result := blade(this, x?)
          else
            result := blade(x?)
        else
          result := blade
      }
    }

    this.stack.pop()
    return result
  }

  static typechain(x) {
    chain := [x]
    x := x.base
    while x {
      if type(x) == 'Prototype'
        chain.push(%x.__class%)
      else
        chain.push(unset)

      x := x.base
    }
    return chain
  }

  static basechain(x) {
    chain := [x]
    x := x.base
    while x {
      chain.push(x)
      x := x.base
    }
    return chain
  }

  static typechainStr(x) {
    try
      chain := [String(x)]
    catch
      chain := ['']

    x := x.base
    while x {
      if type(x) == 'Prototype'
        chain.push(x.__class)
      else
        chain.push('')

      x := x.base
    }
    return chain
  }

  static propPathSearch(x, nearest := false) {
    paths := []
    path := ''
    while x {
      path_save := path
      if x.hasProp('OwnProps') {
         for n in x.OwnProps()
           paths.push(path . '.' . n)
      } else if (x == Any.prototype) {
         paths.push('.GetMethod', '.HasBase'
                , '.HasMethod', '.HasProp')  ; dont add 'base'
      }

      if nearest
        if type(x) == 'Prototype'
          return paths

      path := path_save '.base'
      x := x.base
    }
    return paths
  }

  static propPathEval(x, path) {
    steps := StrSplit(path, '.')

    if not steps[1]
      Arrays.shift(steps)

    while steps.length {
      step := Arrays.shift(steps)

      if (x.hasProp('OwnProps')) {
        if (x.hasOwnProp(step)) {
          desc := x.getOwnPropDesc(step)
          if desc.hasOwnProp('Get') {
            x := dig.__descriptor(desc, step)
            continue
          }
        }
      }

      x := x.%step%
    }

    return x
  }

  static propEval(x, path) {
    result := dig.propPathEval(x, path)
    if not result is dig.__descriptor
      return result
    if result.desc.hasOwnProp('get')
      if result.desc.get.minParams > 1  ; getter needs more args than just x as this
        return result.desc.get
    return x.%result.name%
  }

  ; deprecated
  static propStrEval(str) {
    x_and_path := StrSplit(str, '.', '', 2)
    x_str := x_and_path[1]
    x     := %x_str%  ; the function has no access to the value of %x_str%, it is not in its scope.
    path  := x_and_path[2]
    result := str . " := "
      . dig.propEval(x, path)
    return result
  }

  ; private class
  class __descriptor {
    __New(desc, name) {
      this.desc := desc
      this.name := name
    }
  }

  static getNearestProps(x) {
    return dig.getAllProps(x, true, true)
  }

  static getAllProps(x, nearest := false, propEval := false) {
    prop_map := Map()
    paths := dig.propPathSearch(x, nearest)
    for path in paths {
      propname := StrSplit(path, '.')[-1]
      if propEval {
        result := dig.propEval(x,path)
        prop_map[propname] := result
      } else {
        result := dig.propPathEval(x,path)
        if result is dig.__descriptor {
          for n in ['Get', 'Set', 'Call'] {
            if result.desc.hasOwnProp(n) {
              prop_map[propname . '.' . n] := result.desc.%n%
            }
          }
        } else {
          prop_map[propname] := result
        }
      }
    }
    prop_map["base"] := x.base
    return prop_map
  }

  static getAllPropNames(x) {
    arr := []
    for t in dig.typechain(x) {
      if isSet(t) {
        if t.hasProp('prototype') {
          t := t.prototype
        }
        if t.hasProp('OwnProps') {
           props := Arrays.fromEnumerator(t.OwnProps())
           arr.push(props*)
        } else if (t == Any.prototype) {
           arr.push('GetMethod', 'HasBase'
                  , 'HasMethod', 'HasProp')  ; dont add 'base'
        }
      }
    }
    return arr
  }

  static getImmediatePropNames(x) {
    ts := dig.typechain(x)
    if x.hasProp('ownprops')
      arr := Arrays.fromEnumerator(x.ownprops())
    else
      arr := []
    Arrays.shift(ts)
    for t in ts {
      if ( isSet(t) 
        and t.hasProp('prototype')
        and t.prototype.hasProp('OwnProps')
      ) {
        arr := Arrays.concat(arr, Arrays.fromEnumerator(t.prototype.ownprops()))
        break
      }
    }
    return arr
  }

  class spade {
    __New(fn_handle, blade, args*) {
      this.fn_handle := fn_handle
      this.blade     := blade
    }
    Call(x?) {
      fn_handle := this.fn_handle
      return fn_handle(x?)
    }
  }

  getIndent() {
    str := ''
    i := 1
    while (i < this.stack.length + this.indent_modifier) {
      str .= '  '
      i++
    }
    return [str, str . '  ']
  }

  carefulOpen(x, n, prop_arr) {
    if (x.hasProp('OwnProps')) {
      if (x.hasOwnProp(n)) {
        desc := x.getOwnPropDesc(n)
        if desc.hasOwnProp('Get') {
          prop_arr.push(n . '.Get' . ": " . this(desc.get))
          if desc.hasOwnProp('Set')
            prop_arr.push(n . '.Set' . ": " . this(desc.set))
          return
        }
      }
    }
    prop_arr.push(n ": " . this(x.%n%))
  }

  openPrototype(x) {
    if not x.hasProp('OwnProps')
      return x.__class . ".Prototype"
    prop_arr := []
    for n in x.OwnProps() {
      desc := x.getOwnPropDesc(n)
      if desc.hasOwnProp('Get') {
        prop_arr.push(n . '.Get' . ": " . this(desc.get))
        if desc.hasOwnProp('Set')
          prop_arr.push(n . '.Set' . ": " . this(desc.set))
      } else {
        prop_arr.push(n ": " . this(x.%n%))
      }
    }
    return this.prettify(x.__class . ".Prototype", prop_arr, '{', '}')
  }

  openNearest(x) {
    return this.openAll(x, true)
  }

  openAll(x, nearest := false) {
    prop_map := dig.getAllProps(x, nearest, true)
    prop_arr := []
    for k, v in prop_map {
      prop_arr.push(k . ': ' . this(v))
    }
    return this.prettify(type(x), prop_arr, '{', '}')
  }

  openObject(x, type_x := type(x)) {
    prop_arr := []
    for n in x.OwnProps() {
      this.carefulOpen(x, n, prop_arr)
    }
    return this.prettify(type_x, prop_arr, '{', '}')
  }

  openMap(x, type_x := type(x)) {
    prop_arr := []
    /*
    for n, v in dig.getNearestProps(x) {
      prop_arr.push(n . ': ' . this(v))
    }
    */
    for n, v in x {
      prop_arr.push(this(n) . ' -> ' . this(v))
    }
    return this.prettify(type_x, prop_arr, '{', '}')
  }

  openArray(x) {
    prop_arr := []
    for y in x {
      prop_arr.push(this(y?))
    }
    return this.prettify(type(x), prop_arr, '[', ']')
  }

  ; Maybe Todo: enums of 1 arg?
  ; Maybe Todo: enums of more args than 2?
  open__Enum(x) {
    if not dig.recurse__Enum
      return dig.signature(x)
    if this.stack.length == 1
      return dig.signature(x)

    parent := this.stack[-2]
    if type(parent) == 'Prototype'
      return dig.signature(x)

    this.indent_modifier--
    ; assumes enum arg count is 2
    result := dig.signature(x) . '`n' . this.getIndent()[2] . '``--> ' . this(x(parent, 2))
    this.indent_modifier++
    return result
  }

  openEnumerator(x) {
    return this.openMap(x, dig.signature(x))
  }

  openClass(x) {
    prop_arr := []
    for n in x.OwnProps() {
      this.carefulOpen(x, n, prop_arr)
    }
    return this.prettify("Class " . x.prototype.__class, prop_arr, '{', '}')
  }

  static signature(f) {
    args_str_arr := []
    i := 1
    static varStr := (f,i) => (Format('{}a{}{}'
      , (f.isByRef(i)    ? '&' : '')
      , i
      , (f.isOptional(i) ? '?' : '')))

    while (i <= f.maxParams) {
      args_str_arr.push(varStr(f,i))
      i++
    }

    if f.isVariadic
      args_str_arr.push('rest*')
    if InStr(f.name, '.')
      args_str_arr[1] := 'this'
    args_str := Arrays.join(args_str_arr, ', ')
    return Format('{}{} {}({})'
      , (f.isBuiltin ? 'built-in ' : '')
      , type(f)
      , (f.name      ? f.name      : '<anonymous>')
      , args_str)
  }

  prettify(type_x, props, po, pc) {
    if props.length == 0
      return type_x . ' ' . po . pc 

    static unfold := (indent, type_x, props, po, pc) => (Format('{} {}`n{}`n{}'
        , type_x
        , po
        , Arrays.join(Arrays.map(props, (s => (indent[2] . s)))
          , ',`n')
        , indent[1] . pc))

    indent := this.getIndent()
    if Arrays.findIndex(props, (s) => (InStr(s, '`n')))
      return unfold(indent, type_x, props, po, pc)

    oneline := Format('{} {}{}{}'
      , type_x
      , po
      , Arrays.join(props, ', ')
      , pc)

    if StrLen(oneline) < 33
      return oneline

    return unfold(indent, type_x, props, po, pc)
  }

  ; deprecated
  openFunc(x) {
    str := 'Func {`n'
    for n in dig.getImmediatePropNames(x) {
      y := x.%n%
      rep_y := type(y) == 'Func'
        ? type(y)
        : this(y)
      str .= n ": " rep_y ",`n"
    }
    return str . '}'
  }

  openVarRef(x) {
    return dig.recurseVarRef
      ? "VarRef ~> " . this(%x%)
      : "VarRef"
  }

  ; order matters here.
  static spades := [
      dig.spade((x?) => (not IsSet(x)), 'unset')
    , dig.spade((x) => (Arrays.includes(dig.openAll, x)), (this, x) => (this.openAll(x)))
    , dig.spade((x) => (x is Number), (x) => (x))
    , dig.spade((x) => (x is String), (x) => (Format('"{}"', x)))
    , dig.spade((x) => (x is Func and SubStr(x.name, -StrLen('.__Enum')) = '.__Enum' ), (this, x) => (this.open__Enum(x)))
    , dig.spade((x) => (x is Enumerator),          (this, x) => (this.openEnumerator(x)))
    , dig.spade((x) => (x is Func),   (x) => (dig.signature(x)))
    , dig.spade((x) => (x is Array),  (this, x) => (this.openArray(x)))
    , dig.spade((x) => (x is VarRef), (this, x) => (this.openVarRef(x)))
    , dig.spade((x) => (type(x) == 'Prototype'),   (this, x) => (this.openPrototype(x)))
    , dig.spade((x) => (x is Class),  (this, x) => (this.openClass(x)))
    , dig.spade((x) => (type(x) == 'Object'),      (this, x) => this.openObject(x))
    , dig.spade((x) => (x is Map),    (this, x) => (this.openMap(x)))
    , dig.spade((x) => (x is Object), (this, x) => (this.openNearest(x)))
  ]
}
