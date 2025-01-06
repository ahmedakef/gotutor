module Steps.View exposing (..)

import Css
import Html as UnSytyled
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick)
import Steps.Decoder exposing (..)
import Steps.Steps as Steps
import Styles
import SyntaxHighlight as SH


view : Steps.State -> Html Steps.Msg
view state =
    case state of
        Steps.Success stepsState ->
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
                                    [ button [ onClick Steps.Prev ] [ text "Prev" ]
                                    , button [ onClick Steps.Next ] [ text "Next" ]
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

        Steps.Failure error ->
            div [] [ pre [] [ text error ] ]

        Steps.Loading ->
            div [] [ text "Loading..." ]


type alias VisualizeState =
    { lastStep : Maybe Step
    , stack : List StackFrame
    , packageVars : List Variable
    , sourceCode : String
    , currentLine : Maybe Int
    }


stateToVisualize : Steps.StepsState -> VisualizeState
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

                _ =
                    stepsSoFar |> Debug.toString |> Debug.log "Just stepsSoFar"
            in
            VisualizeState (Just step) callHierarchy packageVars stepsState.sourceCode currentLine

        Nothing ->
            VisualizeState lastStep [] [] stepsState.sourceCode Nothing


filterUserFrames : List StackFrame -> List StackFrame
filterUserFrames stack =
    stack
        |> List.filter (\frame -> String.endsWith "main.go" frame.file)


codeView : VisualizeState -> Html msg
codeView state =
    let
        highlightMode =
            Maybe.map (\_ -> SH.Add) state.lastStep

        currentLine =
            Maybe.withDefault 0 state.currentLine

        _ =
            Debug.toString currentLine |> Debug.log "currentLine"

        _ =
            Debug.toString highlightMode |> Debug.log "highlightMode"
    in
    div
        []
        [ SH.noLang state.sourceCode
            |> Result.map (SH.highlightLines highlightMode (currentLine - 1) currentLine)
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


programVisualizer : VisualizeState -> Html msg
programVisualizer state =
    div []
        [ packageVarsView state.packageVars
        , goroutineView state.lastStep
        , stackView state.stack
        ]


stackView : List StackFrame -> Html msg
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


frameView : StackFrame -> Html msg
frameView frame =
    div [ css borderStyle ]
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
