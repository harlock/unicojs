describe 'TemplateFactory', ->
  describe 'loadTemplate', ->
    describe 'preloaded layout', ->
      html = '<div>foo</div>'
      layout = undefined
      beforeEach (done) ->
        spyOn(SendRequest, 'get').and.callThrough();
        f = new TemplateFactory()
        f.addLayout 'foo', html
        f.loadTemplate({}, 'foo').done (l) ->
          layout = l
          done()

      it 'should return a resolved promise', ->
        expect(SendRequest.get).not.toHaveBeenCalled()
        expect(layout.meta).toEqual html

    describe 'new layout', ->
      layout = undefined
      beforeEach (done) ->
        spyOn(SendRequest, 'get').and.callThrough();
        f = new TemplateFactory()
        f.base = '/base/test/fixtures/'
        f.loadTemplate(createCtx(), 'template_1.html').done (l) ->
          layout = l
          done()

      it 'should return a resolved promise', ->
        expect(SendRequest.get).toHaveBeenCalled()
        expect(layout.html).toMatch 'Template 1'
        expect(layout.meta.tag).toEqual 'script'
        expect(layout.meta.attrs.id).toEqual 'template_1.html'