module Steps.View exposing (..)

import Char
import Css
import Css.Global exposing (children)
import Helpers.Hex
import Html as UnSytyled
import Html.Attributes
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (..)
import Json.Decode as Json
import Steps.Decoder exposing (..)
import Steps.Steps exposing (..)
import SyntaxHighlight as SH
import Tailwind.Theme as Tw
import Tailwind.Utilities as Tw
import Svg
import Svg.Attributes as SvgAttr


view : State -> Html Msg
view state =
    case state of
        Success stepsState ->
            let
                visualizeState =
                    stateToVisualize stepsState
            in
            main_ [ css [ Tw.flex, Tw.flex_wrap, Tw.flex_1 ] ]
                [ div [ css [ Tw.flex, Tw.flex_col, Tw.items_center, Tw.flex_1, Tw.pb_4 ] ]
                        [ div [ css [Tw.box_border, borderStyle, Tw.px_2 ,Tw.py_2, Tw.flex, Tw.flex_wrap, Tw.flex_row, Tw.items_center,
                                Tw.justify_between, Tw.gap_2, Css.width (Css.pct 85), Css.backgroundColor mutedColor, Tw.rounded_t_lg ] ] [
                            div [css [ Tw.flex, Tw.flex_row, Tw.items_center, Tw.gap_2 ]] ( exampleSelector :: (case visualizeState.mode of
                                Edit ->
                                    [ div [ onClick Fmt, css [ secondaryButtonStyle, borderStyle ] ] [
                                        formatSvg
                                        , text "Format"
                                        ]
                                    ]

                                View ->
                                    [ case stepsState.shareUrl of
                                        Just url ->
                                            input [ type_ "text", value url, css [ Tw.w_56, Tw.p_2, Tw.bg_color Tw.slate_50, borderStyle ] ] []
                                        Nothing ->
                                            input [ type_ "text", hidden True ] []
                                    , div [ onClick Share, css [ secondaryButtonStyle, borderStyle ] ] [
                                        shareSvg
                                        , text "Share"
                                    ]
                                    ]
                                _ ->
                                    []
                            ) )
                            , div [] [editOrViewButton visualizeState.mode]
                            ]
                            , codeView visualizeState
                            , div [ css [ Css.displayFlex, Css.flexDirection Css.column, Tw.box_border
                                    ,Tw.bg_color Tw.white, Tw.p_4, borderStyle, Tw.rounded_lg, Tw.mt_4, Css.width (Css.pct 85) ] ]
                                [ div [ css [ Tw.flex, Tw.flex_row, Tw.items_center, Tw.gap_2, Tw.justify_between ] ]
                                    [ div [ css [ Tw.text_color Tw.gray_500 ] ]
                                        [ text ("Step " ++ String.fromInt stepsState.position ++ " of " ++ (List.length stepsState.executionResponse.steps |> String.fromInt))
                                        ]
                                    , div [] [
                                        div [ onClick Prev, css [ secondaryButtonStyle, borderStyle, Tw.mr_4 ] ] [ previousSvg ]
                                        , div [ onClick Next, css [ secondaryButtonStyle, borderStyle, Tw.ml_4 ] ] [ nextSvg ]
                                    ]
                                    ]
                                    , div [ css [ Tw.flex, Tw.justify_center, Tw.mt_4 ] ]
                                        [ input
                                            [ type_ "range"
                                            , Html.Styled.Attributes.min "1"
                                            , Html.Styled.Attributes.max (String.fromInt (List.length stepsState.executionResponse.steps))
                                            , Html.Styled.Attributes.value (String.fromInt stepsState.position)
                                            , onInput (String.toInt >> Maybe.withDefault 1 >> SliderChange)
                                            ]
                                            []
                                        ]
                                ]
                        ]
                    , programVisualizer visualizeState
                    ]


        Failure error ->
            main_ [ css [ Css.flex (Css.num 1), Css.displayFlex, Css.justifyContent Css.spaceBetween, Css.alignItems Css.center ] ]
                [ pre [ css [ Tw.bg_color Tw.red_500, Css.fontSize (Css.px 20) ] ] [ text error ]
                ]

        Loading ->
            main_ [ css [ Css.flex (Css.num 1), Css.displayFlex, Css.justifyContent Css.spaceBetween, Css.alignItems Css.center ] ]
                [ pre [ css [ Css.fontSize (Css.px 20) ] ] [ text "Loading..." ]
                ]

