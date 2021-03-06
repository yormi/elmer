module Elmer.SpyMatcherTests exposing (..)

import Test exposing (..)
import Expect
import Elmer.TestApps.SpyTestApp as SpyApp
import Elmer.Spy as Spy
import Elmer.Spy.Matchers as Matchers exposing (stringArg)
import Elmer.Spy.Internal as Spy_ exposing (Calls, Arg(..))
import Elmer.Html as Markup
import Elmer.Html.Event as Event
import Elmer.Html.Matchers exposing (hasText)
import Elmer.Printer exposing (..)
import Elmer


type FunType
  = Fruit String
  | Bird String

type alias FunStuff =
  { name : String }

funStuff : String -> FunStuff
funStuff funThing =
  { name = funThing
  }


wasCalledTests : Test
wasCalledTests =
  describe "wasCalled"
  [ describe "when the spy has not been called"
    [ test "it fails with the message" <|
      \() ->
        Elmer.given SpyApp.defaultModel SpyApp.view SpyApp.update
          |> Spy.use [ Spy.create "clearName" (\_ -> SpyApp.clearName) ]
          |> Spy.expect "clearName" (Matchers.wasCalled 2)
          |> Expect.equal (Expect.fail <|
            format
              [ message "Expected spy clearName to have been called" "2 times"
              , message "but it was called" "0 times"
              ]
            )
    , test "it fails with a properly depluralized message" <|
      \() ->
        Elmer.given SpyApp.defaultModel SpyApp.view SpyApp.update
          |> Spy.use [ Spy.create "clearName" (\_ -> SpyApp.clearName) ]
          |> Spy.expect "clearName" (Matchers.wasCalled 1)
          |> Expect.equal (Expect.fail <|
            format
              [ message "Expected spy clearName to have been called" "1 time"
              , message "but it was called" "0 times"
              ]
            )
    ]
  , describe "when the spy has been called"
    [ describe "when the expected count does not match the number of calls"
      [ test "it fails" <|
        \() ->
          Elmer.given SpyApp.defaultModel SpyApp.view SpyApp.update
            |> Spy.use [ Spy.create "clearName" (\_ -> SpyApp.clearName) ]
            |> Markup.target "#button"
            |> Event.click
            |> Event.click
            |> Spy.expect "clearName" (Matchers.wasCalled 3)
            |> Expect.equal (Expect.fail <|
              format
                [ message "Expected spy clearName to have been called" "3 times"
                , message "but it was called" "2 times"
                ]
              )
      ]
    , describe "when the expected count matches the number of calls"
      [ test "it passes" <|
        \() ->
          Elmer.given SpyApp.defaultModel SpyApp.view SpyApp.update
            |> Spy.use [ Spy.create "clearName" (\_ -> SpyApp.clearName) ]
            |> Markup.target "#button"
            |> Event.click
            |> Event.click
            |> Spy.expect "clearName" (Matchers.wasCalled 2)
            |> Expect.equal (Expect.pass)
      ]
    ]
  ]

testCalls : String -> List (List Arg) -> Calls
testCalls name args =
  { name = name
  , calls = args
  }

wasCalledWithTests : Test
wasCalledWithTests =
  describe "wasCalledWith"
  [ describe "when the spy has not been called"
    [ test "it fails" <|
      \() ->
        Matchers.wasCalledWith [ stringArg "blah", stringArg "fun", stringArg "sun" ] (testCalls "test-spy" [])
          |> Expect.equal (Expect.fail <|
            format
              [ message "Expected spy test-spy to have been called with" "[ \"blah\"\n, \"fun\"\n, \"sun\"\n]"
              , description "but it was not called"
              ]
            )
    ]
  , describe "when the spy has been called with other args"
    [ test "it fails" <|
      \() ->
        Matchers.wasCalledWith [ stringArg "blah" ] (testCalls "test-spy" [ [ StringArg "not blah" ], [ StringArg "something" ] ])
          |> Expect.equal (Expect.fail <|
            format
              [ message "Expected spy test-spy to have been called with" "[ \"blah\"\n]"
              , message "but it was called with" "[ \"not blah\"\n]\n\n[ \"something\"\n]"
              ]
            )
    ]
  , describe "when a call matches"
    [ test "it passes" <|
      \() ->
        Matchers.wasCalledWith [ stringArg "blah" ] (testCalls "test-spy" [ [ StringArg "not blah" ], [ StringArg "blah" ] ])
          |> Expect.equal Expect.pass
    ]
  , describe "when the any argument matcher is used"
    [ test "it passes" <|
      \() ->
        Matchers.wasCalledWith [ Matchers.anyArg ] (testCalls "test-spy" [ [ StringArg "not blah" ], [ StringArg "blah" ] ] )
          |> Expect.equal Expect.pass
    ]
  ]

