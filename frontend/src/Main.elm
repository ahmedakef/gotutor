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
import Url.Parser as Parser exposing ((<?>), (</>), Parser )
import Url.Parser.Query as Query
import Tailwind.Theme as Tw
import Tailwind.Utilities as Tw


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


routeParser : Parser (Steps.Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Steps.Home (Parser.top <?> Query.string "id")
        , Parser.map Steps.Home (Parser.s "src" </> Parser.s "index.html" <?> Query.string "id") -- for local development
        ]


type alias Model =
    { env : Common.Env
    , key : Nav.Key
    , url : Url.Url
    , state : Steps.State
    , route : Steps.Route
    }



-- Init


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        route =
            Parser.parse routeParser url
                |> Maybe.withDefault (Steps.Home Nothing)

        ( stepsState, stepsCmd ) =
            Steps.init route

        initialModel =
            Model Common.Prod key url stepsState route
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
            let
                newRoute =
                    Parser.parse routeParser url
                        |> Maybe.withDefault (Steps.Home Nothing)
            in
            ( { model | url = url, route = newRoute }
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
            "GoTutor | Online Go Debugger & Visualizer"

        body =
            div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.minHeight (Css.vh 100) ] ]
                [ Styles.globalStyles
                , navigation
                , heading
                , Html.map StepsMsg (StepsView.view model.state)
                , feedback
                , palastineSupport
                , pageFooter
                ]
    in
    { title = title
    , body = [ toUnstyled body ]
    }


navigation : Html msg
navigation =
    nav
        [ css
            [ Tw.flex , Tw.justify_center , Tw.items_center , Tw.w_full
            , Css.borderBottom2 (Css.px 1) Css.solid
            , Tw.border_b_color Tw.gray_300
            , Tw.text_xl
            ]
        ]
        [ div [ css [ Tw.flex_1, Tw.pl_4 ] ]
            [ img [ height 27, src "static/logo.svg", alt "github logo" ] []
            ]
        , ul [ css [ Tw.my_0, Tw.list_none, Tw.flex, Tw.items_center, Css.flex (Css.num 2), Tw.gap_5 ] ]
            [
                li [ css [ navBarItemsStyle ] ] [ viewLink "About" "#about" "_self" ]
                , li [ css [ navBarItemsStyle ] ] [ viewLink "Github" "https://github.com/ahmedakef/gotutor" "_blank" ]
                , li [ ] [ githubSponsorsButton ]
                , li [ ] [ koFiButton ]
            ]
        ]

heading : Html msg
heading =
    header [ css [ Tw.flex, Css.flexDirection Css.column, Tw.items_center, Css.flex (Css.num 1), Tw.pt_4, Tw.pb_4 ] ]
        [ div [ css [ Tw.flex, Tw.items_center ] ]
            [ img [ height 70, src "static/gopher.png", alt "github logo" ] []
            , h1 [ css [ Tw.text_2xl, Tw.font_bold ] ] [ text "Online Go Debugger & Visualizer" ]
            ]
        , p [] [ text "It shows the state of all the running Goroutines, the state of each stack frame and can go back in time." ]
        ]


feedback : Html msg
feedback =
    div [ css [ Tw.flex, Tw.justify_center, Tw.mt_5 ] ]
        [
            p [] [ text "Your feedback matters, please share your thoughts and suggestions" ]
            , a [css [ Tw.ml_1] , href "https://github.com/ahmedakef/gotutor/issues", target "_blank" ]
                [ p [] [ text "on GitHub" ]]
        ]


palastineSupport : Html msg
palastineSupport =
    div [ css [ Tw.flex, Tw.justify_center, Tw.mt_5 ] ]
        [ a [ href "https://humanappeal.org.uk/appeals/gaza-emergency-appeal", target "_blank" ]
            [ img [ src "https://raw.githubusercontent.com/Safouene1/support-palestine-banner/master/banner-support.svg", alt "palastine logo" ] []
            ]
        ]

pageFooter : Html msg
pageFooter =
    footer
        [ id "about"
        , css
            [ Css.displayFlex
            , Css.width (Css.pct 100)
            , Tw.border_t
            , Tw.border_t_color Tw.gray_300
            , Css.borderTopStyle Css.solid
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
            [ text "GoTutor is an online Go debugger & visualizer that shows the shows the program's execution steps."
            , br [] []
            , text "It's very welcome to help by contributing to the project or suggesting ideas."
            , br [] []
            , text "The project only follows the main Goroutine now as described in "
            , a [ href "https://github.com/ahmedakef/gotutor?tab=readme-ov-file#limitations", target "_blank", css [ Css.textDecoration Css.none ] ] [ text "Limitations" ]
            , text "."
            , br [] []
            , text "Copyright © 2024 by "
            , a [ href "https://www.linkedin.com/in/ahmedakef4/", target "_blank", css [ Css.textDecoration Css.none ] ] [ text "Ahmed Akef" ]
            , text "."
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
        [ img [ height 25, src "static/github-mark.svg", alt "github logo" ] []
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


navBarItemsStyle : Css.Style
navBarItemsStyle =
    Css.batch
        [
            Tw.p_2
            , Css.hover [ Tw.bg_color Tw.gray_100 ]
        ]


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
