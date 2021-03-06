class MetaElement
  constructor: (@ctx, el) ->
    @initializeElement(el) if el

  initializeElement: (el) ->
    @_extractMeta el
    @_denormalizeRepeat()
    @_denormalizeOptions()
    @_attachComponent()
    @_attachDirectives()
    @_createClass()

  @fromStr: (ctx, html) ->
    el = document.createElement 'div'
    el.innerHTML = html
    if el.childNodes.length != 1
      new Error("fromStr require one single element")
    new MetaElement ctx, el.childNodes[0]

  clone: ->
    instance = new MetaElement(@ctx)
    Object.assign(instance, @)


  _extractMeta: (el) ->
    if el.tagName
      @tag = el.tagName.toLowerCase()
      @_extractAttributes(el)
      @_runTransformations(el)
      nodes = @_extractChildrens(el)
      @nodes = nodes if nodes.length > 0

    # comments
    else if el.nodeType == el.COMMENT_NODE
      @tag = "comment"

    # Text nodes
    else
      # Text Node
      @text = true
      @data = el.data if el.data?.trim().length > 0
      if @data && @data.match(/{{.+}}/) != null
        @interpolate = @_splitInterpolated(@data)

  # Extrac nodes from the given element
  _extractChildrens: (parent) ->
    nodes = []
    for el in @_getHtmlChildrens(parent)
      meta = new MetaElement(@ctx, el)
      nodes.push meta if meta._isValid()
    return nodes

  # Return childrens in the given HTML element.
  # Needed because element of type SCRIPT always return its content as
  # text element, so we should build a DOM from that text
  _getHtmlChildrens: (el) ->
    return el.childNodes if el.tagName != 'SCRIPT'

    # Extract a DOM from the element
    div = document.createElement 'div'
    div.innerHTML = el.innerHTML.toString()
    return div.childNodes


  # Transform html attributes into a hash
  _extractAttributes: (el) ->
    @attrs = {}
    # Return an empty hash if element has no attributes
    return false unless el.attributes and el.attributes.length > 0
    varRegexp = /{{.+}}/

    length = el.attributes.length - 1
    for i in [0..length]
      key = el.attributes[i].name
      value = el.attributes[i].value

      # Do some transformations for react
      key = "className" if key == "class"
      key = "encType" if key == "enctype"

      # Assign the value
      if varRegexp.test(value)
        @attrsInterpolated ||= {}
        @attrsInterpolated[key] = value

      @attrs[key] = value


    # Return an array with text contstants and variables interpolated
  _splitInterpolated: (content) ->
    childs = []
    lastPos = 0
    content.replace /{{([\s\w\d\[\]_\-\(\)\.,\$\?\=\!\|:"']+)}}/g, (match, capture, pos) =>
      if pos > lastPos
        childs.push {t: "text", v: content.substr(lastPos, pos - lastPos)}

      # Update lastPos
      lastPos = pos + match.length
      childs.push {t: "exp", v: capture}

    # Add the end
    if lastPos < content.length
      childs.push {t: "text", v: content.substr(lastPos, content.length - lastPos)}

    return childs


  _isValid: ->
    @tag || @data

  # Called just before create the reactElement.
  prepareIgnition: (ctx) ->
    if @directives?
      # Instantiate directives and call build if present
      for d in @directives
        if d.instance_ctx != ctx
          d.instance_ctx = ctx
          d.instance = new d.clazz()
          d.instance.build(ctx, @) if d.instance.build?

    if @attrsInterpolated
      for name, exp of @attrsInterpolated
        @attrs[name] = ctx.interpolate(exp)

  # Search for directives and create class at inspection time
  _attachDirectives:  ->
    return unless @attrs
    for key, value of @attrs
      if @ctx.app.directives[key]?
        @directives ||= []
        @directives.push { clazz: @ctx.app.directives[key] }


  _attachComponent: ->
    name = if @attrs && @attrs.component then @attrs.component else @tag
    return unless clazz = @ctx.app.components[name]
    @component = { clazz: clazz }
    if clazz.template?
      clazz.__template_meta ||= MetaElement.fromStr @ctx, clazz.template
      # Build template
      @component.template = clazz.__template_meta

    # Add directive
    @component.directive = { clazz: clazz }
    @directives ||= []
    @directives.push @component.directive


  _createClass: ->
    return unless @directives?
    # Create reactClass
    renderCallback = ->
      for d in @props.meta.directives
        d.instance.beforeRender() if d.instance.beforeRender

      ReactFactory.buildElement @props.meta, @props.ctx

    mountedCallback = ->
      for d in @props.meta.directives
        if d.instance.link
          d.instance.link @props.ctx, ReactDOM.findDOMNode(@), @props.meta

    @reactClass = React.createClass componentDidMount: mountedCallback, render: renderCallback


  _denormalizeRepeat: ->
    return unless @attrs?.repeat
    @repeatExp = @_denormalizeCollectionExp @attrs.repeat

  # Denormalize expression from collection in form
  # "value in items()" or "key, value in items()
  _denormalizeOptions: ->
    return unless @attrs?.options
    optExp = @attrs.options.match(/(.*) from (.*)/)
    return unless optExp
    fieldExp = @_denormalizeFieldExp optExp[1]
    fromExp = @_denormalizeCollectionExp optExp[2]
    @optionsExp = {field: fieldExp, from: fromExp}

  # Denormalize expression from collection in form
  # "value in items()" or "key, value in items()
  _denormalizeCollectionExp: (str) ->
    exp = str.match(/([\w\d_\$]+)\s?,?\s?([\w\d_\$]+)?\s+in\s+([\s\w\d\[\]_\(\)\.\$"']+)/)
    return undefined unless exp
    exp_1 = exp[1]
    exp_2 = exp[2]
    collectionExpression = exp[3]
    exp = {src: collectionExpression}

    if exp_2
      exp.key = exp_1
      exp.value = exp_2
    else
      exp.value = exp_1

    return exp

  _denormalizeFieldExp: (str) ->
    exp = str.match(/([\w\d\[\]_\(\)\.\$"']+)(\sas\s)?([\s\w\d\[\]_\(\)\.\$"']+)?/)
    return false unless exp
    if exp[2]
      {src: str, key: exp[1], value: exp[3]}
    else
      {src: str, value: exp[1]}



  _runTransformations: ->
    # Register template
    if @tag == 'script' && @attrs.type = "text/html"
      return @_transformTemplate()

  # We need to store templates for later use
  _transformTemplate: ->
    @attrs.hide = true
    @ctx.instance.templates ||= {}
    @ctx.instance.templates[@attrs.id] = @
