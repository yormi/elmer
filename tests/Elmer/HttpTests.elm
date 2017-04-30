module Elmer.HttpTests exposing (all)

import Test exposing (..)
import Expect
import Http
import Dict
import Elmer
import Html
import Elmer exposing ((<&&>))
import Elmer.ComponentState as ComponentState exposing (ComponentState)
import Elmer.Html.Event as Event
import Elmer.Html.Matchers as Matchers exposing (element, hasText)
import Elmer.Http as ElmerHttp
import Elmer.Http.Stub as HttpStub
import Elmer.Http.Status as Status
import Elmer.Http.Internal as HttpInternal exposing (..)
import Elmer.Http.Matchers exposing (..)
import Elmer.Spy as Spy
import Elmer.Printer exposing (..)
import Elmer.Platform.Command as Command
import Elmer.Html as Markup

import Elmer.TestApps.HttpTestApp as App
import Elmer.TestApps.SimpleTestApp as SimpleApp

all : Test
all =
  describe "Http Tests"
  [ serveTests
  , spyTests
  , requestRecordTests
  , noBodyRequestTests
  , errorResponseTests
  , expectRequestTests "GET" ElmerHttp.expectGET
  , expectRequestTests "POST" ElmerHttp.expectPOST
  , expectRequestTests "PUT" ElmerHttp.expectPUT
  , expectRequestTests "DELETE" ElmerHttp.expectDELETE
  , expectRequestTests "PATCH" ElmerHttp.expectPATCH
  , expectRequestDataTests
  , resolveTests
  , clearRequestsTests
  ]

requestRecordTests : Test
requestRecordTests =
  let
    request = Http.request
      { method = "GET"
      , headers = [ Http.header "x-fun" "fun", Http.header "x-awesome" "awesome" ]
      , url = "http://myapp.com/fun.html"
      , body = Http.stringBody "application/json" "{\"name\":\"cool person\"}"
      , expect = Http.expectString
      , timeout = Nothing
      , withCredentials = False
      }
    httpRequestHandler = HttpInternal.asHttpRequestHandler request
  in
    describe "RequestRecord"
    [ test "it has the method" <|
      \() ->
        Expect.equal httpRequestHandler.request.method "GET"
    , test "it has the url" <|
      \() ->
        Expect.equal httpRequestHandler.request.url "http://myapp.com/fun.html"
    , test "it has the body" <|
      \() ->
        Expect.equal httpRequestHandler.request.body (Just "{\"name\":\"cool person\"}")
    , test "it has the headers" <|
      \() ->
        let
          funHeader = { name = "x-fun", value = "fun" }
          awesomeHeader = { name = "x-awesome", value = "awesome" }
        in
          Expect.equal httpRequestHandler.request.headers [funHeader, awesomeHeader]
    ]

noBodyRequestTests : Test
noBodyRequestTests =
  let
    request = Http.request
      { method = "GET"
      , headers = [ Http.header "x-fun" "fun", Http.header "x-awesome" "awesome" ]
      , url = "http://myapp.com/fun.html"
      , body = Http.emptyBody
      , expect = Http.expectString
      , timeout = Nothing
      , withCredentials = False
      }
    httpRequestHandler = HttpInternal.asHttpRequestHandler request
  in
    describe "No Body RequestRecord"
    [ test "it has Nothing for the body" <|
      \() ->
        Expect.equal httpRequestHandler.request.body Nothing
    ]

