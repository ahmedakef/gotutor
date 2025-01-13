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


view : State -> Html Msg
view state =
    case state of
        Success stepsState ->
            let
                visualizeState =
                    stateToVisualize stepsState
            in
            main_ [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.flex (Css.num 1), Css.paddingTop (Css.vh 5) ] ]
                [ div [ css [ Css.paddingLeft (Css.px 10) ] ] [ h1 [] [ text "Visualize your Go Program:" ] ]
                , div [ css [ Css.displayFlex, Css.flex (Css.num 1) ] ]
                    [ div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.alignItems Css.center, Css.flex (Css.num 1) ] ]
                        [ codeView visualizeState
                        , editOrViewButton visualizeState.mode
                        , div [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.alignItems Css.center, Css.marginTop (Css.px 10) ] ]
                            [ div []
                                [ div []
                                    [ input
                                        [ type_ "range"
                                        , Html.Styled.Attributes.min "1"
                                        , Html.Styled.Attributes.max (String.fromInt (List.length stepsState.steps))
                                        , Html.Styled.Attributes.value (String.fromInt stepsState.position)
                                        , onInput (String.toInt >> Maybe.withDefault 1 >> SliderChange)
                                        ]
                                        []
                                    ]
                                , button [ onClick Prev, css [ buttonStyle, Css.marginRight (Css.px 10) ] ] [ text "< Prev" ]
                                , button [ onClick Next, css [ buttonStyle, Css.marginLeft (Css.px 10) ] ] [ text "Next >" ]
                                ]
                            , div [ css [ Css.margin2 (Css.px 10) (Css.px 0) ] ]
                                [ text ("Step " ++ String.fromInt stepsState.position ++ " of " ++ (List.length stepsState.steps |> String.fromInt))
                                ]
                            ]
                        ]
                    , div [ css [ Css.displayFlex, Css.flex (Css.num 1), Css.flexDirection Css.column, Css.alignItems Css.center ] ]
                        [ programVisualizer visualizeState
                        ]
                    ]
                ]

        Failure error ->
            main_ [ css [ Css.flex (Css.num 1), Css.displayFlex, Css.justifyContent Css.center, Css.alignItems Css.center ] ]
                [ pre [ css [ Css.color (Css.hex "#d65287"), Css.fontSize (Css.px 20) ] ] [ text error ]
                ]

        Loading ->
            main_ [ css [ Css.flex (Css.num 1), Css.displayFlex, Css.justifyContent Css.center, Css.alignItems Css.center ] ]
                [ pre [ css [ Css.fontSize (Css.px 20) ] ] [ text "Loading..." ]
                ]


type alias VisualizeState =
    { lastStep : Maybe Step
    , stack : List StackFrame
    , packageVars : List Variable
    , sourceCode : String
    , scroll : Scroll
    , currentLine : Maybe Int
    , highlightedLine : Maybe Int
    , mode : Mode
    , flashMessage : Maybe String
    }


stateToVisualize : StepsState -> VisualizeState
stateToVisualize stepsState =
    let
        stepsSoFar =
            stepsState.steps
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

                callHierarchy =
                    step.stacktrace
                        |> filterUserFrames

                currentLine =
                    List.head callHierarchy
                        |> Maybe.map .line
            in
            { lastStep = Just step
            , stack = callHierarchy
            , packageVars = packageVars
            , sourceCode = stepsState.sourceCode
            , scroll = stepsState.scroll
            , currentLine = currentLine
            , highlightedLine = stepsState.highlightedLine
            , mode = stepsState.mode
            , flashMessage = stepsState.errorMessage
            }

        Nothing ->
            VisualizeState lastStep [] [] stepsState.sourceCode stepsState.scroll Nothing Nothing stepsState.mode stepsState.errorMessage


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

        highlightModeCurrentLine =
            Maybe.map (\_ -> SH.Add) state.lastStep

        highlightModeHighlightedLine =
            if highlightedLine == currentLine then
                Nothing

            else
                Maybe.map (\_ -> SH.Highlight) state.highlightedLine
    in
    div [ css [ borderStyle ], class "code-container" ]
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
                    SH.noLang state.sourceCode
                        |> Result.map (SH.highlightLines highlightModeHighlightedLine (highlightedLine - 1) highlightedLine)
                        |> Result.map (SH.highlightLines highlightModeCurrentLine (currentLine - 1) currentLine)
                        |> Result.map (SH.toBlockHtml (Just 1))
                        |> Result.withDefault
                            (UnSytyled.pre [] [ UnSytyled.code [ Html.Attributes.class "elmsh" ] [ UnSytyled.text state.sourceCode ] ])
                        |> Html.Styled.fromUnstyled

                _ ->
                    SH.noLang state.sourceCode
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
            ]
            []
        ]


