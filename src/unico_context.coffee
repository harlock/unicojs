class UnicoContext
  constructor: (@instance, ctrlNameOrInstance, @scope={}) ->
    @app = @instance.app
    @params = @instance.params
    @ctrl = @_createOrInstantiateController(ctrlNameOrInstance)
    @_watchExpressions = {}
    @_changeListeners = []
    @_childsScopes = []

  _createOrInstantiateController: (ctrlNameOrInstance) ->
    return ctrlNameOrInstance unless typeof(ctrlNameOrInstance) == 'string'
    clazz = @app.controllers[ctrlNameOrInstance]
    ctrl = new clazz(@) if clazz


  # Return a new evalutor with a copy of this, plus the given scope.
  # Used for each loops
  child: (scope={}, opt={}) ->
    # Build a childController with the content of this controller
    # including parent context and parent of parent context
    newScope = Object.assign({}, @scope)
    for key, value of scope
      newScope[key] = value

    childEv = new UnicoContext @instance, @ctrl, newScope
    @_childsScopes.push childEv
    childEv

  # eval: Evaluate expressions
  #----------------------------------------------------------------------

  # evaluate the given expression
  eval: (expression, extra=false) ->
    p = @_extractParams()

    if extra
      for k,v of extra
        p.keys.push k
        p.values.push v

    try
      # Execute expression
      cmd = "return #{expression};"
      func = Function(p.keys, cmd)
      value = func.apply(@ctrl, p.values)
      return value
    catch error
      if @app.debug
        console.error "Exception evaluating: #{expression}"
        console.error(error.stack)
      return null

  # TODO: Test
  set: (target, value) ->
    # value = v

    # # Escape strings and other input types
    # valueType = typeof(v)
    # unless valueType == "number" || valueType == "boolean"
    #   value = "unescape('#{escape(v)}')"

    exp = "#{target} = __value;"
    @eval exp, {__value: value}

    # # UGLY HACK
    # # Sometimes when updating values from the controller we need
    # # to append the this prefix. That doesn't happens with values
    # # in the scope, need to figure out. So the solution is ask for
    # # the value after set without the prefix. If the value doesn't
    # # change, then try again with the prefix

    if @eval(target) != value
      exp = "this.#{target} = __value"
      @eval exp, {__value: value}


  # Search and replace expressions in the given text
  interpolate: (html) ->
    html.replace /{{([\s\w\d\[\]_\-\(\)\.,\$\?\=\!:\|"']+)}}/g, (match, capture) =>
      @eval(capture) || ''

  # Extract elements in the context and store it in arrays for keys and values
  _extractParams: ->
    keys = []
    values = []
    for ctx in [@ctrl, @scope]
      for k, v of ctx
        keys.push k
        if typeof(v) == "function"
          values.push @_buildFunctionProxy k, v, @ctrl
        else
          values.push ctx[k]
    return keys: keys, values: values

  # Create functions used in the evaluator.
  # Simplify sintax and emulate functions called in the controller scope
  # For example, we can use foo() and it will execute ctrl.foo()
  _buildFunctionProxy: (k, v, ctrl) ->
    () -> v.apply ctrl, arguments


  # Digest and change
  #----------------------------------------------------------------------

  # Eval, cache and watch the given expression. Used at render time
  # for storing values for digest
  evalAndWatch: (exp) ->
    return w if w = @_watchExpressions[exp]
    value = @eval(exp)
    @_watchExpressions[exp] = value
    return value


  # A change event is emited automaticaly on digest when some value
  # change, or manually calling @changed()
  addChangeListener: (callback) ->
    @_changeListeners.push callback

  changed:  ->
    # Cleanup cached values
    @_cleanWatched()
    # Call change listeners
    c() for c in @_changeListeners

  digest: ->
    @changed() # if @hasChanges() # TODO: this worth be implemented?

  # Return true if some value change Whenever the view evaluate an
  # expression, we store the returned value.  With this function we
  # evaluate every expression in this context or childrens and return
  # true as soon as we found a diffrence
  hasChanges: ->
    for exp, old of @_watchExpressions
      newValue = @eval(exp)
      return true if newValue != old
    for c in @_childsScopes
      return true if c.hasChanges()
    return false

  _cleanWatched: ->
    c._cleanWatched() for c in @_childsScopes
    @_childsScopes = []
    @_watchExpressions = {}
