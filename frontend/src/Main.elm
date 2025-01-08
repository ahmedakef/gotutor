module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Css
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
            div [ css [ Styles.container, Styles.flexCenter, Css.minHeight (Css.vh 100) ] ]
                [ Styles.globalStyles
                , inlineCss Styles.requiredShStyles
                , navigation
                , Html.map StepsMsg (StepsView.view model.state)
                , pageFooter
                ]
    in
    { title = title
    , body = [ toUnstyled body ]
    }


navigation : Html msg
navigation =
    header [ css [ Styles.container, Css.width (Css.pct 100), Styles.flexCenter, Css.borderBottom3 (Css.px 1) Css.solid (Css.hex "ddd") ] ]
        [ horizontalUL
            [ viewLink "About" "#about" "_self"
            , viewLink "Github" "https://github.com/ahmedakef/gotutor" "_blank"
            ]
        ]


pageFooter : Html msg
pageFooter =
    footer
        [ id "about"
        , css [ Css.width (Css.pct 100) ]
        ]
        [ div
            [ css
                [ Css.borderTop3
                    (Css.px 1)
                    Css.solid
                    (Css.hex "ddd")
                , Css.paddingTop (Css.px 20)
                , Css.paddingLeft (Css.px 20)
                , Css.paddingBottom (Css.px 10)
                ]
            ]
            [ text "Gotutor is a trial to show program execution steps."
            , br [] []
            , text "It's very welcomed to help by contributing to the project."
            , br [] []
            , text "the project only shows the main Goroutine now as descriped in "
            , a [ href "https://github.com/ahmedakef/gotutor?tab=readme-ov-file#limitations", css [ Css.textDecoration Css.none ] ] [ text "Limitations" ]
            , text "."
            , br [] []
            , text "copyright © 2024 by "
            , a [ href "https://www.linkedin.com/in/ahmedakef4/", css [ Css.textDecoration Css.none ] ] [ text "Ahmed Akef" ]
            , text "."
            ]
        ]


horizontalUL : List (Html msg) -> Html msg
horizontalUL items =
    ul [ css [ Styles.horizontalUlStyle ] ]
        (List.map (\item -> li [ css [ Styles.horizontalLiStyle ] ] [ item ]) items)


viewLink : String -> String -> String -> Html msg
viewLink content link targetPage =
    a
        [ href link
        , target targetPage
        , css [ Styles.navItems ]
        ]
        [ text content
        ]


inlineCss : String -> Html msg
inlineCss inlineRawCss =
    node "style" [] [ text inlineRawCss ]