serveTests : Test
serveTests =
  describe "serve"
  [ describe "when the requested url is not stubbed"
    [ test "it fails with a message" <|
      \() ->
        let
          stubbedResponse = HttpStub.get "http://wrongUrl.com"
            |> HttpStub.withBody "{\"name\":\"Super Fun Person\",\"type\":\"person\"}"
          anotherStubbedResponse = HttpStub.post "http://whatUrl.com"
            |> HttpStub.withBody "{\"name\":\"Super Fun Person\",\"type\":\"person\"}"
        in
          Elmer.componentState App.defaultModel App.view App.update
            |> Spy.use [ ElmerHttp.serve [ stubbedResponse, anotherStubbedResponse ] ]
            |> Markup.target "#request-data-click"
            |> Event.click
            |> Markup.target "#data-result"
            |> Markup.expect (element <| hasText "Name: Super Fun Person")
            |> Expect.equal (Expect.fail (format
              [ message "Received a request for" "GET http://fun.com/fun.html"
              , message "but it does not match any of the stubbed requests" "POST http://whatUrl.com\nGET http://wrongUrl.com"
              ]
            ))
    ]
  , describe "when the stubbed route contains a query string"
    [ test "it fails with a message" <|
      \() ->
        let
          stubbedResponse = HttpStub.get "http://wrongUrl.com?type=fun"
            |> HttpStub.withBody "{\"name\":\"Super Fun Person\",\"type\":\"person\"}"
        in
          Elmer.componentState App.defaultModel App.view App.update
            |> Spy.use [ ElmerHttp.serve [ stubbedResponse ] ]
            |> Markup.target "#request-data-click"
            |> Event.click
            |> Markup.target "#data-result"
            |> Markup.expect (element <| hasText "Name: Super Fun Person")
            |> Expect.equal (Expect.fail (format
              [ message "Sent a request where a stubbed route contains a query string" "http://wrongUrl.com?type=fun"
              , description "Stubbed routes may not contain a query string"
              ]
            ))
    ]
  , describe "when the requested url matches the stubbed response"
    [ describe "when the method does not match"
      [ test "it fails with a message" <|
        \() ->
          let
            stubbedResponse = HttpStub.post "http://fun.com/fun.html"
              |> HttpStub.withBody "{\"name\":\"Super Fun Person\",\"type\":\"person\"}"
          in
            Elmer.componentState App.defaultModel App.view App.update
              |> Spy.use [ ElmerHttp.serve [ stubbedResponse ] ]
              |> Markup.target "#request-data-click"
              |> Event.click
              |> Markup.target "#data-result"
              |> Markup.expect (element <| hasText "Name: Super Fun Person")
              |> Expect.equal (Expect.fail (format
                [ message "Received a request for" "GET http://fun.com/fun.html"
                , message "but it does not match any of the stubbed requests" "POST http://fun.com/fun.html"
                ]
              ))
      ]
    , describe "when the method matches"
      [ describe "when the response status is outside the 200 range"
        [ test "it sends a BadStatus message" <|
          \() ->
            let
              stubbedResponse = HttpStub.get "http://fun.com/fun.html"
                |> HttpStub.withStatus Status.notFound
            in
              Elmer.componentState App.defaultModel App.view App.update
                |> Spy.use [ ElmerHttp.serve [ stubbedResponse ] ]
                |> Markup.target "#request-data-click"
                |> Event.click
                |> Markup.target "#data-result"
                |> Markup.expect (element <| hasText "BadStatus Error: 404 Not Found")
        ]
      , describe "when the response status is in the 200 range"
        [ describe "when the response body cannot be processed"
          [ test "it fails with a message" <|
            \() ->
              let
                stubbedResponse = HttpStub.get "http://fun.com/fun.html"
                  |> HttpStub.withBody "{}"
              in
                Elmer.componentState App.defaultModel App.view App.update
                  |> Spy.use [ ElmerHttp.serve [ stubbedResponse ] ]
                  |> Markup.target "#request-data-click"
                  |> Event.click
                  |> Markup.target "#data-result"
                  |> Markup.expect (element <| hasText "Name: Super Fun Person")
                  |> Expect.equal (Expect.fail (format
                    [ message "Parsing a stubbed response" "GET http://fun.com/fun.html"
                    , description ("\t{}")
                    , message "failed with error" "Expecting an object with a field named `name` but instead got: {}"
                    , description "If you really want to generate a BadPayload error, consider using\nElmer.Http.Stub.withError to build your stubbed response."
                    ]
                  ))
          ]
        , describe "when the requested url has a query string"
          [ test "it matches the stubbed path" <|
            \() ->
              let
                defaultModel = App.defaultModel
                stubbedResponse = HttpStub.get "http://fun.com/fun.html"
                  |> HttpStub.withBody "{\"name\":\"awesome things\"}"
                testModel = { defaultModel | query = "?type=awesome" }
              in
                Elmer.componentState testModel App.view App.update
                  |> Spy.use [ ElmerHttp.serve [ stubbedResponse ] ]
                  |> Markup.target "#request-data-click"
                  |> Event.click
                  |> Markup.target "#data-result"
                  |> Markup.expect (element <| hasText "awesome things")
                  |> Expect.equal Expect.pass
          ]
        , describe "when the response body can be processed"
          [ test "it decodes the response" <|
            \() ->
              let
                stubbedResponse = HttpStub.get "http://fun.com/fun.html"
                  |> HttpStub.withBody "{\"name\":\"Super Fun Person\",\"type\":\"person\"}"
              in
                Elmer.componentState App.defaultModel App.view App.update
                  |> Spy.use [ ElmerHttp.serve [ stubbedResponse ] ]
                  |> Markup.target "#request-data-click"
                  |> Event.click
                  |> Markup.target "#data-result"
                  |> Markup.expect (element <| hasText "Super Fun Person")
                  |> Expect.equal Expect.pass
          ]
        , let
            stubbedResponse = HttpStub.get "http://fun.com/fun.html"
              |> HttpStub.withBody "{\"name\":\"Super Fun Person\",\"type\":\"person\"}"
            otherStub = HttpStub.get "http://fun.com/super.html"
              |> HttpStub.withBody "{\"message\":\"This is great!\"}"
            state = Elmer.componentState App.defaultModel App.view App.update
              |> Spy.use [ ElmerHttp.serve [ stubbedResponse, otherStub ] ]
              |> Markup.target "#request-data-click"
              |> Event.click
              |> Markup.target "#request-other-data-click"
              |> Event.click
          in
            describe "when multiple stubs are provided"
            [ test "it decodes the response for one stub" <|
              \() ->
                Markup.target "#data-result" state
                  |> Markup.expect (element <| hasText "Super Fun Person")
            , test "it decodes the response for the other stub" <|
              \() ->
                Markup.target "#other-data-result" state
                  |> Markup.expect (element <| hasText "This is great!")
            ]
        ]
      ]
    ]
  ]

