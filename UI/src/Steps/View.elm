module Steps.View exposing (..)

import Css exposing (..)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)
import Steps.Decoder as StepsDecoder
import Steps.Steps as Steps
import Styles
import Html.Styled.Events exposing (onClick)

view : Steps.State -> Html Steps.Msg
view state =
    case state of
        Steps.Success stepsState ->
            div []
                [ div [ css [Styles.container] ]
                    [ div [ css [Styles.flexColumn] ]
                        [ h1 [] [ text "Steps of your Go Program:" ]
                        ]
                    ]
                , div [ css [Styles.container] ]
                    [ div [ css [ Styles.flexColumn, Styles.flexCenter ] ]
                        [ div []
                            [ div []
                                [ button [  onClick Steps.Prev] [ text "Prev" ]
                                , button [  onClick Steps.Next] [ text "Next" ]
                                ]
                            , div [] [ text ("Step " ++ (String.fromInt stepsState.position) ++" of " ++ ( List.length stepsState.steps |> String.fromInt) ) ]
                            ]
                        ]
                    , div [ css [Styles.flexColumn] ]
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
        [ div [] [ text <| "Goroutine ID: " ++ String.fromInt step.goroutine.id ]
        , div [] [ text <| "PC: " ++ String.fromInt step.goroutine.currentLoc.pc ]
        , div [] [ text <| "File: " ++ step.goroutine.currentLoc.file ]
        , div [] [ text <| "Line: " ++ String.fromInt step.goroutine.currentLoc.line ]
        , div [] [ text <| "Function: " ++ step.goroutine.currentLoc.function.name ]
        ]


borderStyle : List Css.Style
borderStyle =
    [ border3 (px 1) solid (hex "ccc")
    , padding (px 10)
    , margin3 (px 0) (px 0) (px 10)
    ]
