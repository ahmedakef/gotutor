port module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Css
import Helpers.Common as Common
import Helpers.Http as HttpHelper
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick, preventDefaultOn)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Steps.Steps as Steps
import Steps.View as StepsView
import Styles
import Url
import Url.Parser as Parser exposing ((<?>), (</>), Parser )
import Url.Parser.Query as Query
import Tailwind.Theme as Tw
import Tailwind.Utilities as Tw


-- PORTS


port setLocalStorageWithValue : { key : String, value : String } -> Cmd msg
port getLocalStorage : String -> Cmd msg
port getCurrentTime : () -> Cmd msg
port localStorageReceived : (String -> msg) -> Sub msg
port currentTimeReceived : (Float -> msg) -> Sub msg


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
    , showFeedbackDialog : Bool
    , currentTime : Maybe Float
    , subscriptionStatus : Maybe (Result String String)
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
            Model Common.Prod key url stepsState route False Nothing Nothing
    in
    ( initialModel, Cmd.batch [ Cmd.map StepsMsg stepsCmd, getLocalStorage "feedbackDialogDismissed2", getCurrentTime () ] )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | StepsMsg Steps.Msg
    | DismissFeedbackDialogTemporary
    | DismissFeedbackDialogPermanent
    | LocalStorageReceived String
    | CurrentTimeReceived Float
    | SubmitSubscription String
    | GotSubscriptionResponse (Result String SubscriptionResponse)


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

        DismissFeedbackDialogTemporary ->
            case model.currentTime of
                Just currentTime ->
                    let
                        timestampValue = "temporary:" ++ String.fromFloat currentTime
                    in
                    ( { model | showFeedbackDialog = False }, setLocalStorageWithValue { key = "feedbackDialogDismissed2", value = timestampValue } )
                Nothing ->
                    ( { model | showFeedbackDialog = False }, getCurrentTime () )

        DismissFeedbackDialogPermanent ->
            ( { model | showFeedbackDialog = False }, setLocalStorageWithValue { key = "feedbackDialogDismissed2", value = "permanent" } )

        CurrentTimeReceived time ->
            let
                updatedModel = { model | currentTime = Just time }
            in
            -- If we were waiting for time to dismiss temporarily, do it now
            if not model.showFeedbackDialog then
                ( updatedModel, Cmd.none )
            else
                ( updatedModel, Cmd.none )

        LocalStorageReceived value ->
            if value == "permanent" then
                ( { model | showFeedbackDialog = False }, Cmd.none )
            else if String.startsWith "temporary:" value then
                -- Check if 7 days have passed since temporary dismissal
                case model.currentTime of
                    Just currentTime ->
                        let
                            timestampStr = String.dropLeft 10 value -- Remove "temporary:" prefix
                            dismissTime = String.toFloat timestampStr |> Maybe.withDefault 0
                            sevenDaysInMs = 7 * 24 * 60 * 60 * 1000
                        in
                        if (currentTime - dismissTime) > sevenDaysInMs then
                            ( model, Cmd.none ) -- Show dialog again
                        else
                            ( { model | showFeedbackDialog = False }, Cmd.none ) -- Keep hidden
                    Nothing ->
                        ( model, getCurrentTime () ) -- Get current time first
            else
                ( { model | showFeedbackDialog = True }, Cmd.none ) -- First time visitor, show dialog

        SubmitSubscription email ->
            let
                trimmedEmail = String.trim email
            in
            if String.isEmpty trimmedEmail then
                ( model, Cmd.none )
            else
                ( model, submitEmailSubscription trimmedEmail model.env )

        GotSubscriptionResponse result ->
            case result of
                Ok response ->
                    ( { model | subscriptionStatus = Just (Ok response.message) }, Cmd.none )
                Err err ->
                    ( { model | subscriptionStatus = Just (Err err) }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ localStorageReceived LocalStorageReceived
        , currentTimeReceived CurrentTimeReceived
        ]


-- HTTP


backendUrl : Common.Env -> String
backendUrl env =
    case env of
        Common.Dev ->
            "http://localhost:8080"

        Common.Prod ->
            "https://backend.gotutor.dev"


type alias SubscriptionResponse =
    { message : String
    }


submitEmailSubscription : String -> Common.Env -> Cmd Msg
submitEmailSubscription email env =
    Http.request
        { method = "POST"
        , headers = []
        , url = backendUrl env ++ "/subscribe-email"
        , body = Http.jsonBody (Encode.object [ ( "email", Encode.string email ) ])
        , expect = HttpHelper.expectJson GotSubscriptionResponse subscriptionResponseDecoder
        , timeout = Just (60 * 1000) -- ms
        , tracker = Nothing
        }


subscriptionResponseDecoder : Decode.Decoder SubscriptionResponse
subscriptionResponseDecoder =
    Decode.map SubscriptionResponse
        (Decode.field "message" Decode.string)



-- VIEW


