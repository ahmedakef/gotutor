module Steps.View exposing (..)

import Char
import Css
import Helpers.Hex
import Html as UnSytyled
import Html.Attributes
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (..)
import Html.Styled.Keyed as Keyed
import Icons
import Json.Decode as Json
import Steps.Decoder exposing (..)
import Steps.Steps exposing (..)
import Styles
import SyntaxHighlight as SH
import Tailwind.Breakpoints as Bp
import Tailwind.Theme as Tw
import Tailwind.Utilities as Tw


{-| The editor and program state panes, followed by the output panel.
-}
view : State -> List (Html Msg)
view state =
    case state of
        Success stepsState ->
            let
                visualizeState =
                    stateToVisualize stepsState
            in
            [ main_
                [ css
                    [ Tw.flex
                    , Tw.flex_col
                    , Bp.lg
                        [ Tw.grid
                        , Tw.grid_cols_2
                        , Css.property "grid-template-rows" "minmax(0, 1fr)"
                        , Tw.flex_1
                        , Tw.min_h_0
                        ]
                    ]
                ]
                [ editorPane stepsState visualizeState
                , statePane visualizeState
                ]
            , outputPanel visualizeState
            ]

        Failure error ->
            [ centered
                [ div [ css [ Styles.card, Tw.w_full, Tw.max_w_lg, Tw.p_5 ] ]
                    [ div [ css [ Tw.flex, Tw.items_center, Tw.gap_2, Tw.text_color Tw.red_700, Tw.font_semibold ] ]
                        [ Icons.circleAlert 18, text "Couldn't load the program" ]
                    , pre [ css [ Styles.mono, Tw.text_xs, Tw.whitespace_pre_wrap, Tw.break_words, Tw.text_color Tw.slate_700, Tw.bg_color Tw.slate_50, Tw.rounded_md, Tw.p_3, Tw.mt_3, Tw.mb_4 ] ]
                        [ text error ]
                    , a [ href "", target "_self", css [ Styles.buttonSecondary ] ] [ text "Reload" ]
                    ]
                ]
            ]

        Loading ->
            [ centered
                [ img [ src "static/gopher.png", alt "", height 64 ] []
                , div [ css [ Tw.flex, Tw.items_center, Tw.gap_2, Tw.text_color Tw.slate_500 ] ]
                    [ spinner 16, text "Loading program…" ]
                ]
            ]


centered : List (Html msg) -> Html msg
centered content =
    main_
        [ css
            [ Tw.flex_1
            , Tw.flex
            , Tw.flex_col
            , Tw.items_center
            , Tw.justify_center
            , Tw.gap_4
            , Tw.p_8
            , Css.minHeight (Css.vh 60)
            ]
        ]
        content


spinner : Int -> Html msg
spinner size =
    span [ css [ Tw.inline_flex, Tw.animate_spin ] ] [ Icons.loader size ]


type alias VisualizeState =
    { lastStep : Maybe Step
    , stdout : String
    , stderr : String
    , duration : String
    , packageVars : List Variable
    , sourceCode : String
    , scroll : Scroll
    , currentLine : Maybe Int
    , highlightedLine : Maybe Int
    , mode : Mode
    , flashMessage : Maybe String
    , config : Config
    }


stateToVisualize : StepsState -> VisualizeState
stateToVisualize stepsState =
    let
        stepsSoFar =
            stepsState.executionResponse.steps
                |> List.take stepsState.position

        lastStep =
            stepsSoFar
                |> List.reverse
                |> List.head
    in
    case lastStep of
        Just step ->
            let
                packageVars =
                    step.packageVars

                currentLine =
                    List.head step.goroutinesData
                        |> Maybe.map .stacktrace
                        |> Maybe.map filterUserFrames
                        |> Maybe.andThen List.head
                        |> Maybe.map .line
            in
            { lastStep = Just step
            , stdout = stepsState.executionResponse.stdout
            , stderr = stepsState.executionResponse.stderr
            , duration = stepsState.executionResponse.duration
            , packageVars = packageVars
            , sourceCode = stepsState.sourceCode
            , scroll = stepsState.scroll
            , currentLine = currentLine
            , highlightedLine = stepsState.highlightedLine
            , mode = stepsState.mode
            , flashMessage = stepsState.errorMessage
            , config = stepsState.config
            }

        Nothing ->
            VisualizeState lastStep "" "" "" [] stepsState.sourceCode stepsState.scroll Nothing Nothing stepsState.mode stepsState.errorMessage stepsState.config


