# Main app
#----------------------------------------------------------------------

class UnicoApp
  @builtInDirectives = {}

  constructor: (@opt={})->
    @controllers = {}
    @directives = UnicoApp.builtInDirectives
    @components = {}
    @_mountedCallbacks = []

    if @opt.enableRouter
      @router = @_createRouter()
      @tmplFactory = new TemplateFactory(base: @opt.templateBasePath)

  addController: (name, clazz) ->
    @controllers[name] = clazz

  addDirective: (name, clazz) ->
    @directives[name] = clazz

  addComponent: (name, clazz) ->
    @components[name] = clazz

  refresh: ->
    if @instances
      i.changed() for i in @instances

    true

  # One Time Render
  #----------------------------------------------------------------------

  render: ->
    @instances = []
    # Search for controllers
    for el in document.querySelectorAll("[controller]")
      controllerName = el.getAttribute 'controller'
      instance = new UnicoInstance @, controllerName
      instance.build(el)
      @instances.push instance
    return @


  # Router
  #----------------------------------------------------------------------

  buildRender: ->
    body = document.querySelector @opt.targetElement
    reactClass = React.createClass render: ->
      return React.DOM.div( {}, []) unless @props.meta && @props.ctx
      ReactFactory.buildElement @props.meta, @props.ctx

    reactElement = React.createElement(reactClass, {meta: false, ctx: false})
    @reactRender = React.render reactElement, body


  visit: (path) ->
    @router.visit path

  startRouter: ->
    @buildRender()
    @router.start()

  addMountListener: (listener) ->
    @_mountedCallbacks.push listener

  _loadRoute: (request, path) ->
    try
      ctrlName = request.route.controller
      instance = new UnicoInstance @, ctrlName, @reactRender
      @instances = [instance]
      instance.buildRoute request, path

    catch error
      console.error(error.stack) if @debug
      return false

  _createRouter: ->
    router = new UnicoRouter()
    router.addRouteChangedListener (request, path) =>
      @_loadRoute(request, path)
    @opt.targetElement ||= "body"
    return router

  _onMounted: ->
    c() for c in @_mountedCallbacks
