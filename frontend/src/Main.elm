module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Css
import Helpers.Common as Common
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
    { env : Common.Env
    , key : Nav.Key
    , url : Url.Url
    , state : Steps.State
    }



-- Init


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        ( stepsState, stepsCmd ) =
            Steps.init

        initialModel =
            Model Common.Prod key url stepsState
    in
    ( initialModel, Cmd.map StepsMsg stepsCmd )



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
                    Steps.update stepsMsg model.state model.env
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
            div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.minHeight (Css.vh 100) ] ]
                [ Styles.globalStyles
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
    header [ css [ Css.displayFlex, Css.width (Css.pct 100), Css.flexDirection Css.column, Css.alignItems Css.center, Css.borderBottom3 (Css.px 1) Css.solid (Css.hex "ddd") ] ]
        [ horizontalUL
            [ viewLink "About" "#about" "_self"
            , viewLink "Github" "https://github.com/ahmedakef/gotutor" "_blank"
            ]
        ]


pageFooter : Html msg
pageFooter =
    footer
        [ id "about"
        , css
            [ Css.displayFlex
            , Css.width (Css.pct 100)
            , Css.borderTop3
                (Css.px 1)
                Css.solid
                (Css.hex "ddd")
            ]
        ]
        [ div
            [ css
                [ Css.flex (Css.num 1)
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
        , div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.property "justify-content" "space-evenly", Css.alignItems Css.center, Css.flex (Css.num 1) ] ]
            [ githubSponsorsButton
            , koFiButton
            ]
        ]


githubSponsorsButton : Html msg
githubSponsorsButton =
    a
        [ href "https://github.com/sponsors/ahmedakef"
        , target "_blank"
        , css
            [ Css.displayFlex
            , Css.alignItems Css.center
            , Css.padding2 (Css.px 5) (Css.px 5)
            , Css.textDecoration Css.none
            , Css.fontSize (Css.px 12)
            , Css.backgroundColor (Css.hex "f6f8fa")
            , Css.borderRadius (Css.rem 0.375)
            , Css.border3 (Css.rem 0.0625) Css.solid (Css.hex "d1d9e0")
            , Css.hover [ Css.backgroundColor (Css.hex "e6eaef") ]
            ]
        ]
        [ img [ height 25, src "github-mark.svg", alt "github logo" ] []
        , span [ css [ Css.marginLeft (Css.px 10), Css.color (Css.hex "25292e") ] ] [ text "Sponsor Me on GitHub" ]
        ]


koFiButton : Html msg
koFiButton =
    a [ href "https://ko-fi.com/M4M319RW5Y", target "_blank" ]
        [ img
            [ height 36
            , css [ Css.border (Css.px 0), Css.height (Css.px 36) ]
            , src "https://storage.ko-fi.com/cdn/kofi6.png?v=6"
            , alt "Buy Me a Coffee at ko-fi.com"
            ]
            []
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