filterUserFrames : List StackFrame -> List StackFrame
filterUserFrames stack =
    stack
        |> List.filter (\frame -> String.endsWith "main.go" frame.file)



-- EDITOR PANE


editorPane : StepsState -> VisualizeState -> Html Msg
editorPane stepsState state =
    section
        [ attribute "aria-label" "Editor"
        , css
            [ Tw.flex
            , Tw.flex_col
            , Tw.min_h_0
            , Tw.bg_color Tw.white
            , Tw.border_b
            , Bp.lg [ Tw.border_b_0, Tw.border_r ]
            ]
        ]
        [ editorToolbar stepsState state
        , codeView state
        , stepControls stepsState
        ]


editorToolbar : StepsState -> VisualizeState -> Html Msg
editorToolbar stepsState state =
    div [ css [ Styles.panelHeader ] ]
        [ div [ css [ Tw.flex, Tw.flex_wrap, Tw.items_center, Tw.gap_2, Tw.min_w_0 ] ]
            (exampleSelector
                :: (case state.mode of
                        Edit ->
                            [ button [ type_ "button", onClick Fmt, css [ Styles.buttonSecondary, Styles.buttonSm ] ]
                                [ Icons.alignLeft 14, text "Format" ]
                            ]

                        View ->
                            [ button [ type_ "button", onClick Share, css [ Styles.buttonSecondary, Styles.buttonSm ] ]
                                [ Icons.share 14, text "Share" ]
                            , case stepsState.shareUrl of
                                Just url ->
                                    span
                                        [ title "Click to select the link, then copy it"
                                        , css
                                            [ Styles.mono
                                            , Tw.select_all
                                            , Tw.truncate
                                            , Tw.max_w_xs
                                            , Tw.text_xs
                                            , Tw.leading_5
                                            , Tw.px_2
                                            , Tw.py_1
                                            , Tw.rounded_md
                                            , Tw.border
                                            , Tw.border_color Tw.slate_200
                                            , Tw.bg_color Tw.slate_50
                                            , Tw.text_color Tw.slate_700
                                            ]
                                        ]
                                        [ text url ]

                                Nothing ->
                                    text ""
                            ]

                        _ ->
                            []
                   )
            )
        , editOrViewButton state.mode
        ]