feedbackDialog : Model -> Html Msg
feedbackDialog model =
    div
        [ css
            [ Tw.fixed
            , Tw.inset_0
            , Tw.bg_color Tw.black
            , Css.backgroundColor (Css.rgba 0 0 0 0.5)
            , Tw.flex
            , Tw.items_center
            , Tw.justify_center
            , Tw.z_50
            ]
        ]
        [ div
            [ css
                [ Tw.bg_color Tw.white
                , Tw.rounded_lg
                , Tw.p_6
                , Tw.max_w_md
                , Tw.mx_4
                , Css.boxShadow5 (Css.px 0) (Css.px 10) (Css.px 25) (Css.px 0) (Css.rgba 0 0 0 0.1)
                ]
            ]
            [ div [ css [ Tw.flex, Tw.items_center, Tw.justify_between, Tw.mb_4 ] ]
                [ div [ css [ Tw.flex, Tw.items_center ] ]
                    [ img [ src "static/gopher.png", height 40, css [ Tw.mr_3 ] ] []
                    , h2 [ css [ Tw.text_xl, Tw.font_semibold, Tw.m_0 ] ]
                        [ text "Welcome to GoTutor!" ]
                    ]
                , button
                    [ onClick DismissFeedbackDialogTemporary
                    , css
                        [ Tw.p_2
                        , Tw.border_0
                        , Tw.bg_color Tw.transparent
                        , Tw.text_color Tw.gray_500
                        , Tw.cursor_pointer
                        , Css.hover [ Tw.text_color Tw.gray_700 ]
                        , Tw.text_xl
                        , Tw.leading_none
                        ]
                    ]
                    [ text "×" ]
                ]
                , subscriptionForm model
            , p [ css [ Tw.mb_5, Css.lineHeight (Css.num 1.5), Tw.text_color Tw.gray_700 ] ]
                [ text "Thank you for trying GoTutor! I'm currently running this project on AWS free tier and need your support to keep it alive. "
                , text "Without community backing, the project may need to be closed. Please consider giving a star on GitHub and supporting the project!"
                ]
            , div [ css [ Tw.flex, Tw.justify_between, Tw.items_center ] ]
                [
                 div [ css [ Tw.flex, Tw.gap_3 ] ]
                    [ a
                        [ href "https://github.com/ahmedakef/gotutor"
                        , target "_blank"
                        , onClick DismissFeedbackDialogPermanent
                        , css
                            [ Tw.px_4
                            , Tw.py_2
                            , Tw.border_0
                            , Tw.rounded
                            , Tw.bg_color Tw.blue_600
                            , Tw.text_color Tw.white
                            , Css.textDecoration Css.none
                            , Tw.cursor_pointer
                            , Css.hover [ Tw.bg_color Tw.blue_700 ]
                            , Tw.transition_colors
                            , Tw.flex
                            , Tw.items_center
                            , Tw.gap_2
                            ]
                        ]
                        [ img [ src "static/github-mark.svg", height 16, css [ Tw.mr_2 ] ] []
                        , text "Give a Star on GitHub"
                        ]
                    ]
                , koFiButton
                ]
            ]
        ]


view : Model -> Browser.Document Msg
view model =
    let
        title =
            "GoTutor | Online Go Debugger & Visualizer"

        body =
            div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.minHeight (Css.vh 100) ] ]
                ([ Styles.globalStyles
                , navigation
                , heading
                , feedback
                , Html.map StepsMsg (StepsView.view model.state)
                , palastineSupport
                , pageFooter model
                ] ++ (if model.showFeedbackDialog then [ feedbackDialog model ] else []))
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
    header [ css [ Tw.flex, Css.flexDirection Css.column, Tw.items_center, Css.flex (Css.num 1), Tw.mt_2, Tw.mb_2 ] ]
        [ div [ css [ Tw.flex, Tw.items_center ] ]
            [ img [ height 70, src "static/gopher.png", alt "github logo" ] []
            , h1 [ css [ Tw.text_2xl, Tw.font_bold ] ] [ text "Online Go Debugger & Visualizer" ]
            ]
        , p [] [ text "It shows the state of all the running Goroutines, the state of each stack frame and can go back in time." ]
        ]


feedback : Html msg
feedback =
    div [ css [ Tw.flex, Tw.ml_10, Tw.text_2xl ] ]
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

pageFooter : Model -> Html Msg
pageFooter model =
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
        , div
            [ css
                [ Css.flex (Css.num 1)
                , Css.paddingTop (Css.px 20)
                , Css.paddingRight (Css.px 20)
                , Css.paddingBottom (Css.px 10)
                , Css.maxWidth (Css.px 400)
                ]
            ]
            [ subscriptionForm model
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

subscriptionForm : Model -> Html Msg
subscriptionForm model =
    Html.form
        [ preventDefaultOn "submit" (Decode.map (\email -> (SubmitSubscription email, True)) (Decode.at ["target", "email", "value"] Decode.string))
        , css [ Tw.mb_4 ]
        ]
        [ label [ css [ Tw.block, Tw.text_sm, Tw.font_medium, Tw.mb_2, Tw.text_color Tw.gray_700 ] ]
            [ text "Subscribe to updates (optional)" ]
        , div [ css [ Tw.flex, Tw.gap_2 ] ]
            [ input
                [ type_ "email"
                , name "email"
                , placeholder "your.email@example.com"
                , css
                    [ Tw.flex_1
                    , Tw.px_3
                    , Tw.py_2
                    , Tw.border
                    , Tw.border_color Tw.gray_300
                    , Tw.rounded
                    , Css.focus [ Tw.border_color Tw.blue_500, Css.outline Css.none ]
                    ]
                ]
                []
            , button
                [ type_ "submit"
                , css
                    [ Tw.px_4
                    , Tw.py_2
                    , Tw.border_0
                    , Tw.rounded
                    , Tw.bg_color Tw.green_600
                    , Tw.text_color Tw.white
                    , Tw.cursor_pointer
                    , Css.hover [ Tw.bg_color Tw.green_700 ]
                    , Tw.transition_colors
                    ]
                ]
                [ text "Subscribe" ]
            ]
        , case model.subscriptionStatus of
            Just (Ok message) ->
                div [ css [ Tw.text_sm, Tw.text_color Tw.green_600, Tw.mt_2 ] ]
                    [ text message ]
            Just (Err error) ->
                div [ css [ Tw.text_sm, Tw.text_color Tw.red_600, Tw.mt_2 ] ]
                    [ text error ]
            Nothing ->
                text ""
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
