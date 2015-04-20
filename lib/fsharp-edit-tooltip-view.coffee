{$, View} = require 'atom-space-pen-views'

module.exports =

class FsharpEditTooltipView

  constructor: (serializedState) ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('fsharp-edit-tooltip')
    @element.classList.add('overlayer')

    # Create message element
    @message = document.createElement('div')
    @message.textContent = "A tool tip message goes here"
    @message.classList.add('message')
    @element.appendChild(@message)

  position: (pos) ->
    $(@element).css
      left: pos.left
      top: pos.top

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element
