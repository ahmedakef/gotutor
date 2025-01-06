module Steps.View exposing (..)

import Char
import Css
import Css.Global exposing (children)
import Html as UnSytyled
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (..)
import Steps.Decoder exposing (..)
import Steps.Steps exposing (..)
import Styles
import SyntaxHighlight as SH


view : State -> Html Msg
view state =
    case state of
        Success stepsState ->
            let
                visualizeState =
                    stateToVisualize stepsState
            in
            div []
                [ div [ css [ Styles.container ] ]
                    [ div [ css [ Styles.flexColumn ] ]
                        [ h1 [] [ text "Steps of your Go Program:" ]
                        ]
                    ]
                , div [ css [ Styles.container ] ]
                    [ div [ css [ Styles.flexColumn, Styles.flexCenter ] ]
                        [ div []
                            [ codeView visualizeState
                            , div [ css [ Styles.flexCenter, Css.margin2 (Css.px 20) (Css.px 0) ] ]
                                [ div []
                                    [ div []
                                        [ input
                                            [ type_ "range"
                                            , Html.Styled.Attributes.min "0"
                                            , Html.Styled.Attributes.max (String.fromInt (List.length stepsState.steps))
                                            , Html.Styled.Attributes.value (String.fromInt stepsState.position)
                                            , onInput (String.toInt >> Maybe.withDefault 0 >> SliderChange)
                                            ]
                                            []
                                        ]
                                    , button [ onClick Prev, css [ buttonStyle, Css.margin4 (Css.px 0) (Css.px 10) (Css.px 0) (Css.px 0) ] ] [ text "< Prev" ]
                                    , button [ onClick Next, css [ buttonStyle ] ] [ text "Next >" ]
                                    ]
                                , div [ css [ Css.margin2 (Css.px 10) (Css.px 0) ] ]
                                    [ text ("Step " ++ String.fromInt stepsState.position ++ " of " ++ (List.length stepsState.steps |> String.fromInt))
                                    ]
                                ]
                            ]
                        ]
                    , div [ css [ Styles.flexColumn ] ]
                        [ programVisualizer visualizeState
                        ]
                    ]
                ]

        Failure error ->
            div [] [ pre [] [ text error ] ]

        Loading ->
            div [] [ text "Loading..." ]


type alias VisualizeState =
    { lastStep : Maybe Step
    , stack : List StackFrame
    , packageVars : List Variable
    , sourceCode : String
    , currentLine : Maybe Int
    , highlightedLine : Maybe Int
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
            , currentLine = currentLine
            , highlightedLine = stepsState.highlightedLine
            }

        Nothing ->
            VisualizeState lastStep [] [] stepsState.sourceCode Nothing Nothing


filterUserFrames : List StackFrame -> List StackFrame
filterUserFrames stack =
    stack
        |> List.filter (\frame -> String.endsWith "main.go" frame.file)


codeView : VisualizeState -> Html msg
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
    div
        []
        [ SH.noLang state.sourceCode
            |> Result.map (SH.highlightLines highlightModeHighlightedLine (highlightedLine - 1) highlightedLine)
            |> Result.map (SH.highlightLines highlightModeCurrentLine (currentLine - 1) currentLine)
            |> Result.map (SH.toBlockHtml (Just 1))
            |> Result.withDefault
                (UnSytyled.pre [] [ UnSytyled.code [] [ UnSytyled.text state.sourceCode ] ])
            |> Html.Styled.fromUnstyled
        ]


wrapCode : String -> String
wrapCode code =
    "```go\n" ++ code ++ "\n```"


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
                    [ summary []
                        [ text <| var.name ++ " = "
                        , span [ css [ Css.color (Css.hex "979494") ] ] [ text <| "{" ++ var.type_ ++ "}  " ]
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
    div []
        [ varsView "Global Variables:" (Just state.packageVars) [ css [ Styles.marginBottom 10 ] ]
        , goroutineView state.lastStep
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
                    [ text "Stacktrace"
                    ]
                ]
            , ul [ css [ Css.listStyleType Css.none ] ]
                (List.map frameView stack
                    |> List.map (\element -> li [] [ element ])
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
            [ borderStyle
            , Css.width (Css.pct 50)
            , Css.backgroundColor (Css.hex "f2f0ec")
            ]
        , onMouseEnter (Highlight frame.line)
        , onMouseLeave (Unhighlight frame.line)
        ]
        [ div [ css [ Styles.flexCenter ] ] [ b [] [ text <| removeMainPrefix frame.function.name ] ]
        , div [ css [ Css.margin3 (Css.px 0) (Css.px 0) (Css.px 10) ] ] [ b [] [ text "Loc: " ], text <| fileName ++ ":" ++ String.fromInt frame.line ]
        , varsView "arguments:" frame.arguments [ css [ Styles.marginBottom 10 ] ]
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


goroutineView : Maybe Step -> Html msg
goroutineView maybeStep =
    case maybeStep of
        Nothing ->
            div [] []

        Just step ->
            details [ attribute "open" "", css [ Css.margin3 (Css.px 0) (Css.px 0) (Css.px 10) ] ]
                [ summary []
                    [ b [] [ text "Goroutine Info:" ]
                    ]
                , div [ css [ Css.margin3 (Css.px 10) (Css.px 0) (Css.px 0) ] ]
                    [ ul [ css [ Css.listStyleType Css.none ] ]
                        [ li []
                            [ text <| "ID: " ++ String.fromInt step.goroutine.id
                            ]
                        ]
                    ]
                ]


borderStyle : Css.Style
borderStyle =
    Css.batch
        [ Css.border3 (Css.px 1) Css.solid (Css.hex "ccc")
        , Css.padding (Css.px 10)
        , Css.margin3 (Css.px 0) (Css.px 0) (Css.px 10)
        , Css.borderRadius (Css.px 15)
        ]


buttonStyle : Css.Style
buttonStyle =
    Css.batch
        [ Css.backgroundColor (Css.hex "f2f0ec")
        , Css.border3 (Css.px 1) Css.solid (Css.hex "ccc")
        , Css.padding (Css.px 5)
        ]