wrapCode : String -> String
wrapCode code =
    "```go\n" ++ code ++ "\n```"


editOrViewButton : Mode -> Html Msg
editOrViewButton mode =
    case mode of
        Edit ->
            button [ onClick Visualize, css [ buttonStyle, Css.marginTop (Css.px 10) ] ] [ text "Visualize Steps" ]

        View ->
            button [ onClick EditCode, css [ buttonStyle, Css.marginTop (Css.px 10) ] ] [ text "Edit Code" ]

        WaitingSteps ->
            p [ css [ Css.marginTop (Css.px 10), Css.marginBottom (Css.px 0) ] ] [ text "Waiting for execution steps... ⏳" ]


varView : Variable -> Html msg
varView v =
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
            in
            li []
                [ details []
                    [ summary
                        [ if List.isEmpty children then
                            css [ Css.listStyle Css.none ]

                          else
                            css []
                        ]
                        [ text <| removeMainPrefix var.name ++ " = "
                        , span [ css [ Css.color (Css.hex "979494") ] ]
                            [ text <| "{" ++ var.type_ ++ " | " ++ (var.addr |> Helpers.Hex.intToHex |> String.slice 0 8) ++ "}  "
                            ]
                        , text value
                        ]
                    , ul [ css [ Css.listStyleType Css.none ] ] (List.map varView children)
                    ]
                ]


varsView : String -> Maybe (List Variable) -> List (Attribute msg) -> Html msg
varsView title maybeVars attributes =
    case maybeVars of
        Nothing ->
            div [] []

        Just vars ->
            if List.isEmpty vars then
                div [] []

            else
                details (attribute "open" "" :: attributes)
                    [ summary []
                        [ b [] [ text title ]
                        ]
                    , ul [ css [ Css.listStyleType Css.none ] ] (List.map varView vars)
                    ]


programVisualizer : VisualizeState -> Html Msg
programVisualizer state =
    div
        [ css
            ([ borderStyle, Css.padding2 (Css.px 10) (Css.px 50), Css.width (Css.pct 80) ]
                ++ (case state.flashMessage of
                        Just _ ->
                            [ Css.backgroundColor (Css.hex "f5c6cb") ]

                        Nothing ->
                            []
                   )
            )
        ]
        [ goroutineView state
        , varsView
            "Global Variables:"
            (Just state.packageVars)
            [ css [ Css.marginBottom (Css.px 10) ] ]
        , stackView state.stack
        ]


stackView : List StackFrame -> Html Msg
stackView stack =
    if List.isEmpty stack then
        div [] []

    else
        details [ attribute "open" "" ]
            [ summary []
                [ b []
                    [ text "Stacktrace:"
                    ]
                ]
            , ul [ css [ Css.listStyleType Css.none ] ]
                (List.map frameView stack
                    |> List.indexedMap
                        (\idx element ->
                            li []
                                ((if idx > 0 then
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
                                    ]

                                  else
                                    []
                                 )
                                    ++ [ element ]
                                )
                        )
                )
            ]


frameView : StackFrame -> Html Msg
frameView frame =
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
        , varsView "arguments:" frame.arguments [ css [ Css.marginBottom (Css.px 10) ] ]
        , varsView "locals:" frame.locals []
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


goroutineView : VisualizeState -> Html msg
goroutineView state =
    let
        gInfo =
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
                                    "step is empty, try change the slider"

                                Just step ->
                                    if step.goroutine.id == 1 then
                                        "Main Goroutine"

                                    else
                                        "Goroutine: " ++ String.fromInt step.goroutine.id
    in
    div
        [ css [ Css.displayFlex, Css.flexDirection Css.column, Css.alignItems Css.center, Css.marginBottom (Css.px 10) ] ]
        [ p [ css [ Css.fontSize (Css.rem 1.5) ] ] [ text gInfo ] ]


borderStyle : Css.Style
borderStyle =
    Css.batch
        [ Css.border3 (Css.px 1) Css.solid (Css.hex "ddd")
        , Css.borderRadius (Css.px 5)
        ]


frameBorderStyle : Css.Style
frameBorderStyle =
    Css.batch
        [ Css.border3 (Css.px 1) Css.solid (Css.hex "ccc")
        , Css.padding (Css.px 10)
        , Css.marginBottom (Css.px 10)
        , Css.borderRadius (Css.px 15)
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