nextSvg : Html msg
nextSvg =
    (Svg.svg
        [ SvgAttr.width "24"
        , SvgAttr.height "24"
        , SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        , SvgAttr.class "lucide lucide-chevron-right h-4 w-4"
        ]
        [ Svg.path
            [ SvgAttr.d "m9 18 6-6-6-6"
            ]
            []
        ]
    ) |> Html.Styled.fromUnstyled

previousSvg : Html msg
previousSvg =
    (Svg.svg
        [ SvgAttr.width "24"
        , SvgAttr.height "24"
        , SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        , SvgAttr.class "lucide lucide-chevron-left h-4 w-4"
        ]
        [ Svg.path
            [ SvgAttr.d "m15 18-6-6 6-6"
            ]
            []
        ]
    ) |> Html.Styled.fromUnstyled
shareSvg : Html msg
shareSvg =
    (Svg.svg
        [ SvgAttr.width "16"
        , SvgAttr.height "16"
        , SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        , SvgAttr.class "lucide lucide-share"
        ]
        [ Svg.path
            [ SvgAttr.d "M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"
            ]
            []
        , Svg.polyline
            [ SvgAttr.points "16 6 12 2 8 6"
            ]
            []
        , Svg.line
            [ SvgAttr.x1 "12"
            , SvgAttr.x2 "12"
            , SvgAttr.y1 "2"
            , SvgAttr.y2 "15"
            ]
            []
        ]
    ) |> Html.Styled.fromUnstyled

formatSvg : Html msg
formatSvg =
    (Svg.svg
        [ SvgAttr.width "16"
        , SvgAttr.height "16"
        , SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        , SvgAttr.class "lucide lucide-align-left"
        ]
        [ Svg.path
            [ SvgAttr.d "M15 12H3"
            ]
            []
        , Svg.path
            [ SvgAttr.d "M17 18H3"
            ]
            []
        , Svg.path
            [ SvgAttr.d "M21 6H3"
            ]
            []
        ]
    ) |> Html.Styled.fromUnstyled

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
            [ borderStyle
            , case state.mode of
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
            , class "code-style"
            , class "code-textarea"
            , class "code-textarea-lc"
            , spellcheck False
            , css
                [ Css.cursor
                    (case state.mode of
                        Edit ->
                            Css.text_

                        _ ->
                            Css.notAllowed
                    )
                ]
            ]
            []
        ]


wrapCode : String -> String
wrapCode code =
    "```go\n" ++ code ++ "\n```"

secondaryBackgroundColor : Css.Color
secondaryBackgroundColor =
    Css.hsla 210 0.40 0.98 1

secondaryBackgroundColorHover : Css.Color
secondaryBackgroundColorHover =
    Css.hsla 210 0.40 0.961 1

mutedColor : Css.Color
mutedColor =
    Css.hsla 210 0.40 0.96 1

primaryForegroundColor : Css.Color
primaryForegroundColor =
    Css.hsla 210 0.40 0.98 1

primaryBackgroundColor : Css.Color
primaryBackgroundColor =
    Css.rgba 0 173 216 1

primaryHoverBackgroundColor : Css.Color
primaryHoverBackgroundColor =
    Css.rgba 13 75 115 1

editOrViewButton : Mode -> Html Msg
editOrViewButton mode =
    let
        bStyle =
            Css.batch
                [ buttonStyle
                , borderStyle
                , Css.color primaryForegroundColor
                , Css.backgroundColor primaryBackgroundColor
                , Css.hover [ Css.backgroundColor primaryHoverBackgroundColor ]
                ]
    in
    case mode of
        Edit ->
            div [ onClick Visualize, css [ bStyle ] ] [
                (Svg.svg
                    [ SvgAttr.width "16"
                    , SvgAttr.height "16"
                    , SvgAttr.viewBox "0 0 24 24"
                    , SvgAttr.fill "none"
                    , SvgAttr.stroke "currentColor"
                    , SvgAttr.strokeWidth "2"
                    , SvgAttr.strokeLinecap "round"
                    , SvgAttr.strokeLinejoin "round"
                    ]
                    [ Svg.polygon [ SvgAttr.points "6 3 20 12 6 21 6 3" ] []
                    ]
                ) |> Html.Styled.fromUnstyled
                , text "Visualize Code Execution"
            ]

        View ->
            div [ onClick EditCode, css [ bStyle ] ] [
                (Svg.svg
                    [ SvgAttr.width "16"
                    , SvgAttr.height "16"
                    , SvgAttr.viewBox "0 0 24 24"
                    , SvgAttr.fill "none"
                    , SvgAttr.stroke "currentColor"
                    , SvgAttr.strokeWidth "2"
                    , SvgAttr.strokeLinecap "round"
                    , SvgAttr.strokeLinejoin "round"
                    ]
                    [ Svg.path
                        [ SvgAttr.d "M12 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"
                        ]
                        []
                    , Svg.path
                        [ SvgAttr.d "M18.375 2.625a1 1 0 0 1 3 3l-9.013 9.014a2 2 0 0 1-.853.505l-2.873.84a.5.5 0 0 1-.62-.62l.84-2.873a2 2 0 0 1 .506-.852z"
                        ]
                        []
                    ]
                 ) |> Html.Styled.fromUnstyled
                , text "Edit Code"
            ]

        WaitingSteps ->
            p [ css [ Css.marginTop (Css.px 10), Css.marginBottom (Css.px 0) ] ] [ text "Waiting for execution steps... ⏳" ]

        WaitingSourceCode ->
            p [ css [ Css.marginTop (Css.px 10), Css.marginBottom (Css.px 0) ] ] [ text "Waiting for source code... ⏳" ]


