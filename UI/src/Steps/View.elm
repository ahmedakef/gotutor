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
                            , div [ css [ Styles.flexCenter ] ]
                                [ div []
                                    [ button [ onClick Steps.Prev ] [ text "Prev" ]
                                    , button [ onClick Steps.Next ] [ text "Next" ]
                                    ]
                                , div []
                                    [ text ("Step " ++ String.fromInt stepsState.position ++ " of " ++ (List.length stepsState.steps |> String.fromInt))
                                    ]
                                ]
                            ]
                        ]
                    , div [ css [ Styles.flexColumn ] ]
                        [ let
                            ( stepsSoFar, packageVars ) =
                                stateToVisualize stepsState
                          in
                          programVisualizer stepsSoFar packageVars
                        ]
                    ]
                ]

        Steps.Failure error ->
            div [] [ text error ]

        Steps.Loading ->
            div [] [ text "Loading..." ]


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


packageVarsView : List PackageVariable -> Html msg
packageVarsView packageVars =
    div []
        (List.map packageVarView packageVars)


packageVarView : PackageVariable -> Html msg
packageVarView packageVar =
    div [] [ text packageVar.name ]


stateToVisualize : Steps.StepsState -> ( List Step, List PackageVariable )
stateToVisualize stepsState =
    let
        stepsSoFar =
            stepsState.steps
                |> List.take stepsState.position

        lastStep =
            stepsState.steps
                |> List.drop stepsState.position
                |> List.head
    in
    case lastStep of
        Just step ->
            let
                packageVars =
                    step.packageVars
            in
            ( stepsSoFar, packageVars )

        Nothing ->
            -- This should never happen, try to remove this case
            ( stepsSoFar, [] )


programVisualizer : List Step -> List PackageVariable -> Html msg
programVisualizer steps packageVars =
    div []
        [ packageVarsView packageVars
        , stepsListView steps
        ]


stepsListView : List Step -> Html msg
stepsListView steps =
    ul [] (List.map stepView steps)


stepView : Step -> Html msg
stepView step =
    div [ css borderStyle ]
        [ div [] [ text <| step.goroutine.currentLoc.function.name ]
        , hr [] []
        , div [] [ text <| "Goroutine ID: " ++ String.fromInt step.goroutine.id ]
        , div [] [ text <| "File: " ++ step.goroutine.currentLoc.file ]
        , div [] [ text <| "Line: " ++ String.fromInt step.goroutine.currentLoc.line ]
        , div [] [ text <| "PC: " ++ String.fromInt step.goroutine.currentLoc.pc ]
        ]


borderStyle : List Css.Style
borderStyle =
    [ Css.border3 (Css.px 1) Css.solid (Css.hex "ccc")
    , Css.padding (Css.px 10)
    , Css.margin3 (Css.px 0) (Css.px 0) (Css.px 10)
    ]
