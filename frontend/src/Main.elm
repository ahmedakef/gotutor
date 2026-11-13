port module Main exposing (..)

import Browser
import Browser.Events
import Browser.Navigation as Nav
import Css
import Helpers.Common as Common
import Helpers.Http as HttpHelper
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick, preventDefaultOn)
import Http
import Icons
import Json.Decode as Decode
import Json.Encode as Encode
import Steps.Steps as Steps
import Steps.View as StepsView
import Styles
import Time
import Url
import Url.Parser as Parser exposing ((<?>), (</>), Parser )
import Url.Parser.Query as Query
import Tailwind.Breakpoints as Bp
import Tailwind.Theme as Tw
import Tailwind.Utilities as Tw


-- PORTS


port setLocalStorageWithValue : { key : String, value : String } -> Cmd msg
port getLocalStorage : String -> Cmd msg
port getCurrentTime : () -> Cmd msg
port localStorageReceived : (String -> msg) -> Sub msg
port currentTimeReceived : (Float -> msg) -> Sub msg


-- MAIN


main : Program (Maybe String) Model Msg
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


firefoxAddonUrl : String
firefoxAddonUrl =
    "https://addons.mozilla.org/en-US/firefox/addon/gotutor/"


chromeExtensionUrl : String
chromeExtensionUrl =
    "https://chromewebstore.google.com/detail/gotutor/jpmhhnokngjcnoefeiipogbhlnpmcdbh"


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


sourceCodeStorageKey : String
sourceCodeStorageKey =
    "sourceCode"


nonBlank : String -> Maybe String
nonBlank value =
    if String.isEmpty (String.trim value) then
        Nothing

    else
        Just value


init : Maybe String -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init savedSourceCode url key =
    let
        route =
            Parser.parse routeParser url
                |> Maybe.withDefault (Steps.Home Nothing)

        ( stepsState, stepsCmd ) =
            Steps.init route (savedSourceCode |> Maybe.andThen nonBlank)

        initialModel =
            Model Common.Prod key url stepsState route False Nothing Nothing
    in
    ( initialModel, Cmd.batch [ Cmd.map StepsMsg stepsCmd, getLocalStorage "feedbackDialogDismissed3", getCurrentTime () ] )



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

                previousCode =
                    Steps.userSourceCode model.state

                newCode =
                    Steps.userSourceCode state

                saveCmd =
                    case ( previousCode, newCode ) of
                        ( Just previous, Just code ) ->
                            if previous /= code then
                                setLocalStorageWithValue { key = sourceCodeStorageKey, value = code }

                            else
                                Cmd.none

                        _ ->
                            Cmd.none
            in
            ( { model | state = state }, Cmd.batch [ Cmd.map StepsMsg cmd, saveCmd ] )

        DismissFeedbackDialogTemporary ->
            case model.currentTime of
                Just currentTime ->
                    let
                        timestampValue = "temporary:" ++ String.fromFloat currentTime
                    in
                    ( { model | showFeedbackDialog = False }, setLocalStorageWithValue { key = "feedbackDialogDismissed3", value = timestampValue } )
                Nothing ->
                    ( { model | showFeedbackDialog = False }, getCurrentTime () )

        DismissFeedbackDialogPermanent ->
            ( { model | showFeedbackDialog = False }, setLocalStorageWithValue { key = "feedbackDialogDismissed3", value = "permanent" } )

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
subscriptions model =
    Sub.batch
        [ localStorageReceived LocalStorageReceived
        , currentTimeReceived CurrentTimeReceived
        , if canStepWithKeyboard model then
            Browser.Events.onKeyDown stepKeyDecoder

          else
            Sub.none
        ]


canStepWithKeyboard : Model -> Bool
canStepWithKeyboard model =
    case model.state of
        Steps.Success stepsState ->
            stepsState.mode == Steps.View && not model.showFeedbackDialog

        _ ->
            False


