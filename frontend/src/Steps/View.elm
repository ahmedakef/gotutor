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
import SyntaxHighlight.SyntaxHighlight as SH
import Tailwind.Theme as Tw
import Tailwind.Utilities as Tw


view : State -> Html Msg
view state =
    case state of
        Success stepsState ->
            let
                visualizeState =
                    stateToVisualize stepsState
            in
            main_ [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.flex (Css.num 1), Css.paddingTop (Css.vh 2) ] ]
                [ div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.alignItems Css.center, Css.paddingBottom (Css.px 20) ] ]
                    [ div [ css [ Css.displayFlex ] ]
                        [ img [ height 70, src "static/gopher.png", alt "github logo" ] []
                        , h1 [ css [ Css.fontSize (Css.rem 1.7) ] ] [ text "An online graphical debugging tool to visualize Go" ]
                        ]
                    , p [] [ text "It shows the state of all the running Goroutines, the state of each stack frame and can go back in time." ]
                    ]
                , div [ css [ Tw.flex, Tw.flex_wrap, Tw.flex_1 ] ]
                    [ div [ css [ Tw.flex, Tw.flex_col, Tw.items_center, Tw.flex_1, Tw.pb_4 ] ]
                        [ div [ css [ Tw.flex, Tw.flex_col, Tw.items_center, Tw.w_3over4 ] ]
                            [ div [ css [ Tw.flex, Tw.flex_row, Tw.self_stretch, Tw.self_end, Tw.gap_2 ] ]
                                [ case stepsState.shareUrl of
                                    Just url ->
                                        input [ type_ "text", value url, css [ Tw.w_56 ] ] []
                                    Nothing ->
                                        input [ type_ "text", hidden True ] []
                                , button [ onClick Share, css [ buttonStyle ] ] [ text "Share" ]
                                , button [ onClick Fmt, css [ buttonStyle ] ] [ text "Format" ]
                                , exampleSelector
                                ],
                                p [ css [ Tw.mt_1 ] ] [ text "Press Edit Code or select an example to visualize" ]
                            ]
                            , codeView visualizeState
                            , editOrViewButton visualizeState.mode
                            , div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.alignItems Css.center, Css.marginTop (Css.px 10) ] ]
                                [ div []
                                    [ div [ css [ Tw.pb_4 ] ]
                                        [ input
                                            [ type_ "range"
                                            , Html.Styled.Attributes.min "1"
                                            , Html.Styled.Attributes.max (String.fromInt (List.length stepsState.executionResponse.steps))
                                            , Html.Styled.Attributes.value (String.fromInt stepsState.position)
                                            , onInput (String.toInt >> Maybe.withDefault 1 >> SliderChange)
                                            ]
                                            []
                                        ]
                                    , button [ onClick Prev, css [ buttonStyle, Tw.mr_4 ] ] [ text "< Prev" ]
                                    , button [ onClick Next, css [ buttonStyle, Tw.ml_4 ] ] [ text "Next >" ]
                                    ]
                                , div [ css [ Css.margin2 (Css.px 10) (Css.px 0) ] ]
                                    [ text ("Step " ++ String.fromInt stepsState.position ++ " of " ++ (List.length stepsState.executionResponse.steps |> String.fromInt))
                                    ]
                                ]
                        ]
                    , programVisualizer visualizeState
                    ]
                ]

        Failure error ->
            main_ [ css [ Css.flex (Css.num 1), Css.displayFlex, Css.justifyContent Css.spaceBetween, Css.alignItems Css.center ] ]
                [ pre [ css [ Css.color (Css.hex "#d65287"), Css.fontSize (Css.px 20) ] ] [ text error ]
                ]

        Loading ->
            main_ [ css [ Css.flex (Css.num 1), Css.displayFlex, Css.justifyContent Css.spaceBetween, Css.alignItems Css.center ] ]
                [ pre [ css [ Css.fontSize (Css.px 20) ] ] [ text "Loading..." ]
                ]