codeView : VisualizeState -> Html Msg
codeView state =
    let
        currentLine =
            Maybe.withDefault 0 state.currentLine

        highlightedLine =
            Maybe.withDefault 0 state.highlightedLine

        highlightModeHighlightedLine =
            if highlightedLine == currentLine then
                Nothing

            else
                Maybe.map (\_ -> SH.Highlight) state.highlightedLine
    in
    div
        [ css
            [ case state.mode of
                Edit ->
                    Tw.bg_color Tw.slate_50

                _ ->
                    Tw.bg_color Tw.white
            ]
        , class "code-container"
        ]
        [ div
            [ class "code-view-container"
            , class "code-style"
            , style "transform"
                ("translate("
                    ++ String.fromFloat -state.scroll.left
                    ++ "px, "
                    ++ String.fromFloat -state.scroll.top
                    ++ "px)"
                )
            , css [ Css.property "will-change" "transform", Css.pointerEvents Css.none ]
            ]
            [ case state.mode of
                View ->
                    SH.go state.sourceCode
                        |> Result.map (SH.highlightLines highlightModeHighlightedLine (highlightedLine - 1) highlightedLine)
                        |> Result.map (SH.highlightLines (Just SH.Add) (currentLine - 1) currentLine)
                        |> Result.map (SH.toBlockHtml (Just 1))
                        |> Result.withDefault
                            (UnSytyled.pre [] [ UnSytyled.code [ Html.Attributes.class "elmsh" ] [ UnSytyled.text state.sourceCode ] ])
                        |> Html.Styled.fromUnstyled

                _ ->
                    SH.go state.sourceCode
                        |> Result.map (SH.toBlockHtml (Just 1))
                        |> Result.withDefault
                            (UnSytyled.pre [] [ UnSytyled.code [ Html.Attributes.class "elmsh" ] [ UnSytyled.text state.sourceCode ] ])
                        |> Html.Styled.fromUnstyled
            ]
        , textarea
            [ onInput CodeUpdated
            , on "scroll"
                (Json.map2 Scroll
                    (Json.at [ "target", "scrollTop" ] Json.float)
                    (Json.at [ "target", "scrollLeft" ] Json.float)
                    |> Json.map OnScroll
                )
            , value state.sourceCode
            , readonly (not (state.mode == Edit))
            , id "code-textarea"
            , class "code-style"
            , class "code-textarea"
            , class "code-textarea-lc"
            , class "thin-scroll"
            , spellcheck False
            , attribute "aria-label" "Go source code"
            , css
                [ Css.cursor
                    (case state.mode of
                        Edit ->
                            Css.text_

                        _ ->
                            Css.default
                    )
                ]
            ]
            []
        ]


stepControls : StepsState -> Html Msg
stepControls stepsState =
    let
        total =
            List.length stepsState.executionResponse.steps

        position =
            stepsState.position

        hasSteps =
            total > 0

        atStart =
            not hasSteps || position <= 1

        atEnd =
            not hasSteps || position >= total
    in
    div [ css [ Tw.flex_none, Tw.border_t, Tw.px_3, Tw.pt_1, Tw.pb_2 ] ]
        [ div [ css [ Tw.flex, Tw.items_center, Tw.gap_3 ] ]
            [ div [ css [ Tw.flex, Tw.items_center, Tw.gap_1 ] ]
                [ stepButton "First step" (SliderChange 1) atStart (Icons.chevronFirst 16)
                , stepButton "Previous step (←)" Prev atStart (Icons.chevronLeft 16)
                , stepButton "Next step (→)" Next atEnd (Icons.chevronRight 16)
                , stepButton "Last step" (SliderChange total) atEnd (Icons.chevronLast 16)
                ]
            , if hasSteps then
                div [ css [ Tw.text_sm, Tw.text_color Tw.slate_500, Tw.tabular_nums, Tw.whitespace_nowrap ] ]
                    [ text "Step "
                    , span [ css [ Tw.font_semibold, Tw.text_color Tw.slate_900 ] ] [ text (String.fromInt position) ]
                    , text (" / " ++ String.fromInt total)
                    ]

              else
                div [ css [ Styles.muted, Tw.whitespace_nowrap ] ] [ text "Press Visualize to record steps" ]
            , input
                [ type_ "range"
                , Html.Styled.Attributes.min "1"
                , Html.Styled.Attributes.max (String.fromInt total)
                , Html.Styled.Attributes.value (String.fromInt position)
                , onInput (String.toInt >> Maybe.withDefault 1 >> SliderChange)
                , disabled (not hasSteps)
                , attribute "aria-label" "Execution step"
                , css [ Tw.flex_1, Tw.min_w_0 ]
                ]
                []
            ]
        , p [ css [ Tw.text_color Tw.slate_400, Css.fontSize (Css.px 11) ] ]
            [ text "Your code is sent to our server for execution and cached to improve performance. We don't share it." ]
        ]


stepButton : String -> Msg -> Bool -> Html Msg -> Html Msg
stepButton label msg isDisabled iconHtml =
    button
        [ type_ "button"
        , onClick msg
        , disabled isDisabled
        , title label
        , attribute "aria-label" label
        , css [ Styles.buttonGhost, Styles.iconButton, Tw.h_8, Tw.w_8 ]
        ]
        [ iconHtml ]


