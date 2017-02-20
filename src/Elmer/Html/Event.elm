module Elmer.Html.Event
    exposing
        ( click
        , doubleClick
        , input
        , on
        )

{-| Trigger events on targeted elements. When an event occurs, Elmer will
call the component's `update` method with the resulting message.

# Mouse Events
@docs click, doubleClick

# Form Events
@docs input

# Custom Events
@docs on

-}

import Json.Decode as Json
import Elmer.Html.Types exposing (..)
import Elmer.Internal as Internal exposing (..)
import Elmer
import Elmer.Runtime as Runtime
import Dict


type alias EventHandler msg =
    HtmlElement msg -> EventResult msg


type EventResult msg
    = Message msg
    | EventFailure String


clickHandler : String -> EventHandler msg
clickHandler clickType node =
    genericHandler clickType "{}" node

{-| Trigger a click event on the targeted element.
-}
click : Elmer.ComponentState model msg -> Elmer.ComponentState model msg
click componentStateResult =
    handleEvent (clickHandler "click") componentStateResult

{-| Trigger a double click event on the targeted element.
-}
doubleClick : Elmer.ComponentState model msg -> Elmer.ComponentState model msg
doubleClick componentState =
    handleEvent (clickHandler "dblclick") componentState

inputHandler : String -> EventHandler msg
inputHandler inputString node =
    let
        eventJson =
            "{\"target\":{\"value\":\"" ++ inputString ++ "\"}}"
    in
        genericHandler "input" eventJson node

{-| Trigger an input event on the targeted element.
-}
input : String -> Elmer.ComponentState model msg -> Elmer.ComponentState model msg
input inputString componentStateResult =
    handleEvent (inputHandler inputString) componentStateResult


genericHandler : String -> String -> EventHandler msg
genericHandler eventName eventJson node =
    case getEvent eventName node of
        Just customEvent ->
            let
                message =
                    Json.decodeString customEvent.decoder eventJson
            in
                eventResult message customEvent

        Nothing ->
            EventFailure ("No " ++ eventName ++ " event found")

{-| Trigger a custom event on the targeted element.

The following will trigger a `keyup` event:

    componentState
      |> on "keyup" "{\"keyCode\":65}"
-}
on : String -> String -> Elmer.ComponentState model msg -> Elmer.ComponentState model msg
on eventName eventJson componentStateResult =
    handleEvent (genericHandler eventName eventJson) componentStateResult


-- Private functions


getEvent : String -> HtmlElement msg -> Maybe (HtmlEvent msg)
getEvent eventName node =
    List.head (List.filter (\e -> e.eventType == eventName) node.events)


handleEvent : EventHandler msg -> ComponentState model msg -> ComponentState model msg
handleEvent eventHandler componentStateResult =
    componentStateResult
        |> Internal.map (handleNodeEvent eventHandler)


handleNodeEvent : EventHandler msg -> Component model msg -> ComponentState model msg
handleNodeEvent eventHandler componentState =
    case componentState.targetElement of
        Just node ->
            updateComponent node eventHandler componentState

        Nothing ->
            Failed "No target node specified"


updateComponent : HtmlElement msg -> EventHandler msg -> Component model msg -> ComponentState model msg
updateComponent node eventHandler componentState =
    case eventHandler node of
        Message msg ->
          Runtime.performUpdate msg componentState
            |> asComponentState

        EventFailure msg ->
            Failed msg


asComponentState : Result String (Component model msg) -> ComponentState model msg
asComponentState commandResult =
  case commandResult of
    Ok updatedComponentState ->
      Ready updatedComponentState
    Err message ->
      Failed message


eventResult : Result String msg -> HtmlEvent msg -> EventResult msg
eventResult eventResult event =
    case eventResult of
        Ok m ->
            Message m

        Err e ->
            EventFailure e