{-| Left/right arrows step through the execution, unless the key is meant for a form control
or used with a modifier (e.g. Alt+Left navigates back).
-}
stepKeyDecoder : Decode.Decoder Msg
stepKeyDecoder =
    Decode.map4
        (\key tagName readOnly hasModifier ->
            let
                isEditable =
                    tagName == "INPUT" || tagName == "SELECT" || (tagName == "TEXTAREA" && not readOnly)
            in
            if hasModifier || isEditable then
                Nothing

            else
                case key of
                    "ArrowRight" ->
                        Just (StepsMsg Steps.Next)

                    "ArrowLeft" ->
                        Just (StepsMsg Steps.Prev)

                    _ ->
                        Nothing
        )
        (Decode.field "key" Decode.string)
        (Decode.oneOf [ Decode.at [ "target", "tagName" ] Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.at [ "target", "readOnly" ] Decode.bool, Decode.succeed False ])
        (Decode.map4 (\alt ctrl meta shift -> alt || ctrl || meta || shift)
            (Decode.field "altKey" Decode.bool)
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
            (Decode.field "shiftKey" Decode.bool)
        )
        |> Decode.andThen
            (\maybeMsg ->
                case maybeMsg of
                    Just msg ->
                        Decode.succeed msg

                    Nothing ->
                        Decode.fail "not a step key"
            )


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


githubUrl : String
githubUrl =
    "https://github.com/ahmedakef/gotutor"


githubIssuesUrl : String
githubIssuesUrl =
    "https://github.com/ahmedakef/gotutor/issues"


githubSponsorsUrl : String
githubSponsorsUrl =
    "https://github.com/sponsors/ahmedakef"


koFiUrl : String
koFiUrl =
    "https://ko-fi.com/M4M319RW5Y"


view : Model -> Browser.Document Msg
view model =
    let
        title =
            "GoTutor | Online Go Debugger & Visualizer"

        shell =
            div
                [ css
                    [ Tw.flex
                    , Tw.flex_col
                    , Bp.lg
                        [ Tw.h_screen
                        , Css.property "height" "100dvh"
                        , Css.minHeight (Css.px 560)
                        ]
                    ]
                ]
                (topBar :: List.map (Html.map StepsMsg) (StepsView.view model.state))

        body =
            div []
                ([ Styles.globalStyles
                 , shell
                 , aboutSection model
                 ]
                    ++ (if model.showFeedbackDialog then
                            [ feedbackDialog model ]

                        else
                            []
                       )
                )
    in
    { title = title
    , body = [ toUnstyled body ]
    }


topBar : Html msg
topBar =
    header
        [ css
            [ Tw.flex_none
            , Tw.flex
            , Tw.items_center
            , Tw.justify_between
            , Tw.gap_4
            , Tw.h_14
            , Tw.px_4
            , Tw.bg_color Tw.white
            , Tw.border_b
            ]
        ]
        [ div [ css [ Tw.flex, Tw.items_center, Tw.gap_3, Tw.min_w_0 ] ]
            [ brandMark
            , div [ css [ Tw.hidden, Bp.lg [ Tw.block ], Tw.h_5, Tw.w_px, Tw.bg_color Tw.slate_200 ] ] []
            , h1 [ css [ Tw.hidden, Bp.lg [ Tw.block ], Tw.text_sm, Tw.font_medium, Tw.text_color Tw.slate_500, Tw.truncate ] ]
                [ text "Online Go Debugger & Visualizer" ]
            ]
        , nav [ attribute "aria-label" "Main", css [ Tw.flex, Tw.items_center, Tw.gap_1 ] ]
            [ a
                [ href firefoxAddonUrl
                , target "_blank"
                , title "Firefox add-on"
                , attribute "aria-label" "Firefox add-on"
                , css [ Styles.buttonGhost, Styles.iconButton, Tw.hidden, Bp.md [ Tw.inline_flex ] ]
                ]
                [ extensionIcon "static/firefox.svg" ]
            , a
                [ href chromeExtensionUrl
                , target "_blank"
                , title "Chrome extension"
                , attribute "aria-label" "Chrome extension"
                , css [ Styles.buttonGhost, Styles.iconButton, Tw.hidden, Bp.md [ Tw.inline_flex ] ]
                ]
                [ extensionIcon "static/chrome.svg" ]
            , a
                [ href githubIssuesUrl
                , target "_blank"
                , title "Share your thoughts and suggestions on GitHub"
                , css [ Styles.buttonGhost, Tw.hidden, Bp.sm [ Tw.inline_flex ] ]
                ]
                [ Icons.messageSquare 16, text "Feedback" ]
            , a [ href "#about", target "_self", css [ Styles.buttonGhost ] ] [ text "About" ]
            , a
                [ href githubUrl
                , target "_blank"
                , attribute "aria-label" "GitHub"
                , css [ Styles.buttonSecondary, Tw.ml_1 ]
                ]
                [ img [ src "static/github-mark.svg", height 16, alt "" ] []
                , span [ css [ Tw.hidden, Bp.sm [ Tw.inline ] ] ] [ text "GitHub" ]
                ]
            , sponsorButton [ Tw.hidden, Bp.sm [ Tw.inline ] ]
            ]
        ]