spyTests : Test
spyTests =
  let
    requestedState = Elmer.componentState App.defaultModel App.view App.update
      |> Spy.use [ ElmerHttp.spy ]
      |> Markup.target "#request-data-click"
      |> Event.click
  in
    describe "spy"
    [ test "it records any request" <|
      \() ->
        ElmerHttp.expectGET "http://fun.com/fun.html" wasSent requestedState
    , test "it is as if the response never returned" <|
      \() ->
        Markup.target "#data-result" requestedState
          |> Markup.expect (element <| hasText "")
          |> Expect.equal Expect.pass
    ]

errorResponseTests : Test
errorResponseTests =
  describe "when the request should result in an Http.Error"
  [ test "it returns the error" <|
    \() ->
      let
        stubbedResponse = HttpStub.get "http://fun.com/fun.html"
          |> HttpStub.withError Http.Timeout
      in
        Elmer.componentState App.defaultModel App.view App.update
          |> Spy.use [ ElmerHttp.serve [ stubbedResponse ] ]
          |> Markup.target "#request-data-click"
          |> Event.click
          |> Markup.target "#data-result"
          |> Markup.expect (element <| hasText "Timeout Error")
  ]


componentStateWithRequests : List HttpRequest -> ComponentState SimpleApp.Model SimpleApp.Msg
componentStateWithRequests requestData =
  let
    defaultState = Elmer.componentState SimpleApp.defaultModel SimpleApp.view SimpleApp.update
  in
    defaultState
      |> ComponentState.map (\component -> ComponentState.with { component | httpRequests = requestData })

testRequest : String -> String -> HttpRequest
testRequest method url =
  { method = method
  , url = url
  , body = Nothing
  , headers = []
  }

