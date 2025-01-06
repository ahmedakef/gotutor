module Steps.View exposing (..)

import Css
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
                                    [ button [ onClick Prev ] [ text "Prev" ]
                                    , button [ onClick Next ] [ text "Next" ]
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

        _ =
            Debug.toString currentLine |> Debug.log "currentLine"

        _ =
            Debug.toString highlightModeCurrentLine |> Debug.log "highlightModeCurrentLine"

        _ =
            Debug.toString highlightedLine |> Debug.log "highlightedLine"

        _ =
            Debug.toString highlightModeHighlightedLine |> Debug.log "highlightModeHighlightedLine"
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


packageVarsView : List Variable -> Html msg
packageVarsView packageVars =
    if List.isEmpty packageVars then
        div [] []

    else
        div []
            [ h2 []
                [ text "Package Variables"
                ]
            , div [] (List.map packageVarView packageVars)
            ]


packageVarView : Variable -> Html msg
packageVarView packageVar =
    div []
        [ div [] [ text ("Name: " ++ packageVar.name) ]
        , div [] [ text ("Type: " ++ packageVar.type_) ]
        , div [] [ text ("Value: " ++ packageVar.value) ]
        ]


programVisualizer : VisualizeState -> Html Msg
programVisualizer state =
    div []
        [ packageVarsView state.packageVars
        , goroutineView state.lastStep
        , stackView state.stack
        ]


stackView : List StackFrame -> Html Msg
stackView stack =
    if List.isEmpty stack then
        div [] []

    else
        div []
            [ h2 []
                [ text "Stacktrace"
                ]
            , ul [] (List.map frameView stack)
            ]


frameView : StackFrame -> Html Msg
frameView frame =
    div [ css borderStyle, onMouseEnter (Highlight frame.line), onMouseLeave (Unhighlight frame.line) ]
        [ div [] [ text <| frame.function.name ]
        , hr [] []
        , div [] [ text <| "File: " ++ frame.file ]
        , div [] [ text <| "Line: " ++ String.fromInt frame.line ]
        ]


goroutineView : Maybe Step -> Html msg
goroutineView maybeStep =
    case maybeStep of
        Nothing ->
            div [] []

        Just step ->
            div []
                [ h2 []
                    [ text "goroutine Info"
                    ]
                , div []
                    [ text <|
                        "Goroutine ID: "
                            ++ String.fromInt step.goroutine.id
                    ]
                ]


borderStyle : List Css.Style
borderStyle =
    [ Css.border3 (Css.px 1) Css.solid (Css.hex "ccc")
    , Css.padding (Css.px 10)
    , Css.margin3 (Css.px 0) (Css.px 0) (Css.px 10)
    ]
