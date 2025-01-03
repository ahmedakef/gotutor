module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Helpers.Http as HttpHelper
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)
import Steps.Steps as Steps
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


type State
    = Success (List Steps.Step)
    | Failure String
    | Loading


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , state : State
    }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( Model key url Loading, Steps.getSteps StepsMsg )



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
            case stepsMsg of
                Steps.GotSteps (Ok steps) ->
                    ( { model | state = Success steps }, Cmd.none )

                Steps.GotSteps (Err err) ->
                    ( { model | state = Failure (err |> HttpHelper.errorToString) }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view _ =
    let
        title =
            "URL Interceptor"

        body =
            div []
                [ Styles.horizontalUL
                    [ viewLink "/home"
                    , viewLink "/about"
                    ]
                ]
    in
    { title = title
    , body = [ toUnstyled body ]
    }


viewLink : String -> Html msg
viewLink path =
    a [ href path ] [ text path ]