{-| The browser logos are solid black, so they're dimmed to sit with the other nav items.
-}
extensionIcon : String -> Html msg
extensionIcon iconSrc =
    img [ src iconSrc, height 16, alt "", css [ Css.opacity (Css.num 0.6) ] ] []


brandMark : Html msg
brandMark =
    div [ css [ Tw.flex, Tw.items_center, Tw.gap_2, Tw.shrink_0 ] ]
        [ img [ src "static/gopher.png", height 32, alt "" ] []
        , img [ src "static/logo.svg", height 20, alt "GoTutor" ] []
        ]


{-| The label styles let the top bar hide the text on small screens.
-}
sponsorButton : List Css.Style -> Html msg
sponsorButton labelStyles =
    a [ href githubSponsorsUrl, target "_blank", attribute "aria-label" "Sponsor", css [ Styles.buttonSecondary ] ]
        [ span [ css [ Tw.inline_flex, Tw.text_color Tw.pink_500 ] ] [ Icons.heart 16 ]
        , span [ css labelStyles ] [ text "Sponsor" ]
        ]


koFiButton : Html msg
koFiButton =
    a [ href koFiUrl, target "_blank", css [ Styles.buttonSecondary ] ]
        [ span [ css [ Tw.inline_flex, Tw.text_color Tw.amber_700 ] ] [ Icons.coffee 16 ]
        , text "Buy me a coffee"
        ]


aboutSection : Model -> Html Msg
aboutSection model =
    let
        currentYear =
            model.currentTime
                |> Maybe.map (round >> Time.millisToPosix >> Time.toYear Time.utc)
                |> Maybe.withDefault 2024

        footerLink label link targetPage =
            li [] [ a [ href link, target targetPage, css [ Tw.text_color Tw.slate_600, Css.hover [ Tw.text_color Tw.slate_900 ] ] ] [ text label ] ]
    in
    footer
        [ id "about"
        , css [ Tw.bg_color Tw.white, Tw.border_t ]
        ]
        [ div
            [ css
                [ Tw.max_w_6xl
                , Tw.mx_auto
                , Tw.px_6
                , Tw.py_12
                , Tw.grid
                , Tw.gap_10
                , Bp.md [ Css.property "grid-template-columns" "1.4fr 1fr 1.3fr" ]
                ]
            ]
            [ div [ css [ Tw.flex, Tw.flex_col, Tw.gap_3 ] ]
                [ brandMark
                , p [ css [ Tw.text_color Tw.slate_600 ] ]
                    [ text "GoTutor is an online Go debugger & visualizer. It shows the state of all the running goroutines, the state of each stack frame, and can go back in time." ]
                , p [ css [ Tw.text_color Tw.slate_600 ] ]
                    [ text "It's open source and contributions and ideas are very welcome." ]
                , p [ css [ Styles.muted ] ]
                    [ text ("© 2024–" ++ String.fromInt currentYear ++ " ")
                    , a [ href "https://www.linkedin.com/in/ahmedakef4/", target "_blank" ] [ text "Ahmed Akef" ]
                    ]
                ]
            , div []
                [ h2 [ css [ Styles.sectionTitle, Tw.mb_3 ] ] [ text "Resources" ]
                , ul [ css [ Tw.list_none, Tw.p_0, Tw.flex, Tw.flex_col, Tw.gap_2 ] ]
                    [ footerLink "Source code on GitHub" githubUrl "_blank"
                    , footerLink "Report an issue" githubIssuesUrl "_blank"
                    , footerLink "Known limitations" "https://github.com/ahmedakef/gotutor?tab=readme-ov-file#limitations" "_blank"
                    , footerLink "Firefox add-on" firefoxAddonUrl "_blank"
                    , footerLink "Chrome extension" chromeExtensionUrl "_blank"
                    , footerLink "Privacy policy" "privacy.html" "_self"
                    ]
                ]
            , div [ css [ Tw.flex, Tw.flex_col, Tw.gap_4 ] ]
                [ h2 [ css [ Styles.sectionTitle ] ] [ text "Stay in the loop" ]
                , subscriptionForm "footer" model
                , div [ css [ Tw.flex, Tw.flex_wrap, Tw.gap_2 ] ] [ sponsorButton [], koFiButton ]
                ]
            ]
        ]


