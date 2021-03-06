module Elmer.Html.Matchers exposing
  ( element
  , elements
  , elementExists
  , hasText
  , hasClass
  , hasProperty
  , hasAttribute
  , hasId
  , hasStyle
  , listensForEvent
  )

{-| Make expectations about the Html generated by the component's view function.

# HtmlTarget Matchers
@docs element, elementExists, elements

# HtmlElement Matchers
@docs hasText, hasId, hasClass, hasStyle, hasAttribute, hasProperty, listensForEvent

-}

import Elmer exposing (Matcher)
import Elmer.Internal exposing (..)
import Elmer.Html.Types exposing (..)
import Elmer.Html
import Elmer.Html.Internal as Html_
import Elmer.Html.Query as Query
import Elmer.Printer exposing (..)
import Expect
import String
import Json.Decode as Json
import Dict exposing (Dict)
import Html as Html exposing (Html)


{-| Make expectations about the selected element.

The matcher will fail if the selected element does not exist.

If the selector matches more than one element,
the given element matcher will only be applied to the first element selected.

    Elmer.Html.target "div"
      |> Elmer.Html.expect (element <| hasText "Fun Stuff")

-}
element : Matcher (Elmer.Html.HtmlElement msg) -> Matcher (Elmer.Html.HtmlTarget msg)
element elementMatcher query =
  case Query.findElement query of
    Ok element ->
      elementMatcher element
    Err msg ->
      Expect.fail msg

{-| Expect that the selected element exists.

    Elmer.Html.target "#cool-element" testState
      |> Elmer.Html.expect elementExists
-}
elementExists : Matcher (Elmer.Html.HtmlTarget msg)
elementExists query =
  case Query.findElement query of
    Ok _ ->
      Expect.pass
    Err msg ->
      Expect.fail msg


{-| Make expectations about the selected elements.

If the selector fails to match any elements, an empty list will
be passed to the given matcher.

    Elmer.Html.target "li" testState
      |> Elmer.Html.expect (elements <| Elmer.hasLength 4)

-}
elements : Matcher (List (Elmer.Html.HtmlElement msg)) -> Matcher (Elmer.Html.HtmlTarget msg)
elements listMatcher query =
  Query.findElements query
    |> listMatcher


{-| Expect that an element has some text. This matcher will pass only if the element
or any of its descendents contains some `Html.text` with the specified text.
-}
hasText : String -> Matcher (Elmer.Html.HtmlElement msg)
hasText text node =
    let
        texts =
            flattenTexts node.children
    in
        if List.length texts == 0 then
            Expect.fail (format [ message "Expected element to have text" text, description "but it has no text" ])
        else if List.member text texts then
            Expect.pass
        else
            Expect.fail (format [ message "Expected element to have text" text, message "but it has" (printList texts) ])

{-| Expect that an element has the specified class. No need to prepend the class name with a dot.
-}
hasClass : String -> Matcher (Elmer.Html.HtmlElement msg)
hasClass className node =
    let
        classList =
            Html_.classList node
    in
        if List.length classList > 0 then
            if List.member className classList then
                Expect.pass
            else
                Expect.fail (format [message "Expected element to have class" className, message "but it has" (printList classList) ])
        else
            Expect.fail (format [message "Expected element to have class" className, description "but it has no classes" ])

{-| Expect that an element has the specified property with the specified value.

    hasProperty ( "innerHtml", "Fun <i>stuff</i>" ) element

-}
hasProperty : (String, String) -> Matcher (Elmer.Html.HtmlElement msg)
hasProperty (name, value) node =
  case Html_.property name node of
    Just propertyValue ->
      if value == propertyValue then
        Expect.pass
      else
        Expect.fail (format [message "Expected element to have property" (name ++ " = " ++ value),
          message "but it has" (name ++ " = " ++ propertyValue) ])
    Nothing ->
      Expect.fail (format [message "Expected element to have property" (name ++ " = " ++ value),
          description "but it has no property with that name" ])

{-| Expect that an element has the specified attribute with the specified value.

    hasAttribute ( "src", "http://fun.com" ) element

-}
hasAttribute : (String, String) -> Matcher (Elmer.Html.HtmlElement msg)
hasAttribute (name, value) element =
  case Html_.attribute name element of
    Just attributeValue ->
      if value == attributeValue then
        Expect.pass
      else
        Expect.fail (format [message "Expected element to have attribute" (name ++ " = " ++ value),
          message "but it has" (name ++ " = " ++ attributeValue) ])
    Nothing ->
      Expect.fail (format [message "Expected element to have attribute" (name ++ " = " ++ value),
          description "but it has no attribute with that name" ])


{-| Expect that an element has the specified id. No need to prepend the id with a pound sign.
-}
hasId : String -> Matcher (Elmer.Html.HtmlElement msg)
hasId expectedId node =
  case Html_.elementId node of
    Just nodeId ->
      if nodeId == expectedId then
        Expect.pass
      else
        Expect.fail (format [message "Expected element to have id" expectedId, message "but it has id" nodeId ])
    Nothing ->
      Expect.fail (format [message "Expected element to have id" expectedId, description "but it has no id" ])

{-| Expect that an element has the specified style.

    hasStyle ("left", "20px") element

-}
hasStyle : (String, String) -> Matcher (Elmer.Html.HtmlElement msg)
hasStyle (name, value) element =
  case Html_.styles element of
    Just styles ->
      case Dict.get name styles of
        Just styleValue ->
          if styleValue == value then
            Expect.pass
          else
            Expect.fail <| format
              [ message "Expected element to have style" <| name ++ ": " ++ value
              , message "but it has style" (printDict styles)
              ]
        Nothing ->
          Expect.fail <| format
            [ message "Expected element to have style" <| name ++ ": " ++ value
            , message "but it has style" (printDict styles)
            ]
    Nothing ->
      Expect.fail <| format
        [ message "Expected element to have style" <| name ++ ": " ++ value
        , description "but it has no style"
        ]

{-| Expect that an element listens for an event of the given type.

    listensForEvent "click" element

Note: This will not consider event handlers on the element's ancestors.

-}
listensForEvent : String -> Matcher (Elmer.Html.HtmlElement msg)
listensForEvent event element =
  if List.isEmpty element.eventHandlers then
    Expect.fail <| format
      [ message "Expected element to listen for event" event
      , description "but it has no event listeners"
      ]
  else
    if List.any (\eventHandler -> eventHandler.eventType == event) element.eventHandlers then
      Expect.pass
    else
      Expect.fail <| format
        [ message "Expected element to listen for event" event
        , message "but it listens for" <| (
          List.map .eventType element.eventHandlers
            |> String.join "\n"
          )
        ]


-- Private functions

flattenTexts : List (HtmlNode msg) -> List String
flattenTexts children =
    List.concat <|
        List.map
            (\child ->
                case child of
                    Element n ->
                        flattenTexts n.children

                    Text t ->
                        [ t ]
            )
            children


printList : List String -> String
printList list =
    String.join ", " list

printDict : Dict String String -> String
printDict dict =
  Dict.toList dict
    |> List.map (\(name, value) -> name ++ ": " ++ value)
    |> String.join "\n"