editOrViewButton : Mode -> Html Msg
editOrViewButton mode =
    case mode of
        Edit ->
            button [ type_ "button", onClick Visualize, css [ Styles.buttonPrimary, Styles.buttonSm ] ]
                [ Icons.play 14, text "Visualize" ]

        View ->
            button [ type_ "button", onClick EditCode, css [ Styles.buttonSecondary, Styles.buttonSm ] ]
                [ Icons.squarePen 14, text "Edit code" ]

        WaitingSteps ->
            busyButton "Running…"

        WaitingSourceCode ->
            busyButton "Loading…"

        WaitingLLM ->
            busyButton "Asking AI…"


busyButton : String -> Html msg
busyButton label =
    button [ type_ "button", disabled True, css [ Styles.buttonPrimary, Styles.buttonSm ] ]
        [ spinner 14, text label ]


exampleSelector : Html Msg
exampleSelector =
    select
        [ css [ Styles.select ]
        , onInput ExampleSelected
        , attribute "aria-label" "Load an example"
        ]
        [ option [ value "gotutor.txt", Html.Styled.Attributes.default True ] [ text "GoTutor Example" ]
        , option [ value "goroutines.txt" ] [ text "Goroutines" ]
        , option [ value "hello.txt" ] [ text "Hello, World!" ]
        , option [ value "fib.txt" ] [ text "Fibonacci Closure" ]
        , option [ value "pi.txt" ] [ text "Concurrent pi" ]
        , option [ value "sieve.txt" ] [ text "Concurrent Prime Sieve" ]
        , option [ value "tree.txt" ] [ text "Tree Comparison" ]
        , option [ value "http.txt" ] [ text "HTTP Server" ]
        , option [ value "index-dev.txt" ] [ text "Generic index" ]
        ]



-- STATE PANE


statePane : VisualizeState -> Html Msg
statePane state =
    section
        [ attribute "aria-label" "Program state"
        , css [ Tw.flex, Tw.flex_col, Tw.min_h_0, Tw.bg_color Tw.slate_50 ]
        ]
        [ div [ css [ Styles.panelHeader ] ]
            [ h2 [ css [ Tw.text_sm, Tw.font_semibold, Tw.text_color Tw.slate_900 ] ] [ text "Program state" ]
            , configView state.config
            ]
        , div
            [ class "thin-scroll"
            , css
                [ Tw.flex_1
                , Tw.min_h_0
                , Tw.overflow_auto
                , Tw.overscroll_contain
                , Tw.p_4
                , Tw.flex
                , Tw.flex_col
                , Tw.gap_5
                ]
            ]
            [ backendStateView state
            , globalsView state.config state.packageVars
            , goroutinesView
                state.config
                (state.lastStep
                    |> Maybe.map .goroutinesData
                    |> Maybe.withDefault []
                    |> List.filter (\g -> not (List.isEmpty (filterUserFrames g.stacktrace)))
                )
            ]
        ]


configView : Config -> Html Msg
configView config =
    div [ css [ Tw.flex, Tw.flex_wrap, Tw.items_center, Tw.gap_x_4, Tw.gap_y_1, Tw.text_xs, Tw.text_color Tw.slate_600 ] ]
        [ label [ css [ Tw.flex, Tw.items_center, Tw.gap_1_dot_5, Tw.cursor_pointer ] ]
            [ input [ type_ "checkbox", onCheck ShowOnlyExportedFields, checked config.showOnlyExportedFields, css [ Styles.checkbox ] ] []
            , text "Exported fields only"
            ]
        , label [ css [ Tw.flex, Tw.items_center, Tw.gap_1_dot_5, Tw.cursor_pointer ] ]
            [ input [ type_ "checkbox", onCheck ShowMemoryAddresses, checked config.showMemoryAddresses, css [ Styles.checkbox ] ] []
            , text "Memory addresses"
            ]
        ]