varView : Config -> Variable -> Html msg
varView config v =
    case v of
        VariableI var ->
            let
                value =
                    case var.type_ of
                        "string" ->
                            "\"" ++ var.value ++ "\""

                        _ ->
                            var.value

                children =
                    if String.startsWith "[]" var.type_ then
                        var.children
                            |> List.indexedMap
                                (\i child ->
                                    case child of
                                        VariableI vI ->
                                            VariableI { vI | name = "[" ++ String.fromInt i ++ "]" ++ vI.name }
                                )

                    else
                        if config.showOnlyExportedFields then
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
            in
            li []
                [ details []
                    [ summary
                        [ if List.isEmpty children then
                            css [ Css.listStyle Css.none ]

                          else
                            css []
                        ]
                        ([span [ css [ Css.hover [ Tw.cursor_pointer ] ] ] [ text <| removeMainPrefix var.name ++ " = "]
                         , span [ css [ Tw.text_color Tw.gray_400 ] ]
                                [ text <| "{" ++ var.type_
                                , if config.showMemoryAddresses then
                                    text <| " | " ++ (var.addr |> Helpers.Hex.intToHex)
                                else
                                    text ""
                                , text "}  "
                                ]

                         , text value
                         ]
                            ++ (if String.startsWith "[]" var.type_ then
                                    [ sub [] [ text <| "len: " ++ String.fromInt var.len ++ ", cap:" ++ String.fromInt var.cap ] ]

                                else
                                    []
                               )
                        )
                    , ul [ css [ Tw.list_none ] ] (List.map (varView config) children)
                    ]
                ]


varsView : Config -> String -> Maybe (List Variable) -> List (Attribute msg) -> Html msg
varsView config title maybeVars attributes =
    case maybeVars of
        Nothing ->
            div [] []

        Just vars ->
            if List.isEmpty vars then
                div [] []

            else
                details (attribute "open" "" :: attributes)
                    [ summary []
                        [ p [ css [ Css.display Css.inline, Tw.text_lg, Css.hover [ Tw.cursor_pointer ] ] ] [ text title ] ]
                    , ul [ css [ Tw.list_none, Tw.ps_5 ] ] (List.map (varView config) vars)
                    ]


programVisualizer : VisualizeState -> Html Msg
programVisualizer state =
    div
        [ css
            [ Css.flex (Css.num 1)
            , Css.paddingTop (Css.px 10)
            , Css.paddingRight (Css.px 10)
            ]
        ]
        [ backendStateView state
        , configView state.config
        , varsView
            state.config
            "Global Variables:"
            (Just state.packageVars)
            [ css [ Css.marginBottom (Css.px 10), Css.hover [ Tw.cursor_pointer ] ] ]
        , goroutinesView
            state.config
            (state.lastStep
                |> Maybe.map .goroutinesData
                |> Maybe.withDefault []
                |> List.filter (\g -> not (List.isEmpty (filterUserFrames g.stacktrace)))
            )
        , programOutputView state.stdout state.stderr state.duration
        ]


