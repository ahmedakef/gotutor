module Steps.View exposing (..)

import Css
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick)
import Steps.Decoder exposing (..)
import Steps.Steps as Steps
import Styles


view : Steps.State -> Html Steps.Msg
view state =
    case state of
        Steps.Success stepsState ->
            div []
                [ div [ css [ Styles.container ] ]
                    [ div [ css [ Styles.flexColumn ] ]
                        [ h1 [] [ text "Steps of your Go Program:" ]
                        ]
                    ]
                , div [ css [ Styles.container ] ]
                    [ div [ css [ Styles.flexColumn, Styles.flexCenter ] ]
                        [ div []
                            [ codeView stepsState.sourceCode
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
                        [ let
                            visualizeState =
                                stateToVisualize stepsState
                          in
                          programVisualizer visualizeState
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

                _ =
                    stepsSoFar |> Debug.toString |> Debug.log "Just stepsSoFar"
            in
            VisualizeState (Just step) callHierarchy packageVars

        Nothing ->
            -- This should never happen, try to remove this case
            VisualizeState lastStep [] []


codeView : String -> Html msg
codeView sourceCode =
    let
        linesNumber =
            sourceCode
                |> String.split "\n"
                |> List.length
    in
    div [ css [ Css.displayFlex ] ]
        [ div [ css [ Styles.codeBlock, Css.color (Css.hex "78909C") ] ]
            (List.indexedMap (\i _ -> div [] [ text (String.fromInt (i + 1)) ]) (List.repeat linesNumber ()))
        , div [ css [ Styles.codeBlock ] ]
            [ pre [ css [ Css.margin (Css.px 0) ] ]
                [ code [] [ text sourceCode ]
                ]
            ]
        ]


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
    ul [] (List.map frameView stack)


frameView : StackFrame -> Html msg
frameView frame =
    div [ css borderStyle ]
        [ div [] [ text <| frame.function.name ]
        , hr [] []
        , div [] [ text <| "File: " ++ frame.file ]
        , div [] [ text <| "Line: " ++ String.fromInt frame.line ]
        , div [] [ text <| "PC: " ++ String.fromInt frame.pc ]
        ]


goroutineView : Maybe Step -> Html msg
goroutineView maybeStep =
    case maybeStep of
        Nothing ->
            div [] []

        Just step ->
            div [] [ text <| "Goroutine ID: " ++ String.fromInt step.goroutine.id ]


borderStyle : List Css.Style
borderStyle =
    [ Css.border3 (Css.px 1) Css.solid (Css.hex "ccc")
    , Css.padding (Css.px 10)
    , Css.margin3 (Css.px 0) (Css.px 0) (Css.px 10)
    ]
