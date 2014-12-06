class MetaElement
  constructor: (el) ->
    @_extractMeta el

  isValid: ->
    @tag || @data

  _extractMeta: (el) ->
    if el.tagName
      @tag = el.tagName.toLowerCase()
      @attrs = @_extractAttributes(el)
      nodes = @_extractChildrens(el)
      @nodes = nodes if nodes.length > 0
    else
      @data = el.data if el.data?.trim().length > 0
      if @data && @data.match(/{{.+}}/) != null
        @interpolate = @_splitInterpolated(@data)

  # Extrac nodes from the given element
  _extractChildrens: (parent) ->
    nodes = []
    for el in parent.childNodes
      meta = new MetaElement(el)
      nodes.push meta if meta.isValid()
    return nodes

  # Transform html attributes into a hash
  _extractAttributes: (el) ->
    attrs = {}
    # Return an empty hash if element has no attributes
    return attrs unless el.attributes and el.attributes.length > 0

    length = el.attributes.length - 1
    for i in [0..length]
      key = el.attributes[i].name
      value = el.attributes[i].value

      # Do some transformations for react
      key = "className" if key == "class"

      # Assign the value
      attrs[key] = value

    return attrs

  _splitInterpolated: (content) ->
    childs = []
    lastPos = 0
    content.replace /{{([\s\w\d\[\]_\(\)\.\$"']+)}}/g, (match, capture, pos) =>
      if pos > lastPos
        childs.push {t: "text", v: content.substr(lastPos, pos - lastPos)}

      # Update lastPos
      lastPos = pos + match.length
      childs.push {t: "exp", v: capture}

    childs