programOutputView : String -> String -> String -> Html Msg
programOutputView stdout stderr duration =
    let
        stdoutWithBR =
            String.split "\n" stdout
                |> List.map text
                |> List.intersperse (br [] [])
        stderrWithBR =
            String.split "\n" stderr
                |> List.map text
                |> List.intersperse (br [] [])
    in
    details [ css [ Css.marginTop (Css.px 10) ] ]
        [ summary []
            [ p [ css [ Css.display Css.inline, Css.fontSize (Css.rem 1.3), Css.hover [ Tw.cursor_pointer ] ] ] [ text "Program Output:" ] ]
        , div []
            [ p [ css [ Css.padding4 (Css.px 20) (Css.px 20) (Css.px 5) (Css.px 20), Css.backgroundColor (Css.hex "d9d5cf33") ] ]
                (p [ css [ Tw.text_color (Tw.lime_500), Tw.mb_1 ] ] [ text "Standard Output:" ]
                :: stdoutWithBR
                ++  p [ css [ Tw.text_color (Tw.red_500), Tw.mb_1 ] ] [ text "Standard Error:" ]
                :: stderrWithBR
                ++ [ p [ css [ Tw.text_color (Tw.gray_500), Tw.mb_1 ] ] [ text <| "Execution time: " ++ duration ]
                       , p [ css [ Tw.text_color (Tw.gray_500), Tw.mt_1 ] ] [ text "Output doesn't respect the slider yet." ]
                       ]
                )
            ]
        ]


configView : Config -> Html Msg
configView config =
    div [ css [  Tw.flex, Tw.flex_row, Tw.gap_10 ] ]
        [ p [ css [ Tw.text_lg ] ] [ text "Config:" ]
        , label [ css [ Tw.flex, Tw.items_center, Tw.gap_2 ] ]
            [ input [ type_ "checkbox", onCheck ShowOnlyExportedFields, checked config.showOnlyExportedFields, css [ Tw.cursor_pointer ] ] []
            , text " Show only exported fields"
            ]
        , label [ css [ Tw.flex, Tw.items_center, Tw.gap_2 ] ]
            [ input [ type_ "checkbox", onCheck ShowMemoryAddresses, checked config.showMemoryAddresses, css [ Tw.cursor_pointer ] ] []
            , text " Show memory addresses"
            ]

        ]


goroutinesView : Config -> List GoroutinesData -> Html Msg
goroutinesView config goroutinesData =
    let
        note =
            if List.length goroutinesData >= 100 then
                p [ css [ Tw.text_color Tw.zinc_500, Css.marginBottom (Css.px 5) ] ] [ text "Showing first 100 goroutines only." ]

            else
                div [] []

        goroutines =
            if List.length goroutinesData >= 100 then
                List.take 100 goroutinesData

            else
                goroutinesData
    in
    details [ attribute "open" "", css [ Css.marginTop (Css.px 10) ] ]
        [ summary [css [Tw.mb_5]]
            [ p [ css [ Css.display Css.inline, Css.fontSize (Css.rem 1.3), Css.hover [ Tw.cursor_pointer ] ] ] [
                text <| "Running Goroutines (" ++ String.fromInt (List.length goroutines) ++ ")"
            ] ]
        , note
        , div
            [ css
                [ Css.displayFlex
                , Css.flexDirection Css.row
                , Css.flexWrap Css.wrap
                , Css.property "justify-content" "space-evenly"
                ]
            ]
            (List.map (goroutineView config) goroutines)
        ]


goroutineView : Config -> GoroutinesData -> Html Msg
goroutineView config goroutineData =
    div
        [ css
            [ borderStyle
            , Css.paddingLeft (Css.px 10)
            , Css.paddingRight (Css.px 10)
            , Css.marginBottom (Css.px 10)
            , Tw.relative
            ]
        ]
        [
            img [ src "static/megaphone-gopher.svg", alt "goroutine", css [ Tw.absolute, Tw.w_10, Tw.h_10, Tw.neg_inset_5 ] ] []
            , goroutineInfoView goroutineData
        , stackView config (goroutineData.stacktrace |> filterUserFrames)
        ]


goroutineInfoView : GoroutinesData -> Html msg
goroutineInfoView goroutineData =
    let
        gInfo =
            if goroutineData.goroutine.id == 1 then
                "Main Goroutine #1"

            else
                "Goroutine #" ++ String.fromInt goroutineData.goroutine.id
    in
    div
        [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.alignItems Css.center, Css.marginBottom (Css.px 10) ] ]
        [ p [ css [ Css.fontSize (Css.rem 1.3) ] ] [ text gInfo ] ]