argMatcherTests : Test
argMatcherTests =
  describe "Argument Matcher Tests"
  [ argumentTests "Int" (Matchers.intArg 23) "23" (IntArg 23)
  , argumentTests "Float" (Matchers.floatArg 23.54) "23.54" (FloatArg 23.54)
  , argumentTests "Bool" (Matchers.boolArg True) "true" (BoolArg True)
  , argumentTests "Typed Record" (Matchers.typedArg <| funStuff "Beach") "{ name = \"Beach\" }" (TypedArg "{ name = \"Beach\" }")
  , argumentTests "Typed Union" (Matchers.typedArg <| Bird "Owl") "Bird \"Owl\"" (TypedArg "Bird \"Owl\"")
  , argumentTests "Typed List" (Matchers.typedArg <| [ "Fun", "Sun", "Beach" ]) "[\"Fun\",\"Sun\",\"Beach\"]" (TypedArg "[\"Fun\",\"Sun\",\"Beach\"]")
  , argumentTests "Function" (Matchers.functionArg) "<FUNCTION>" FunctionArg
  ]

argumentTests : String -> Arg -> String -> Arg -> Test
argumentTests name expected output actual =
  describe ( name ++ " arg" )
  [ describe "when the spy has been called with other args"
    [ test "it fails" <|
      \() ->
        Matchers.wasCalledWith [ expected ] (testCalls "test-spy" [ [ StringArg "blah" ] ])
          |> Expect.equal (Expect.fail <|
            format
              [ message "Expected spy test-spy to have been called with" <| "[ " ++ output ++ "\n]"
              , message "but it was called with" "[ \"blah\"\n]"
              ])
    ]
  , describe "when a call matches"
    [ test "it passes" <|
      \() ->
        Matchers.wasCalledWith [ expected ] (testCalls "test-spy" [ [ actual ] ])
          |> Expect.equal Expect.pass
    ]
  , describe "when the anyArg matcher is used"
    [ test "it passes" <|
      \() ->
        Matchers.wasCalledWith [ Matchers.anyArg ] (testCalls "test-spy" [ [ actual ] ])
          |> Expect.equal Expect.pass
    ]
  ]

anyArgumentTests : Test
anyArgumentTests =
  describe "Any arg"
  [ describe "when the match fails and an any argument is used"
    [ test "it prints the proper message" <|
      \() ->
        Matchers.wasCalledWith [ stringArg "huh", Matchers.anyArg ] (testCalls "test-spy" [ [ StringArg "blah", StringArg "something" ] ])
          |> Expect.equal (Expect.fail <|
            format
              [ message "Expected spy test-spy to have been called with" <| "[ \"huh\"\n, <ANY>\n]"
              , message "but it was called with" "[ \"blah\"\n, \"something\"\n]"
              ])
    ]
  ]

callsTests : Test
callsTests =
  describe "calls"
  [ describe "when the list matcher passes"
    [ test "it makes the calls available to the matcher" <|
      \() ->
        let
          sampleCalls = testCalls "test-spy" [ [ StringArg "blah" ], [ StringArg "what"] ]
        in
          sampleCalls
            |> Matchers.calls (Elmer.hasLength 2)
            |> Expect.equal (Expect.pass)
    ]
  , describe "when the list matcher fails"
    [ test "it prints an error message with the spy name" <|
      \() ->
        let
          sampleCalls = testCalls "test-spy" [ [ StringArg "blah" ], [ StringArg "what"] ]
        in
          sampleCalls
            |> Matchers.calls (Elmer.hasLength 14)
            |> Expect.equal (Expect.fail <|
              format
                [ description "Expectation for test-spy failed."
                , message "Expected list to have size" "14"
                , message "but it has size" "2"
                ])
    ]
  ]

hasArgsTests : Test
hasArgsTests =
  describe "hasArgs"
  [ describe "when the call has the args"
    [ test "it matches " <|
      \() ->
        let
          sampleCalls = testCalls "test-spy" [ [ StringArg "blah" ], [ StringArg "what"] ]
        in
          sampleCalls
            |> Matchers.calls (Elmer.exactly 1 <| Matchers.hasArgs [ StringArg "what" ])
            |> Expect.equal (Expect.pass)
    ]
  , describe "when the call does not have the args"
    [ test "it fails with the message" <|
      \() ->
        let
          sampleCalls = testCalls "test-spy" [ [ StringArg "blah" ], [ StringArg "what"] ]
        in
          sampleCalls
            |> Matchers.calls (Elmer.exactly 1 <| Matchers.hasArgs [ StringArg "something else" ])
            |> Expect.equal (Expect.fail <|
              format
                [ description "Expectation for test-spy failed."
                , description <| format
                  [ description "Expected exactly 1 to pass but found 0. Here are the failures:"
                  , description <| format
                    [ message "Expected spy to have been called with" "[ \"something else\"\n]"
                    , message "but it was called with" "[ \"blah\"\n]"
                    , message "Expected spy to have been called with" "[ \"something else\"\n]"
                    , message "but it was called with" "[ \"what\"\n]"
                    ]
                  ]
                ])
    ]
  ]
