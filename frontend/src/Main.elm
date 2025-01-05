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
    let
        initialModel =
            Model key url Steps.Loading

        getSteps =
            Cmd.map StepsMsg Steps.getSteps

        getSourceCode =
            Cmd.map StepsMsg Steps.getSourceCode

        combinedCmd =
            Cmd.batch [ getSteps, getSourceCode ]
    in
    ( initialModel, combinedCmd )



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
                ( state, cmd ) =
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
            "Go tutor"

        body =
            div []
                [ Styles.globalStyles
                , inlineCss Styles.requiredShStyles
                , navigation
                , Html.map StepsMsg (StepsView.view model.state)
                ]
    in
    { title = title
    , body = [ toUnstyled body ]
    }


navigation : Html msg
navigation =
    div [ css [ Styles.container, Styles.flexCenter ] ]
        [ horizontalUL
            [ viewLink "home"
            , viewLink "about"
            ]
        ]


horizontalUL : List (Html msg) -> Html msg
horizontalUL items =
    ul [ css [ Styles.horizontalUlStyle ] ]
        (List.map (\item -> li [ css [ Styles.horizontalLiStyle ] ] [ item ]) items)


viewLink : String -> Html msg
viewLink path =
    a [ href ("/" ++ path), css [ Styles.navItems ] ] [ text path ]


inlineCss : String -> Html msg
inlineCss inlineRawCss =
    node "style" [] [ text inlineRawCss ]
