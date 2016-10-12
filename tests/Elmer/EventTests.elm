module Elmer.EventTests exposing (all)

import Test exposing (..)
import Elmer.TestApp as App
import Expect
import Elmer exposing (..)
import Elmer.Event as Event

all : Test
all =
  describe "Event Tests"
    [ clickTests
    , inputTests
    , customEventTests
    ]

standardEventHandlerBehavior : (ComponentStateResult App.Model App.Msg -> ComponentStateResult App.Model App.Msg) -> String -> Test
standardEventHandlerBehavior eventHandler eventName =
  describe "Event Handler Behavior"
  [ describe "when there is an upstream failure"
    [ test "it passes on the error" <|
      \() ->
        let
          initialState = UpstreamFailure "upstream failure"
        in
          eventHandler initialState
            |> Expect.equal initialState
    ]
  , describe "when there is no target node"
    [ test "it returns an upstream failure" <|
      \() ->
        let
          initialState = Elmer.componentState App.defaultModel App.view App.update
        in
          eventHandler initialState
           |> Expect.equal (UpstreamFailure "No target node specified")
    ]
  , describe "when the event is not found on the target node"
    [ test "it returns an event not found error" <|
      \() ->
        let
          initialState = Elmer.componentState App.defaultModel App.view App.update
        in
          Elmer.find ".awesome" initialState
            |> eventHandler
            |> Expect.equal (UpstreamFailure ("No " ++ eventName ++ " event found"))
    ]
  ]

clickTests =
  describe "Click Event Tests"
  [ standardEventHandlerBehavior Event.click "click"
  , describe "when the click succeeds"
    [ test "it updates the model accordingly" <|
      \() ->
        let
          initialState = Elmer.componentState App.defaultModel App.view App.update
          updatedStateResult = Elmer.find ".button" initialState
                                |> Event.click
        in
          case updatedStateResult of
            CurrentState updatedState ->
              Expect.equal updatedState.model.clicks 1
            UpstreamFailure msg ->
              Expect.fail msg
    ]
  ]

inputTests =
  describe "input event tests"
  [ standardEventHandlerBehavior (Event.input "fun stuff") "input"
  , describe "when the input succeeds"
    [ test "it updates the model accordingly" <|
      \() ->
        let
          initialState = Elmer.componentState App.defaultModel App.view App.update
          updatedStateResult = Elmer.find ".nameField" initialState
                                |> Event.input "Mr. Fun Stuff"
        in
          case updatedStateResult of
            CurrentState updatedState ->
              Expect.equal updatedState.model.name "Mr. Fun Stuff"
            UpstreamFailure msg ->
              Expect.fail msg
    ]
  ]

customEventTests =
  let
    keyUpEventJson = "{\"keyCode\":65}"
  in
    describe "custom event tests"
    [ standardEventHandlerBehavior (Event.on "keyup" keyUpEventJson) "keyup"
    , describe "when the event succeeds"
      [ test "it updates the model accordingly" <|
        \() ->
          let
            initialState = Elmer.componentState App.defaultModel App.view App.update
            updatedStateResult = Elmer.find ".nameField" initialState
                                  |> Event.on "keyup" keyUpEventJson
          in
            case updatedStateResult of
              CurrentState updatedState ->
                Expect.equal updatedState.model.lastLetter 65
              UpstreamFailure msg ->
                Expect.fail msg

      ]
    ]