expectRequestTests : String -> (String -> (HttpRequest -> Expect.Expectation) -> ComponentState SimpleApp.Model SimpleApp.Msg -> Expect.Expectation) -> Test
expectRequestTests method func =
  describe ("expect" ++ method)
  [ describe "when there is an upstream error"
    [ test "it fails with the upstream error" <|
      \() ->
        func "http://fun.com/fun" wasSent (ComponentState.failure "Failed!")
          |> Expect.equal (Expect.fail "Failed!")
    ]
  , describe "when the expected route contains a query string"
    [ test "it fails with an error" <|
      \() ->
        let
          initialState = componentStateWithRequests []
        in
          func "http://fun.com/fun?type=amazing" wasSent initialState
            |> Expect.equal (Expect.fail (format
              [ message "The expected route contains a query string" "http://fun.com/fun?type=amazing"
              , description "Use the hasQueryParam matcher instead"
              ]
            ))
    ]
  , describe "when no requests have been recorded"
    [ test "it fails" <|
      \() ->
        let
          initialState = componentStateWithRequests []
        in
          func "http://fun.com/fun" wasSent initialState
            |> Expect.equal (Expect.fail (format
              [ message "Expected request for" (method ++ " http://fun.com/fun")
              , description "but no requests have been made"
              ]
            ))
    ]
  , describe "when requests have been recorded"
    [ describe "when the url does not match any requests"
      [ test "it fails" <|
        \() ->
          let
            request1 = testRequest "POST" "http://fun.com/fun"
            request2 = testRequest "GET" "http://awesome.com/awesome.html?stuff=fun"
            initialState = componentStateWithRequests [ request1, request2 ]
          in
            func "http://fun.com/awesome" wasSent initialState
              |> Expect.equal (Expect.fail (format
                [ message "Expected request for" (method ++ " http://fun.com/awesome")
                , message "but only found these requests" "POST http://fun.com/fun\nGET http://awesome.com/awesome.html?stuff=fun"
                ]
              ))
      ]
    , describe "when the url matches but not the method"
      [ test "it fails" <|
        \() ->
          let
            request1 = testRequest "OTHER_METHOD" "http://fun.com/fun"
            initialState = componentStateWithRequests [ request1 ]
          in
            func "http://fun.com/fun" wasSent initialState
              |> Expect.equal (Expect.fail (format
                [ message "Expected request for" (method ++ " http://fun.com/fun")
                , message "but only found these requests" "OTHER_METHOD http://fun.com/fun"
                ]
              ))
      ]
    , describe "when a matching request occurs"
      [ describe "when the request expectations fail"
        [ test "it fails" <|
          \() ->
            let
              request1 = testRequest method "http://fun.com/fun.html"
              initialState = componentStateWithRequests [ request1 ]
              failRequest = (\_ -> Expect.fail "It failed!")
            in
              func "http://fun.com/fun.html" failRequest initialState
                |> Expect.equal (Expect.fail "It failed!")
        ]
      , describe "when the request expectations pass"
        [ test "it passes" <|
          \() ->
            let
              request1 = testRequest method "http://fun.com/fun.html"
              initialState = componentStateWithRequests [ request1 ]
            in
              func "http://fun.com/fun.html" wasSent initialState
                |> Expect.equal (Expect.pass)
        , describe "when the request has a query string"
          [ test "it passes" <|
            \() ->
              let
                request1 = testRequest method "http://awesome.com/awesome.html?stuff=fun"
                initialState = componentStateWithRequests [ request1 ]
              in
                func "http://awesome.com/awesome.html" (hasQueryParam ("stuff", "fun")) initialState
                  |> Expect.equal (Expect.pass)
          ]
        ]
      ]
    ]
  ]

expectRequestDataTests : Test
expectRequestDataTests =
  describe "Request Data Tests"
  [ test "it finds the headers" <|
    \() ->
      Elmer.componentState App.defaultModel App.view App.update
        |> Spy.use [ ElmerHttp.spy ]
        |> Markup.target "#request-data-click"
        |> Event.click
        |> ElmerHttp.expectGET "http://fun.com/fun.html" (
          hasHeader ("x-fun", "fun") <&&>
          hasHeader ("x-awesome", "awesome")
        )
  ]

resolveTests : Test
resolveTests =
  let
    stubbedResponse = HttpStub.get "http://fun.com/fun.html"
      |> HttpStub.withBody "{\"name\":\"Cool Dude\"}"
      |> HttpStub.deferResponse
    requestedState = Elmer.componentState App.defaultModel App.view App.update
      |> Spy.use [ ElmerHttp.serve [ stubbedResponse ] ]
      |> Markup.target "#request-data-click"
      |> Event.click
  in
    describe "when there is no upstream failure"
    [ describe "before resolve is called"
      [ test "it records the request" <|
        \() ->
          ElmerHttp.expectGET "http://fun.com/fun.html" wasSent requestedState
      , test "it does not yet resolve the response" <|
        \() ->
          Markup.target "#data-result" requestedState
            |> Markup.expect (element <| hasText "")
      ]
    , describe "when resolve is called"
      [ test "it resolves the response" <|
        \() ->
          Command.resolveDeferred requestedState
            |> Markup.target "#data-result"
            |> Markup.expect (element <| hasText "Cool Dude")
      ]
    ]

clearRequestsTests : Test
clearRequestsTests =
  describe "clear"
  [ describe "when there is an upstream failure"
    [ test "it shows the failure" <|
      \() ->
        let
          result = ElmerHttp.clearRequestHistory (ComponentState.failure "You Failed!")
        in
          Expect.equal (ComponentState.failure "You Failed!") result
    ]
  , describe "when there are no requests to clear"
    [ test "it fails" <|
      \() ->
        let
          initialState = componentStateWithRequests []
        in
          ElmerHttp.clearRequestHistory initialState
            |> Expect.equal (ComponentState.failure "No HTTP requests to clear")
    ]
  , describe "when there are requests to clear"
    [ test "it clears the requests" <|
      \() ->
        let
          request1 = testRequest "POST" "http://fun.com/fun"
          request2 = testRequest "GET" "http://awesome.com/awesome.html?stuff=fun"
          initialState = componentStateWithRequests [ request1, request2 ]
        in
          ElmerHttp.clearRequestHistory initialState
            |> ComponentState.mapToExpectation (\component ->
              Expect.equal True (List.isEmpty component.httpRequests)
            )
    ]
  ]