type alias VisualizeState =
    { lastStep : Maybe Step
    , output : String
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
            , output = stepsState.executionResponse.output
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
            VisualizeState lastStep "" "" [] stepsState.sourceCode stepsState.scroll Nothing Nothing stepsState.mode stepsState.errorMessage stepsState.config


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
                    Css.backgroundColor (Css.hex "ffffddf7")

                _ ->
                    Css.backgroundColor (Css.hex "ffffff")
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


editOrViewButton : Mode -> Html Msg
editOrViewButton mode =
    let
        bStyle =
            Css.batch
                [ buttonStyle
                , Css.marginTop (Css.px 10)
                , Css.width (Css.rem 20)
                , Css.height (Css.rem 3)
                ]
    in
    case mode of
        Edit ->
            button [ onClick Visualize, css [ bStyle ] ] [ text "Visualize Steps" ]

        View ->
            button [ onClick EditCode, css [ bStyle ] ] [ text "Edit Code" ]

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
                        ([ text <| removeMainPrefix var.name ++ " = "
                         , span [ css [ Css.color (Css.hex "979494") ] ]
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
                    , ul [ css [ Css.listStyleType Css.none ] ] (List.map (varView config) children)
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
                        [ p [ css [ Css.display Css.inline, Css.fontSize (Css.rem 1.3) ] ] [ text title ] ]
                    , ul [ css [ Css.listStyleType Css.none ] ] (List.map (varView config) vars)
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
            [ css [ Css.marginBottom (Css.px 10) ] ]
        , goroutinesView
            state.config
            (state.lastStep
                |> Maybe.map .goroutinesData
                |> Maybe.withDefault []
                |> List.filter (\g -> not (List.isEmpty (filterUserFrames g.stacktrace)))
            )
        , programOutputView state.output state.duration
        ]


programOutputView : String -> String -> Html Msg
programOutputView output duration =
    let
        outputWithBR =
            String.split "\n" output
                |> List.map text
                |> List.intersperse (br [] [])
    in
    details [ css [ Css.marginTop (Css.px 10) ] ]
        [ summary []
            [ p [ css [ Css.display Css.inline, Css.fontSize (Css.rem 1.3) ] ] [ text "Program Output:" ] ]
        , div []
            [ p [ css [ Css.padding4 (Css.px 20) (Css.px 20) (Css.px 5) (Css.px 20), Css.backgroundColor (Css.hex "d9d5cf33") ] ]
                (outputWithBR
                    ++ [ p [ css [ Css.color (Css.hex "6e7072"), Css.marginBottom (Css.px 5) ] ] [ text <| "Execution time: " ++ duration ]
                       , p [ css [ Css.color (Css.hex "6e7072"), Css.marginTop (Css.px 5) ] ] [ text "Output doesn't respect the slider yet." ]
                       ]
                )
            ]
        ]


configView : Config -> Html Msg
configView config =
    div [ css [  Tw.flex, Tw.flex_row, Tw.gap_10 ] ]
        [ p [ css [ Tw.text_lg ] ] [ text "Config:" ]
        , label [ css [ Tw.flex, Tw.items_center, Tw.gap_2 ] ]
            [ input [ type_ "checkbox", onCheck ShowOnlyExportedFields, checked config.showOnlyExportedFields ] []
            , text " Show only exported fields"
            ]
        , label [ css [ Tw.flex, Tw.items_center, Tw.gap_2 ] ]
            [ input [ type_ "checkbox", onCheck ShowMemoryAddresses, checked config.showMemoryAddresses ] []
            , text " Show memory addresses"
            ]

        ]


goroutinesView : Config -> List GoroutinesData -> Html Msg
goroutinesView config goroutinesData =
    let
        note =
            if List.length goroutinesData >= 100 then
                p [ css [ Css.color (Css.hex "6e7072"), Css.marginBottom (Css.px 5) ] ] [ text "Showing first 100 goroutines only." ]

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
            [ p [ css [ Css.display Css.inline, Css.fontSize (Css.rem 1.3) ] ] [ text "Running Goroutines:" ] ]
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
                "Main Goroutine: 1"

            else
                "Goroutine: " ++ String.fromInt goroutineData.goroutine.id
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
            [ summary [] [ b [] [ text "Stack Frames:" ] ]
            , ul [ css [ Css.listStyleType Css.none ] ]
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
            , Css.backgroundColor (Css.hex "f2f0ec")
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
                                    [ Css.backgroundColor (Css.hex "f5c6cb") ]

                                Nothing ->
                                    []
                           )
                    )
                ]
                [ p [ css [ Css.fontSize (Css.rem 1.5) ] ] [ text message ] ]


exampleSelector : Html Msg
exampleSelector =
    select
        [ css
            [ Css.fontSize (Css.rem 0.9)
            , Css.backgroundColor (Css.hex "fff")
            , Css.border3 (Css.px 1) Css.solid (Css.hex "ddd")
            , Css.padding (Css.px 1)
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
        [ Css.border3 (Css.px 1) Css.solid (Css.hex "ddd")
        , Css.borderRadius (Css.px 3)
        ]


frameBorderStyle : Css.Style
frameBorderStyle =
    Css.batch
        [ Css.border3 (Css.px 1) Css.solid (Css.hex "ccc")
        , Css.padding (Css.px 10)
        , Css.marginBottom (Css.px 10)
        , Css.borderRadius (Css.px 7)
        ]


buttonStyle : Css.Style
buttonStyle =
    Css.batch
        [ Css.backgroundColor (Css.hex "f2f0ec")
        , Css.border3 (Css.px 1) Css.solid (Css.hex "ccc")
        , Css.padding (Css.px 5)
        , Css.hover [ Css.backgroundColor (Css.hex "e0e0e0") ]
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
