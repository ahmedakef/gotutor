module Steps.View exposing (..)

import Css
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick)
import Steps.Decoder as StepsDecoder
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
                            [ div [css [ Styles.codeBlock ] ]
                                [ pre []
                                    [ code [] [ text stepsState.sourceCode ]
                                    ]
                                ]
                            , div []
                                [ button [ onClick Steps.Prev ] [ text "Prev" ]
                                , button [ onClick Steps.Next ] [ text "Next" ]
                                ]
                            , div [] [ text ("Step " ++ String.fromInt stepsState.position ++ " of " ++ (List.length stepsState.steps |> String.fromInt)) ]
                            ]
                        ]
                    , div [ css [ Styles.flexColumn ] ]
                        [ stepsView stepsState
                        ]
                    ]
                ]

        Steps.Failure error ->
            div [] [ text error ]

        Steps.Loading ->
            div [] [ text "Loading..." ]


stepsView : Steps.StepsState -> Html msg
stepsView stepsState =
    let
        stepsSoFar =
            stepsState.steps
                |> List.take stepsState.position
    in
    ul [] (List.map stepView stepsSoFar)


stepView : StepsDecoder.Step -> Html msg
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
