class dig {

  static recurse_VarRef := true
  static max_recurse := 100

  __New(x?) {
    this.stack := []
    this.result := this(x?)
  }

  Call(x?) {
    this.stack.push(x?)
    idx := dig.spades.findIndex(fn => fn(x?))
    if not idx
      result :=  'give up'
    blade := dig.spades[idx].blade
    if blade.hasProp('Call')
      if blade.minParams == 2
        result := blade(this, x?)
      else
        result := blade(x?)
    else
      result := blade

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
      steps.shift()

    while steps.length {
      step := steps.shift()

      if (x.hasProp('OwnProps')) {
        if (x.hasOwnProp(step)) {
          desc := x.getOwnPropDesc(step)
          if desc.hasOwnProp('Get') {
            x := dig.__descriptor(desc)
            continue
          }
        }
      }

      x := x.%step%
    }

    return x
  }

  ; private class
  class __descriptor {
    __New(desc) {
      this.desc := desc
    }
  }

  static getNearestProps(x) {
    return dig.getAllProps(x, true)
  }

  static getAllProps(x, nearest := false) {
    prop_map := Map()
    paths := dig.propPathSearch(x, nearest)
    for path in paths {
      propname := StrSplit(path, '.')[-1]
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
    ts.shift()
    for t in ts {
      if ( isSet(t) 
        and t.hasProp('prototype')
        and t.prototype.hasProp('OwnProps')
      ) {
        arr := arr.concat(Arrays.fromEnumerator(t.prototype.ownprops()))
        break
      }
    }
    return arr
  }

  class spade {
    __New(fn_handle, blade, args*) {
      this.fn_handle := fn_handle
      this.blade  := blade
    }
    Call(x?) {
      fn_handle := this.fn_handle
      return fn_handle(x?)
    }
  }

  getIndent() {
    str := ''
    i := 1
    while (i < this.stack.length) {
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
    prop_map := dig.getAllProps(x, nearest)
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

  openMap(x) {
    prop_arr := []
    for n, v in dig.getNearestProps(x) {
      prop_arr.push(n . ': ' . this(v))
    }
    for n, v in x {
      prop_arr.push(n . ' -> ' . this(v))
    }
    return this.prettify(type(x), prop_arr, '{', '}')
  }

  openArray(x) {
    prop_arr := []
    for y in x {
      prop_arr.push(this(y?))
    }
    return this.prettify(type(x), prop_arr, '[', ']')
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
    args_str := args_str_arr.join(', ')
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
        , props.map(s => (indent[2] . s))
            .join(',`n')
        , indent[1] . pc))

    indent := this.getIndent()
    if props.findIndex((s) => (InStr(s, '`n')))
      return unfold(indent, type_x, props, po, pc)

    oneline := Format('{} {}{}{}'
      , type_x
      , po
      , props.join(', ')
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
    return dig.recurse_VarRef
      ? "VarRef ~> " . this(%x%)
      : "VarRef"
  }

  static spades := [
      dig.spade((x?) => (not IsSet(x)), 'unset')
    , dig.spade((x) => (x is Number), (x) => (x))
    , dig.spade((x) => (x is String), (x) => (Format('"{}"', x)))
    , dig.spade((x) => (x is Func),   (x) => (dig.signature(x)))
    , dig.spade((x) => (x is Array),  (this, x) => (this.openArray(x)))
    , dig.spade((x) => (x is VarRef), (this, x) => (this.openVarRef(x)))
    , dig.spade((x) => (type(x) == 'Prototype')
      , (this, x) => (this.openPrototype(x)))
    , dig.spade((x) => (x is Class),  (this, x) => (this.openClass(x)))
    , dig.spade((x) => (type(x) == 'Object'), (this, x) => this.openObject(x))
    , dig.spade((x) => (x is Map),    (this, x) => (this.openMap(x)))
    , dig.spade((x) => (x is Object), (this, x) => (this.openNearest(x)))
  ]
}
