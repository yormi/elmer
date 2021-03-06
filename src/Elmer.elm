module Elmer
    exposing
        ( TestState
        , Matcher
        , given
        , (<&&>)
        , expectNot
        , each
        , some
        , exactly
        , atIndex
        , hasLength
        , init
        , expectModel
        )

{-| Basic types and functions for working with tests and matchers

# Initializing a test
@docs TestState, given

# Test an init method
@docs init

# Make expectations about the model
@docs expectModel

# Working with Matchers
@docs Matcher, (<&&>), expectNot

# List Matchers
@docs each, exactly, some, atIndex, hasLength

-}

import Html exposing (Html)
import Native.Platform
import Native.Http
import Native.Html
import Native.Spy

import Expect
import Test.Runner
import Elmer.TestState as TestState
import Elmer.Runtime as Runtime
import Elmer.Printer exposing (..)
import Array

{-| Represents the current state of the test.
-}
type alias TestState model msg
  = TestState.TestState model msg

{-| Generic type for functions that pass or fail.

A matcher returns an `Expect.Expectation` from the
[elm-test](http://package.elm-lang.org/packages/elm-community/elm-test/latest)
package.
-}
type alias Matcher a =
  (a -> Expect.Expectation)

{-| Initialize a test with a model, view function, and update function.
-}
given
  :  model
  -> ( model -> Html msg )
  -> ( msg -> model -> ( model, Cmd msg ) )
  -> TestState model msg
given =
  TestState.create

{-| Operator for conjoining matchers.
If one fails, then the conjoined matcher fails, otherwise it passes.

    Elmer.given someModel view update
      |> Elmer.Html.expect (
        Elmer.Html.Matchers.element <|
          Elmer.Html.Matchers.hasText "Awesome" <&&>
          Elmer.Html.Matchers.hasClass "cool"
        )
-}
(<&&>) : Matcher a -> Matcher a -> Matcher a
(<&&>) leftFunction rightFunction =
  (\node ->
    let
      leftResult = leftFunction node
      rightResult = rightFunction node
    in
      if leftResult == Expect.pass then
        rightResult
      else
        leftResult
  )

{-| Make expectations about the model in its current state.

    Elmer.given defaultModel view update
      |> Elmer.Html.target "button"
      |> Elmer.Html.Event.click
      |> Elmer.expectModel (\model ->
        Expect.equal model.clickCount 1
      )

Use Elmer to get the model into a certain state. Then use the normal facilities of
elm-test to describe how the model should look in that state.
-}
expectModel : Matcher model -> Matcher (TestState model msg)
expectModel matcher =
  TestState.mapToExpectation (\context ->
    matcher context.model
  )


{-| Expect that a matcher fails.
-}
expectNot : Matcher a -> Matcher a
expectNot matcher =
  (\node ->
    let
      result = matcher node
    in
      if result == Expect.pass then
        Expect.fail "Expected not to be the case but it is"
      else
        Expect.pass
  )

{-| Expect that all items in a list satisfy the given matcher.
-}
each : Matcher a -> Matcher (List a)
each matcher list =
  let
    failures = failureMessages matcher list
  in
    if List.length failures == 0 then
      Expect.pass
    else
      Expect.fail <| format
        [ description "Expected all to pass but some failed:"
        , description <| printMessages failures
        ]

{-| Expect that at least one item in a list satisfies the given matcher.
-}
some : Matcher a -> Matcher (List a)
some matcher list =
  let
    failures = failureMessages matcher list
  in
    if List.length failures < List.length list then
      Expect.pass
    else
      Expect.fail <| format
        [ description "Expected some to pass but found none. Here are the failures:"
        , description <| printMessages failures
        ]

{-| Expect that exactly some number of items in a list satisfy the given matcher.
-}
exactly : Int -> Matcher a -> Matcher (List a)
exactly expectedCount matcher list =
  let
    failures = failureMessages matcher list
    matchCount = List.length list - List.length failures
  in
    if matchCount == expectedCount then
      Expect.pass
    else
      Expect.fail <| format
        [ description <| "Expected exactly " ++ (toString expectedCount) ++
          " to pass but found " ++ (toString matchCount) ++ ". Here are the failures:"
        , description <| printMessages failures
        ]

{-| Expect that the item at the given index satisfies the given matcher.
-}
atIndex : Int -> Matcher a -> Matcher (List a)
atIndex index matcher list =
  case Array.fromList list |> Array.get index of
    Just item ->
      case Test.Runner.getFailure <| matcher item of
        Just failure ->
          Expect.fail <| format
            [ description <| "Expected item at index " ++ (toString index) ++ " to pass but it failed:"
            , description failure.message
            ]
        Nothing ->
          Expect.pass
    Nothing ->
      Expect.fail <| format
        [ description <| "Expected item at index " ++ (toString index) ++ " to pass but there is no item at that index"
        ]

printMessages : List String -> String
printMessages messages =
  String.join "\n\n" messages

failureMessages : Matcher a -> List a -> List String
failureMessages matcher =
  List.filterMap (\item ->
    case Test.Runner.getFailure <| matcher item of
      Just failure ->
        Just failure.message
      Nothing ->
        Nothing
  )

{-| Expect that a list has the given length.
-}
hasLength : Int -> Matcher (List a)
hasLength expectedCount list =
  if List.length list == expectedCount then
    Expect.pass
  else
    Expect.fail <|
      format
        [ message "Expected list to have size" (toString expectedCount)
        , message "but it has size" (toString (List.length list))
        ]

{-| Update the test context with the given model and Cmd.

The current model will be replaced by the given model and the given command
will then be executed. This is most useful for testing `init` functions.

The first argument takes a wrapper around whatever function produces the initial
model and command. This allows Elmer to evaluate the initializing function lazily,
in case any stubs need to be applied.

    Elmer.given MyComponent.defaultModel MyComponent.view MyComponent.update
      |> init (\() -> MyComponent.init)
      |> Elmer.Html.target "#title"
      |> Elmer.Html.expectElementExists

-}
init : (() -> (model, Cmd msg)) -> TestState model msg -> TestState model msg
init initThunk =
  TestState.map (\context ->
    let
      (initModel, initCommand) = initThunk ()
      updatedContext = { context | model = initModel }
    in
      case Runtime.performCommand initCommand updatedContext of
        Ok initializeContext ->
          TestState.with initializeContext
        Err message ->
          TestState.failure message
  )
