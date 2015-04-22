FsharpEditView = require './fsharp-edit-view'
FsharpEditTooltipView = require './fsharp-edit-tooltip-view'
{CompositeDisposable} = require 'atom'
{$, View} = require 'atom-space-pen-views'
fs = require 'fs'
{spawn} = require 'child_process'
utils = require './utils'

module.exports = FsharpEdit =

  config:
    enableThing:
      type: 'boolean'
      default: false
    thingVolume:
      type: 'integer'
      default: 5
      minimum: 1
      maximum: 11

  fsharpEditView: null
  fsharpEditTooltipView: null
  modalPanel: null
  subscriptions: null
  fspipe: null
  completionResolve: null
  mouseIdleTimer: null
  markers: []

  subscribeToActiveTextEditor: ->
    self = @
    clearTimeout(@mouseIdleTimer) if @mouseIdleTimer
    $('.editor').off 'mousemove.fsharp-tooltip'
    editor = self.getActiveEditor()
    view = atom.views.getView(editor)

    if $(view).attr('data-grammar') != 'source fsharp'
      return

    @onDidChange.dispose() if @onDidChange
    @onDidChange = editor.onDidChange () ->
      self.fsharpEditTooltipView?.destroy()
      clearTimeout(self.mouseIdleTimer) if self.mouseIdleTimer

    parse = () ->
      parseCmd = "parse \"#{editor.getPath()}\"\n#{editor.getText()}\n<<EOF>>\n"
      # console.log parseCmd
      self.fspipe?.stdin.write parseCmd
    parse()

    @onDidStopChanging.dispose() if @onDidStopChanging
    @onDidStopChanging = editor.onDidStopChanging () ->
      parse()

    requestTooltip = () ->
      path = editor.getPath()
      pos = self.bufferPosition

      sendCmd = true

      for marker in self.markers
        if marker.getBufferRange().containsPoint(pos)
          self.fsharpEditTooltipView?.destroy()
          self.fsharpEditTooltipView = new FsharpEditTooltipView()
          if marker.error.Subcategory == 'typecheck'
            self.fsharpEditTooltipView.element.classList.add('fsharp-edit-tooltip-type-error')
          else if marker.error.Subcategory == 'parse'
            self.fsharpEditTooltipView.element.classList.add('fsharp-edit-tooltip-parse-error')
          else
            self.fsharpEditTooltipView.element.classList.add('fsharp-edit-tooltip-parse-error')
          element = atom.views.getView(editor)
          element.appendChild self.fsharpEditTooltipView.element
          self.fsharpEditTooltipView.message.textContent = marker.error.Message
          pos = utils.pixelPositionFromMouseEvent(editor, self.lastMouseMove)
          self.fsharpEditTooltipView.position(pos)
          sendCmd = false

      if sendCmd
        tooltipCmd = "tooltip \"#{path}\" #{pos.row + 1} #{pos.column + 1}\n"
        self.fspipe?.stdin.write tooltipCmd
        # console.log editor
        # console.log tooltipCmd

    $(view).on 'mousemove.fsharp-tooltip', (e) ->
      self.lastMouseMove = e
      self.lastX = e.offsetX
      self.lastY = e.offsetY
      screenPosition = utils.screenPositionFromMouseEvent(editor, e)
      self.bufferPosition = editor.bufferPositionForScreenPosition(screenPosition)
      self.fsharpEditTooltipView?.destroy()
      clearTimeout(self.mouseIdleTimer) if self.mouseIdleTimer
      self.mouseIdleTimer = setTimeout(requestTooltip,1000)

  getActiveEditor: ->
    atom.workspace.getActiveTextEditor()

  activate: (state) ->

    @fsharpEditView = new FsharpEditView(state.fsharpEditViewState)
    #@fsharpEditTooltipView = new FsharpEditTooltipView(state.fsharpEditTooltipViewState)
    @modalPanel = atom.workspace.addBottomPanel(item: @fsharpEditView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'fsharp-edit:toggle': => @toggle()

    @subscriptions.add atom.workspace.onDidChangeActivePaneItem => @subscribeToActiveTextEditor()

    # @subscriptions.add atom.config.observe 'did-select-next', (newValue) ->
    #   console.log 'autocomplete-plus:select-next:', newValue

    @subscriptions.add atom.packages.getActivePackage('autocomplete-plus').mainModule.autocompleteManager.suggestionList.onDidSelectNext =>
      console.log 'suggestionList.onDidSelectNext'

    #@subscriptions.add atom.

    #return

    self = @

    # fspath = path.join utils.packagePath(), 'bin', 'FSharp.AutoComplete', 'fsautocomplete.exe'
    fspath ='/Users/rozgo/Projects/FSharpExpose/bin/Debug/FSharpExpose.exe'
    # fspath = '/Users/rozgo/Projects/fsharpbinding/FSharp.AutoComplete/bin/Debug/fsautocomplete.exe'
    console.log fspath
    console.log (atom.packages.resolvePackagePath('fsharp-edit'))
    @fspipe = spawn 'mono', [fspath]

    @fspipe.stderr.on 'data', (data) ->
      # console.log "ERROR"
      # console.log data.toString()
      process.stderr.write data.toString()
    @fspipe.stdout.on 'data', (data) ->
      # console.log "OUTPUT"
      # console.log data.toString()
      jsons = data.toString().split '\n'
      # jsons.pop()
      # console.log "JSONS COUNT: " + jsons.length
      # console.log jsons
      for json in jsons
        try
          if json.length == 0
            continue
          # console.log "JSON LENGTH: " + json.length
          data = JSON.parse json
          editor = self.getActiveEditor()
          # console.log data
          if data.Kind == 'completion'
            suggestions = []
            prefix = self.completionResolve.prefix
            for item in data.Data
              console.log item
              # continue
              if prefix == '.'
                suggestions.push {text: item.Item1, type: item.Item2, replacementPrefix: ''}
              else if item.Item1.startsWith(prefix)
                suggestions.push {
                  text: item.Item1
                  type: item.Item2
                  replacementPrefix: prefix
                  description: item.Item3}
            console.log atom
            self.completionResolve.promise(suggestions) if self.completionResolve?
          else if data.Kind == 'tooltip'
            self.fsharpEditTooltipView?.destroy()
            self.fsharpEditTooltipView = new FsharpEditTooltipView(state.fsharpEditTooltipViewState)
            element = atom.views.getView(editor)
            element.appendChild self.fsharpEditTooltipView.element
            self.fsharpEditTooltipView.message.textContent = data.Data
            pos = utils.pixelPositionFromMouseEvent(editor, self.lastMouseMove)
            self.fsharpEditTooltipView.position(pos)
          else if data.Kind == 'errors'
            # console.log data.Data
            for marker in self.markers
              marker.destroy()
            self.markers = []
            for error in data.Data
              # if error.Subcategory == 'typecheck'
                # console.log error
                range = [[error.StartLine, error.StartColumn],[error.EndLine, error.EndColumn]]
                marker = editor.markBufferRange(range, invalidate: 'never')
                marker.error = error
                self.markers.push marker
                # editor.decorateMarker(marker, {type: 'gutter', class: 'linter-error'})
                decorator = editor.decorateMarker(marker, {type: 'highlight', class: 'fsharp-edit-type-error'})
                # console.log decorator
          else if data.Kind == 'debug'
            console.log data.Log
        catch error
          console.log "OUTPUT"
          console.log data.toString()
          # console.log error

    console.log atom.project
    console.log utils.packagePath()
    console.log atom.project.getPaths()[0]

    # @fspipe.stdin.write 'outputmode json\n'
    @fspipe.stdin.write 'project "/Users/rozgo/Projects/fsharp-edit/Test1/Test1.fsproj"\n'
    # @fspipe.stdin.write 'project "/Users/rozgo/Projects/BrinkOfWar/Frontal/Frontal.fsproj"\n'
    # @fspipe.stdin.write 'project "/Users/rozgo/Projects/fsharpbinding/FSharp.AutoComplete/FSharp.AutoComplete.fsproj"\n'
    # @fspipe.stdin.write 'project "/Users/rozgo/Projects/SingleAppDemo/SingleAppDemo/SingleAppDemo.fsproj"\n'


    @subscribeToActiveTextEditor()



    # fs.readFile '/Users/rozgo/Projects/fsharp-edit/Test1/Program.fs', (err, data) ->
    #   self.fspipe.stdin.write 'outputmode json\n'
    #   self.fspipe.stdin.write 'project "/Users/rozgo/Projects/fsharp-edit/Test1/Test1.fsproj"\n'
    #   msg = 'parse "/Users/rozgo/Projects/fsharp-edit/Test1/Program.fs"\n' + data + '\n<<EOF>>\n'
    #   console.log msg
    #   self.fspipe.stdin.write msg
    #   self.fspipe.stdin.write 'completion "/Users/rozgo/Projects/fsharp-edit/Test1/Program.fs" 8 19\n'
    #   self.fspipe.stdin.write 'tooltip "/Users/rozgo/Projects/fsharp-edit/Test1/Program.fs" 6 15\n'
    #   self.fspipe.stdin.write 'declarations "/Users/rozgo/Projects/fsharp-edit/Test1/Program.fs"\n'
    #   console.log self.fspipe

  autocomplete: ->

    self = @

    return {

      selector: '.source.fsharp'
      # disableForSelector: '.source.fsharp .constant, .source.fsharp .string'

      # This will take priority over the default provider, which has a priority of 0.
      # `excludeLowerPriority` will suppress any providers with a lower priority
      # i.e. The default provider will be suppressed
      inclusionPriority: 1
      excludeLowerPriority: true

      # Required: Return a promise, an array of suggestions, or null.
      getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix}) ->

        if prefix == ''
          return null
        # console.log {editor, bufferPosition, scopeDescriptor, prefix}
        console.log 'prefix: ' + prefix
        console.log 'scopeDescriptor: '
        console.log scopeDescriptor
        new Promise (resolve) ->
          pos = bufferPosition
          path = editor.getPath()
          parseCmd = "parse \"#{path}\"\n#{editor.getText()}\n<<EOF>>\n"
          completionCmd = "completion \"#{path}\" \"#{prefix}\" #{pos.row + 1} #{pos.column + 0}\n"
          self.fspipe.stdin.write parseCmd
          self.fspipe.stdin.write completionCmd
          self.completionResolve = {promise: resolve, prefix: prefix}

      # (optional): called _after_ the suggestion `replacementPrefix` is replaced
      # by the suggestion `text` in the buffer
      onDidInsertSuggestion: ({editor, triggerPosition, suggestion}) ->

      # (optional): called when your provider needs to be cleaned up. Unsubscribe
      # from things, kill any processes, etc.
      dispose: ->
    }

  deactivate: ->
    clearTimeout(@mouseIdleTimer) if @mouseIdleTimer
    $('.editor').off 'mousemove.fsharp-tooltip'
    @fspipe.disconnect()
    @modalPanel.destroy()
    @fsharpEditTooltipView?.destroy()
    @activeItemSubscription.dispose()
    @selectionSubscription?.dispose()
    @subscriptions.dispose()
    @fsharpEditView.destroy()

  serialize: ->
    fsharpEditViewState: @fsharpEditView.serialize()
    fsharpEditTooltipViewState: @fsharpEditTooltipView.serialize()

  toggle: ->
    console.log 'FsharpAtomComplete was toggled!'
    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
