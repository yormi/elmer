module Elmer.HtmlMapTest exposing (..)

import Html exposing (..)
import Html.Events as E
import Test exposing (..)
import Elmer exposing (TestState, (<&&>))
import Elmer.Html as Html
import Elmer.Html.Matchers as HtmlM
import Elmer.Html.Event as Event


type alias Model =
    String


initialState : Model
initialState =
    "Failed"


type ParentMsg
    = ParentMsg MiddleMsg


type MiddleMsg
    = MiddleMsg ChildMsg


type ChildMsg
    = ChildMsg String


parentUpdate : ParentMsg -> Model -> ( Model, Cmd ParentMsg )
parentUpdate msg model =
    case msg of
        ParentMsg middleMsg ->
            middleUpdate middleMsg model


middleUpdate : MiddleMsg -> Model -> ( Model, Cmd ParentMsg )
middleUpdate msg model =
    case msg of
        MiddleMsg childMsg ->
            childUpdate childMsg model ! []


childUpdate : ChildMsg -> Model -> Model
childUpdate msg model =
    case msg of
        ChildMsg str ->
            str


parentView : Model -> Html ParentMsg
parentView model =
    div [] [ Html.map ParentMsg (middleView model) ]


middleView : Model -> Html MiddleMsg
middleView model =
    div [] [ Html.map MiddleMsg (childView model) ]


expectedText : String
expectedText =
    "Success"


childView : Model -> Html ChildMsg
childView model =
    button
        [ E.onClick <| ChildMsg expectedText ]
        [ text model ]


app : TestState Model ParentMsg
app =
    Elmer.given initialState parentView parentUpdate


htmlMapTest : Test
htmlMapTest =
    only <|
        describe "When using nested Html.map"
            [ test "Correct Msg is sent to update function" <|
                \_ ->
                    let
                        expected =
                            HtmlM.element <|
                                HtmlM.hasText expectedText
                    in
                        app
                            |> Html.target "button"
                            |> Event.click
                            |> Html.expect expected
            , test "No problem for the second event" <|
                \_ ->
                    let
                        expected =
                            HtmlM.element <|
                                HtmlM.hasText expectedText
                    in
                        app
                            |> Html.target "button"
                            |> Event.click
                            |> Html.target "button"
                            |> Event.click
                            |> Html.expect expected
            ]