backendStateView : VisualizeState -> Html Msg
backendStateView state =
    let
        waitingMessage =
            case state.mode of
                WaitingSteps ->
                    Just "Waiting for backend to get execution steps... ⏳"

                WaitingSourceCode ->
                    Just "Waiting for source code... ⏳"

                WaitingLLM ->
                    Just "Waiting for LLM response... ⏳"

                _ ->
                    Nothing

        infoAlert message =
            div [ attribute "role" "status", css [ Styles.alertInfo, Tw.flex, Tw.items_center, Tw.gap_2 ] ]
                [ Icons.info 16, text message ]
    in
    case ( waitingMessage, state.flashMessage, state.lastStep ) of
        ( Just message, _, _ ) ->
            infoAlert message

        ( Nothing, Just error, _ ) ->
            div [ attribute "role" "alert", css [ Styles.alertDanger ] ]
                [ div [ css [ Tw.flex, Tw.items_start, Tw.gap_2 ] ]
                    [ span [ css [ Tw.inline_flex, Tw.mt_0_dot_5, Tw.text_color Tw.red_600 ] ] [ Icons.circleAlert 16 ]
                    , pre [ css [ Styles.mono, Tw.flex_1, Tw.min_w_0, Tw.m_0, Tw.text_xs, Tw.leading_5, Tw.whitespace_pre_wrap, Tw.break_words ] ]
                        [ text error ]
                    ]
                , div [ css [ Tw.flex, Tw.justify_end, Tw.mt_3 ] ]
                    [ button [ type_ "button", onClick FixCodeWithAI, css [ Styles.buttonSecondary, Styles.buttonSm ] ]
                        [ text "Fix with AI ✨" ]
                    ]
                ]

        ( Nothing, Nothing, Nothing ) ->
            infoAlert "No step to show yet. Press Visualize to run the program, or move the slider."

        ( Nothing, Nothing, Just _ ) ->
            text ""


globalsView : Config -> List Variable -> Html msg
globalsView config vars =
    if List.isEmpty vars then
        text ""

    else
        details [ attribute "open" "" ]
            [ summary [ css [ Styles.sectionTitle, Tw.mb_2 ] ] [ text "Global variables" ]
            , div [ css [ Styles.card, Tw.px_3, Tw.py_2 ] ] [ varList config vars ]
            ]


goroutinesView : Config -> List GoroutinesData -> Html Msg
goroutinesView config goroutinesData =
    let
        note =
            if List.length goroutinesData >= 100 then
                p [ css [ Styles.muted, Tw.mb_3 ] ] [ text "Showing the first 100 goroutines only." ]

            else
                text ""

        goroutines =
            if List.length goroutinesData >= 100 then
                List.take 100 goroutinesData

            else
                goroutinesData
    in
    if List.isEmpty goroutines then
        text ""

    else
        details [ attribute "open" "" ]
            [ summary [ css [ Styles.sectionTitle, Tw.mb_3 ] ]
                [ text <| "Goroutines · " ++ String.fromInt (List.length goroutines) ]
            , note
            , Keyed.node "div"
                [ css
                    [ Tw.grid
                    , Css.property "grid-template-columns" "repeat(auto-fill, minmax(280px, 1fr))"
                    , Tw.items_start
                    , Tw.gap_x_4
                    , Tw.gap_y_6
                    , Tw.pt_3
                    ]
                ]
                -- the first goroutine is the one executing the highlighted line
                (List.indexedMap
                    (\index goroutineData ->
                        ( String.fromInt goroutineData.goroutine.id
                        , goroutineView config (index == 0) goroutineData
                        )
                    )
                    goroutines
                )
            ]


