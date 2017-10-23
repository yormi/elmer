var _yormi$elmer$Native_Html = function () {
  const isSimpleTextElement = function (element) {
    const isTagger = e => e.type === 'tagger'

    const isText = e => e.type === 'text'

    if (isText(element)) return true

    if (isTagger(element) && isText(element.node)) return true

    return false
  }

  var getChildren = function (html, inheritedEventHandlers, tagger) {
    const children = html.children.map(function (element) {
      if (isSimpleTextElement(element)) {
        const elmTextHtml = _yormi$elmer$Elmer_Html_Types$Text(element.text)
        return elmTextHtml
      }

      const jsHtml = constructHtmlElement(
        element,
        inheritedEventHandlers,
        tagger
      )

      const elmHtml =  _yormi$elmer$Elmer_Html_Types$Element(jsHtml)
      return elmHtml
    })

    return _elm_lang$core$Native_List.fromArray(children)
  }

  var getHtmlEventHandlers = function(html, tagger) {
    var events = []

    if (html.facts && html.facts.EVENT) {
      for (var eventType in html.facts.EVENT) {
        var decoder = html.facts.EVENT[eventType].decoder
        if (tagger) {
          decoder = A2(_elm_lang$core$Native_Json.map1, tagger, decoder)
        }

        var event = A3(_yormi$elmer$Elmer_Html_Types$HtmlEventHandler,
          eventType,
          html.facts.EVENT[eventType].options,
          decoder);

        events.push(event);
      }
    }
    return _elm_lang$core$Native_List.fromArray(events)
  }

  var getFacts = function(facts) {
    var clonedFacts = JSON.parse(JSON.stringify(facts))
    delete clonedFacts.EVENT
    return clonedFacts
  }

  var concatLists = function (list_1, list_2) {
    var array_1 = _elm_lang$core$Native_List.toArray(list_1);
    var array_2 = _elm_lang$core$Native_List.toArray(list_2);

    var all = array_1.concat(array_2);

    return _elm_lang$core$Native_List.fromArray(all);
  }

  var composeTagger = function (f, g) {
    if (!g) return f

    return function (a) { return f(g(a)) }
  }

  var constructHtmlElement = function (html, inheritedEventHandlers, tagger) {
    var node = html
    if (html.type === 'tagger') {
      node = html.node
      tagger = tagger ? composeTagger(tagger, html.tagger) : html.tagger
      return constructHtmlElement(node, inheritedEventHandlers, tagger)
    }

    var eventHandlers = getHtmlEventHandlers(node, tagger)
    var eventHandlersToInherit = concatLists(inheritedEventHandlers, eventHandlers)

    return A5(_yormi$elmer$Elmer_Html_Types$HtmlElement,
      node.tag,
      JSON.stringify(getFacts(node.facts)),
      getChildren(node, eventHandlersToInherit, tagger),
      inheritedEventHandlers,
      eventHandlers
    )
  }

  var asHtmlElement = function(html) {
    if (html.type == "text") {
      return _elm_lang$core$Maybe$Nothing;
    }

    var inheritedEventHandlers = _elm_lang$core$Native_List.fromArray([])

    return _elm_lang$core$Maybe$Just(constructHtmlElement(html, inheritedEventHandlers))
  }

  return {
    asHtmlElement: asHtmlElement
  };

}();
