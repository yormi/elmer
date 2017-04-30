module Elmer.FocusEventTests exposing (all)

import Test exposing (..)
import Elmer.TestApps.FocusTestApp as App
import Expect
import Elmer
import Elmer.EventTests as EventTests
import Elmer.ComponentState as ComponentState exposing (ComponentState)
import Elmer.Html.Event as Event
import Elmer.Platform.Command as Command
import Elmer.Html as Markup

all : Test
all =
  describe "Focus Event Tests"
    [ focusTests
    , blurTests
    ]

focusTests : Test
focusTests =
  describe "focus"
  [ EventTests.standardEventBehavior Event.focus
  , EventTests.propagationBehavior Event.focus "focus"
  , let
      initialModel = App.defaultModel
      initialState = Elmer.componentState initialModel App.view App.update
    in
      describe "the focus event"
      [ test "at first the element is not focused" <|
        \() ->
          Expect.equal initialModel.isFocused False
      , test "the event updates the model" <|
        \() ->
          Markup.target "#name-field" initialState
            |> Event.focus
            |> Elmer.expectModel (\model ->
                Expect.equal model.isFocused True
              )
      ]
  ]

blurTests : Test
blurTests =
  describe "blur"
  [ EventTests.standardEventBehavior Event.blur
  , EventTests.propagationBehavior Event.blur "blur"
  , let
      initialModel = App.defaultModel
      initialState = Elmer.componentState initialModel App.view App.update
    in
      describe "the blur event"
      [ test "at first the element is not blurred" <|
        \() ->
          Expect.equal initialModel.isBlurred False
      , test "the event updates the model" <|
        \() ->
          Markup.target "#name-field" initialState
            |> Event.blur
            |> Elmer.expectModel (\model ->
                Expect.equal model.isBlurred True
              )
      ]
  ]