goroutineView : Config -> Bool -> GoroutinesData -> Html Msg
goroutineView config isRunning goroutineData =
    div
        [ css
            [ Styles.card
            , Tw.relative
            , Tw.flex
            , Tw.flex_col
            , Tw.gap_3
            , Tw.p_3
            , Tw.min_w_0
            , if isRunning then
                Css.batch [ Tw.border_color Tw.transparent, Tw.ring_2, Tw.ring_color Tw.emerald_500 ]

              else
                Css.batch []
            ]
        ]
        [ img
            [ src "static/megaphone-gopher.svg"
            , alt ""
            , css [ Tw.absolute, Tw.w_10, Tw.h_10, Css.top (Css.rem -1), Css.left (Css.rem -0.75) ]
            ]
            []
        , goroutineInfoView isRunning goroutineData
        , stackView config (goroutineData.stacktrace |> filterUserFrames)
        ]


goroutineInfoView : Bool -> GoroutinesData -> Html msg
goroutineInfoView isRunning goroutineData =
    let
        gInfo =
            if goroutineData.goroutine.id == 1 then
                "Main Goroutine #1"

            else
                "Goroutine #" ++ String.fromInt goroutineData.goroutine.id

        runningBadge =
            if isRunning then
                span
                    [ css
                        [ Tw.inline_flex
                        , Tw.items_center
                        , Tw.gap_1_dot_5
                        , Tw.rounded_full
                        , Tw.bg_color Tw.emerald_50
                        , Tw.text_color Tw.emerald_700
                        , Tw.px_2
                        , Tw.py_0_dot_5
                        , Tw.text_xs
                        , Tw.font_medium
                        ]
                    ]
                    [ span [ css [ Tw.w_1_dot_5, Tw.h_1_dot_5, Tw.rounded_full, Tw.bg_color Tw.emerald_500 ] ] []
                    , text "running"
                    ]

            else
                text ""
    in
    div [ css [ Tw.flex, Tw.items_center, Tw.justify_between, Tw.gap_2, Tw.pl_8, Css.minHeight (Css.rem 1.5) ] ]
        [ h3 [ css [ Tw.text_sm, Tw.font_semibold, Tw.text_color Tw.slate_900 ] ] [ text gInfo ]
        , runningBadge
        ]


stackView : Config -> List StackFrame -> Html Msg
stackView config stack =
    if List.isEmpty stack then
        text ""

    else
        details [ attribute "open" "" ]
            [ summary [ css [ Styles.sectionTitle, Tw.mb_2 ] ] [ text "Stack frames" ]
            , ol [ css [ Tw.list_none, Tw.p_0 ] ]
                (List.indexedMap
                    (\index frame ->
                        li []
                            [ if index > 0 then
                                -- the frame above is called by this one
                                div [ title "called from", css [ Tw.flex, Tw.justify_center, Tw.text_color Tw.slate_400 ] ]
                                    [ Icons.chevronUp 14 ]

                              else
                                text ""
                            , frameView config frame
                            ]
                    )
                    stack
                )
            ]


frameView : Config -> StackFrame -> Html Msg
frameView config frame =
    let
        fileName =
            String.split "/" frame.file
                |> List.reverse
                |> List.head
                |> Maybe.withDefault frame.file
    in
    div
        [ css
            [ Tw.rounded_md
            , Tw.border
            , Tw.border_color Tw.slate_200
            , Tw.bg_color Tw.slate_50
            , Tw.p_2_dot_5
            , Tw.transition_colors
            , Css.hover [ Tw.border_color Tw.cyan_400, Tw.bg_color Tw.white ]
            ]
        , onMouseEnter (Highlight frame.line)
        , onMouseLeave (Unhighlight frame.line)
        ]
        [ div [ css [ Tw.flex, Tw.items_center, Tw.justify_between, Tw.gap_2 ] ]
            [ span [ css [ Styles.mono, Tw.text_xs, Tw.font_semibold, Tw.text_color Tw.slate_900, Tw.truncate ] ]
                [ text <| removeMainPrefix frame.function.name ]
            , span [ css [ Styles.chip, Tw.shrink_0, Tw.bg_color Tw.white, Tw.border, Tw.border_color Tw.slate_200 ] ]
                [ text <| fileName ++ ":" ++ String.fromInt frame.line ]
            ]
        , varsView config "arguments" frame.arguments
        , varsView config "locals" frame.locals
        ]