feedbackDialog : Model -> Html Msg
feedbackDialog model =
    div
        [ css
            [ Tw.fixed
            , Tw.inset_0
            , Tw.z_50
            , Tw.flex
            , Tw.items_center
            , Tw.justify_center
            , Tw.p_4
            , Css.backgroundColor (Css.rgba 15 23 42 0.45)
            , Tw.backdrop_blur_sm
            ]
        ]
        [ div
            [ attribute "role" "dialog"
            , attribute "aria-modal" "true"
            , attribute "aria-labelledby" "welcome-title"
            , css [ Tw.bg_color Tw.white, Tw.rounded_xl, Tw.shadow_xl, Tw.w_full, Tw.max_w_lg, Tw.p_6, Tw.flex, Tw.flex_col, Tw.gap_5 ]
            ]
            [ div [ css [ Tw.flex, Tw.items_start, Tw.justify_between, Tw.gap_3 ] ]
                [ div [ css [ Tw.flex, Tw.items_center, Tw.gap_3 ] ]
                    [ img [ src "static/gopher.png", height 44, alt "" ] []
                    , div []
                        [ h2 [ id "welcome-title", css [ Tw.text_lg, Tw.font_semibold, Tw.text_color Tw.slate_900 ] ]
                            [ text "Welcome to GoTutor" ]
                        , p [ css [ Styles.muted ] ] [ text "Online Go debugger & visualizer" ]
                        ]
                    ]
                , button
                    [ type_ "button"
                    , onClick DismissFeedbackDialogTemporary
                    , attribute "aria-label" "Close"
                    , css [ Styles.buttonGhost, Styles.iconButton, Tw.h_8, Tw.w_8, Tw.neg_mr_2, Tw.neg_mt_1 ]
                    ]
                    [ Icons.x 18 ]
                ]
            , p [ css [ Tw.text_color Tw.slate_600, Css.lineHeight (Css.num 1.6) ] ]
                [ text "Step through any Go program and watch every goroutine, stack frame and variable change over time. "
                , text "GoTutor is free, open source and maintained by one developer — if it helps you, a GitHub star or a coffee keeps it running."
                ]
            , subscriptionForm "dialog" model
            , div [ css [ Tw.flex, Tw.flex_wrap, Tw.items_center, Tw.gap_2 ] ]
                [ a
                    [ href githubUrl
                    , target "_blank"
                    , onClick DismissFeedbackDialogPermanent
                    , css [ Styles.buttonPrimary ]
                    ]
                    [ Icons.star 16, text "Star on GitHub" ]
                , koFiButton
                , button
                    [ type_ "button"
                    , onClick DismissFeedbackDialogTemporary
                    , css [ Styles.buttonGhost, Tw.ml_auto ]
                    ]
                    [ text "Maybe later" ]
                ]
            ]
        ]


{-| The id prefix keeps the label/input ids unique when the form is rendered more than once.
-}
subscriptionForm : String -> Model -> Html Msg
subscriptionForm idPrefix model =
    let
        inputId =
            idPrefix ++ "-email"
    in
    Html.form
        [ preventDefaultOn "submit" (Decode.map (\email -> (SubmitSubscription email, True)) (Decode.at ["target", "email", "value"] Decode.string))
        ]
        [ label [ for inputId, css [ Tw.block, Tw.text_sm, Tw.font_medium, Tw.mb_1_dot_5, Tw.text_color Tw.slate_700 ] ]
            [ text "Subscribe to updates (optional)" ]
        , div [ css [ Tw.flex, Tw.gap_2 ] ]
            [ input
                [ type_ "email"
                , name "email"
                , id inputId
                , placeholder "your.email@example.com"
                , css [ Styles.input, Tw.flex_1, Tw.min_w_0 ]
                ]
                []
            , button [ type_ "submit", css [ Styles.buttonPrimary ] ] [ text "Subscribe" ]
            ]
        , p [ css [ Styles.muted, Tw.mt_1_dot_5 ] ]
            [ text "By subscribing, you agree to receive updates. You can unsubscribe anytime." ]
        , case model.subscriptionStatus of
            Just (Ok message) ->
                p [ css [ Tw.text_sm, Tw.text_color Tw.emerald_700, Tw.mt_2 ] ]
                    [ text message ]
            Just (Err error) ->
                p [ css [ Tw.text_sm, Tw.text_color Tw.red_600, Tw.mt_2 ] ]
                    [ text error ]
            Nothing ->
                text ""
        ]
