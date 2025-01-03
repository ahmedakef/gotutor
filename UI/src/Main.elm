module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)
import Steps.Steps as Steps
import Steps.View as StepsView
import Styles
import Url



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL





type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , state : Steps.State
    }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( Model key url Steps.Loading, Steps.getSteps StepsMsg )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | StepsMsg Steps.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )

        StepsMsg stepsMsg ->
            let
                (state, cmd) =
                    Steps.update stepsMsg model.state
            in
            ( { model | state = state }, Cmd.map StepsMsg cmd )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        title =
            "URL Interceptor"

        body =
            div []
                [ Styles.globalStyles
                , navigation
                , StepsView.view model.state
                ]
    in
    { title = title
    , body = [ toUnstyled body ]
    }

-- Apply the global styles

viewLink : String -> Html msg
viewLink path =
    a [ href path ] [ text path ]


navigation : Html msg
navigation =
    Styles.horizontalUL
        [ viewLink "/home"
        , viewLink "/about"
        ]
