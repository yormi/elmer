module Elmer.TestApps.SimpleSpyTestApp exposing (..)

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events


type alias Model =
    Bool


type Msg
    = IsSpy Bool


defaultModel : Model
defaultModel =
    False


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.button
            [ Attr.id "spy-finder-button"
            , Events.onClick (isASpy False)
            ]
            [ Html.text "Find out if he's a traitor" ]
        , Html.p [] [ Html.text <| toString model ]
        ]


isASpy : Bool -> Msg
isASpy =
    IsSpy


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IsSpy bool ->
            updateTraitorState bool


updateTraitorState : Bool -> ( Model, Cmd Msg )
updateTraitorState bool =
    ( bool, Cmd.none )