stackView : Config -> List StackFrame -> Html Msg
stackView config stack =
    if List.isEmpty stack then
        div [] []

    else
        details [ attribute "open" "" ]
            [ summary [] [ b [css [ Css.hover [ Tw.cursor_pointer ] ] ] [ text "Stack Frames:" ] ]
            , ul [ css [ Tw.list_none, Tw.ps_0 ] ]
                (case stack of
                    [] ->
                        []

                    first :: rest ->
                        li [] [ frameView config first ]
                            :: List.map
                                (\frame ->
                                    li []
                                        [ div [ css [] ]
                                            [ i
                                                [ css
                                                    [ arrow
                                                    , up
                                                    , Css.position Css.relative
                                                    , Css.left (Css.pct 50)
                                                    ]
                                                ]
                                                []
                                            ]
                                        , frameView config frame
                                        ]
                                )
                                rest
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
            [ frameBorderStyle
            , Tw.bg_color Tw.gray_100
            , Css.marginBottom (Css.px 10)
            , Css.padding (Css.px 10)
            , Tw.max_w_xl
            , Tw.min_w_64
            ]
        , onMouseEnter (Highlight frame.line)
        , onMouseLeave (Unhighlight frame.line)
        ]
        [ div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.alignItems Css.center ] ] [ b [] [ text <| removeMainPrefix frame.function.name ] ]
        , div [ css [ Css.margin3 (Css.px 0) (Css.px 0) (Css.px 3) ] ] [ b [] [ text "Loc: " ], text <| fileName ++ ":" ++ String.fromInt frame.line ]
        , varsView config "arguments:" frame.arguments [ css [ Css.marginBottom (Css.px 10) ] ]
        , varsView config "locals:" frame.locals []
        ]


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


backendStateView : VisualizeState -> Html Msg
backendStateView state =
    let
        message =
            case state.flashMessage of
                Just msg ->
                    msg

                Nothing ->
                    case state.mode of
                        WaitingSteps ->
                            "Waiting for backend to get execution steps... ⏳"

                        _ ->
                            case state.lastStep of
                                Nothing ->
                                    "step is empty, try moving the slider, or pressing `Visualize Steps` button"

                                Just _ ->
                                    ""
    in
    case message of
        "" ->
            div [] []

        _ ->
            div
                [ css
                    ([ Css.displayFlex
                     , Css.flexDirection Css.column
                     , Css.alignItems Css.center
                     , Css.marginBottom (Css.px 10)
                     , Css.padding2 (Css.px 0) (Css.px 15)
                     , borderStyle
                     ]
                        ++ (case state.flashMessage of
                                Just _ ->
                                    [ Tw.bg_color Tw.red_300 ]

                                Nothing ->
                                    []
                           )
                    )
                ]
                [ p [ css [ Css.fontSize (Css.rem 1.5) ] ] [ text message ]
                , case state.flashMessage of
                    Just _ ->
                        div [ css [ Tw.mt_3 ] ]
                            [ div [ onClick FixCodeWithAI, css [ secondaryButtonStyle, borderStyle ] ]
                                [ text "Fix with AI ✨" ]
                            ]
                    Nothing ->
                        div [] []
                ]


exampleSelector : Html Msg
exampleSelector =
    select
        [ css
            [ Css.fontSize (Css.rem 0.9)
            , Tw.bg_color Tw.slate_50
            , borderStyle
            , Tw.py_1
            , Tw.rounded_md
            ]
        , onInput ExampleSelected
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


borderStyle : Css.Style
borderStyle =
    Css.batch
        [ Tw.border_color Tw.gray_300
        , Tw.border
        , Tw.border_solid
        ]


frameBorderStyle : Css.Style
frameBorderStyle =
    Css.batch
        [ Tw.border_color Tw.gray_300
        , Tw.border
        , Tw.border_solid
        , Tw.rounded_md
        ]

secondaryButtonStyle : Css.Style
secondaryButtonStyle =
    Css.batch
        [ buttonStyle
        , Css.backgroundColor secondaryBackgroundColor
        , Css.hover [ Css.backgroundColor secondaryBackgroundColorHover ]
        ]

buttonStyle : Css.Style
buttonStyle =
    Css.batch
        [ Tw.inline_flex
        , Tw.items_center
        , Tw.justify_center
        , Tw.gap_2
        , Tw.whitespace_nowrap
        , Tw.text_sm
        , Tw.font_medium
        , Tw.transition_colors
        , Tw.h_9
        , Tw.rounded_md
        , Tw.px_3
        , Css.hover [ Tw.cursor_pointer ]
        ]


arrow : Css.Style
arrow =
    Css.batch
        [ Css.border3 (Css.px 0) Css.solid (Css.hex "979494")
        , Css.borderWidth4 (Css.px 0) (Css.px 3) (Css.px 3) (Css.px 0)
        , Css.display Css.inlineBlock
        , Css.padding (Css.px 3)
        ]


up : Css.Style
up =
    Css.batch
        [ Css.transform (Css.rotate (Css.deg -135))
        ]
