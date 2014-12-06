# Main app
#----------------------------------------------------------------------

class UnicoApp
  constructor: ->
    @controllers = {}
    @directives = {}

  addController: (name, clazz) ->
    @controllers[name] = clazz

  addDirective: (name, clazz) ->
    @directives[name] = clazz

  build: ->
    @instances = []
    # Search for controllers
    for el in document.querySelectorAll("[controller]")
      name = el.getAttribute 'controller'
      clazz = @controllers[name]
      ctrl = new clazz()
      @instances.push new UnicoInstance @, ctrl, el
    return @

  refresh: ->
    for instance in @instances
      instance.refresh()
    true