varsView : Config -> String -> Maybe (List Variable) -> Html msg
varsView config title maybeVars =
    case maybeVars of
        Nothing ->
            text ""

        Just vars ->
            if List.isEmpty vars then
                text ""

            else
                details [ attribute "open" "", css [ Tw.mt_2 ] ]
                    [ summary [ css [ Tw.text_xs, Tw.font_medium, Tw.text_color Tw.slate_500, Tw.mb_0_dot_5 ] ] [ text title ]
                    , varList config vars
                    ]


varList : Config -> List Variable -> Html msg
varList config vars =
    ul
        [ css
            [ Styles.mono
            , Tw.list_none
            , Tw.p_0
            , Css.fontSize (Css.px 12)
            , Css.lineHeight (Css.rem 1.25)
            , Tw.text_color Tw.slate_800
            ]
        ]
        (List.map (varView config) vars)


varView : Config -> Variable -> Html msg
varView config v =
    case v of
        VariableI var ->
            let
                value =
                    case var.type_ of
                        "string" ->
                            quotedString var.value

                        _ ->
                            var.value

                isSliceOrArray =
                    String.startsWith "[]" var.type_ || isArrayType var.type_

                isMap =
                    String.startsWith "map[" var.type_

                children =
                    if isMap then
                        pairMapChildren var.children

                    else if isSliceOrArray then
                        var.children
                            |> List.indexedMap
                                (\i child ->
                                    case child of
                                        VariableI vI ->
                                            VariableI { vI | name = "[" ++ String.fromInt i ++ "]" ++ vI.name }
                                )

                    else if config.showOnlyExportedFields then
                        var.children
                            |> List.filter
                                -- only show exported fields
                                (\child ->
                                    case child of
                                        VariableI vI ->
                                            String.uncons vI.name
                                                |> Maybe.map (\( firstChar, _ ) -> Char.isUpper firstChar)
                                                |> Maybe.withDefault False
                                )

                    else
                        var.children

                isLeaf =
                    List.isEmpty children

                lengthInfo =
                    if isSliceOrArray then
                        "len: " ++ String.fromInt var.len ++ ", cap: " ++ String.fromInt var.cap

                    else if isMap then
                        "len: " ++ String.fromInt var.len

                    else
                        ""
            in
            li []
                [ details
                    (if isLeaf then
                        [ class "leaf" ]

                     else
                        []
                    )
                    [ summary [ css [ Tw.py_px, Css.property "overflow-wrap" "anywhere", Css.paddingLeft (Css.em 1), Css.textIndent (Css.em -1) ] ]
                        [ span [] [ text (removeMainPrefix var.name) ]
                        , span [ css [ Tw.text_color Tw.slate_400 ] ] [ text " = " ]
                        , span [ css [ Tw.text_color Tw.slate_400 ] ]
                            [ text <| "{" ++ var.type_
                            , if config.showMemoryAddresses then
                                text <| " | " ++ (var.addr |> Helpers.Hex.intToHex)

                              else
                                text ""
                            , text "} "
                            ]
                        , span [ css [ valueColor var.type_ ] ] [ text value ]
                        , if String.isEmpty lengthInfo then
                            text ""

                          else
                            span [ css [ Tw.text_color Tw.slate_400, Css.fontSize (Css.px 11), Tw.ml_2 ] ] [ text lengthInfo ]
                        ]
                    , if isLeaf then
                        text ""

                      else
                        ul [ css [ Tw.list_none, Tw.p_0, Tw.ml_1, Tw.pl_3, Tw.border_l, Tw.border_color Tw.slate_200 ] ]
                            (List.map (varView config) children)
                    ]
                ]


valueColor : String -> Css.Style
valueColor type_ =
    let
        isNumber =
            List.any (\prefix -> String.startsWith prefix type_) [ "int", "uint", "float", "complex" ]
                || List.member type_ [ "byte", "rune" ]
    in
    if type_ == "string" then
        Css.color Styles.stringColor

    else if isNumber then
        Css.color Styles.numberColor

    else if type_ == "bool" then
        Css.color Styles.boolColor

    else
        Css.batch []


isArrayType : String -> Bool
isArrayType type_ =
    case String.uncons type_ of
        Just ( '[', rest ) ->
            case String.uncons rest of
                Just ( firstChar, _ ) ->
                    Char.isDigit firstChar

                Nothing ->
                    False

        _ ->
            False


quotedString : String -> String
quotedString s =
    "\"" ++ s ++ "\""


pairMapChildren : List Variable -> List Variable
pairMapChildren children =
    case children of
        (VariableI key) :: (VariableI val) :: rest ->
            let
                keyStr =
                    case key.type_ of
                        "string" ->
                            quotedString key.value

                        _ ->
                            key.value
            in
            VariableI { val | name = keyStr } :: pairMapChildren rest

        _ ->
            []


removeMainPrefix : String -> String
removeMainPrefix str =
    let
        prefix =
            "main."

        prefixLength =
            String.length prefix
    in
    if String.startsWith prefix str then
        String.dropLeft prefixLength str

    else
        str



-- OUTPUT PANEL


outputPanel : VisualizeState -> Html Msg
outputPanel state =
    let
        isEmpty =
            String.isEmpty (String.trim state.stdout) && String.isEmpty (String.trim state.stderr)
    in
    details
        [ attribute "open" ""
        , attribute "aria-label" "Program output"
        , css [ Tw.flex_none, Tw.bg_color Tw.white, Tw.border_t ]
        ]
        [ summary [ css [ Tw.px_4, Tw.py_2, Tw.text_color Tw.slate_500, Tw.select_none ] ]
            [ span [ css [ Tw.inline_flex, Tw.items_center, Tw.gap_3, Tw.align_middle ] ]
                [ span [ css [ Tw.inline_flex, Tw.items_center, Tw.gap_1_dot_5, Tw.text_sm, Tw.font_semibold, Tw.text_color Tw.slate_900 ] ]
                    [ Icons.terminal 14, text "Output" ]
                , if String.isEmpty state.duration then
                    text ""

                  else
                    span [ title "Execution time", css [ Styles.chip ] ] [ Icons.clock 12, text state.duration ]
                , span [ css [ Styles.muted, Tw.hidden, Bp.sm [ Tw.inline ] ] ] [ text "Output doesn't follow the slider yet." ]
                ]
            ]
        , div
            [ class "thin-scroll"
            , css
                [ Styles.mono
                , Tw.text_xs
                , Tw.leading_5
                , Css.property "max-height" "clamp(4.5rem, 20vh, 13rem)"
                , Tw.overflow_auto
                , Tw.overscroll_contain
                , Tw.px_4
                , Tw.pb_3
                ]
            ]
            (if isEmpty then
                [ p [ css [ Tw.text_color Tw.slate_400 ] ] [ text "No output" ] ]

             else
                [ if String.isEmpty state.stdout then
                    text ""

                  else
                    pre [ css [ Tw.m_0, Tw.whitespace_pre_wrap, Tw.break_words, Tw.text_color Tw.slate_800, Css.property "font" "inherit" ] ]
                        [ text state.stdout ]
                , if String.isEmpty state.stderr then
                    text ""

                  else
                    div [ css [ Tw.mt_2 ] ]
                        [ div [ css [ Tw.text_color Tw.red_600, Tw.font_semibold, Tw.uppercase, Tw.tracking_wide, Css.fontSize (Css.px 10) ] ] [ text "stderr" ]
                        , pre [ css [ Tw.m_0, Tw.whitespace_pre_wrap, Tw.break_words, Tw.text_color Tw.red_600, Css.property "font" "inherit" ] ]
                            [ text state.stderr ]
                        ]
                ]
            )
        ]
