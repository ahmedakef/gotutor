module Steps.View exposing (..)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)

import Steps.Decoder as StepsDecoder
import Steps.Steps as Steps



view : Steps.State -> Html msg
view state =
    case state of
        Steps.Success steps ->
            div []
                [ h1 [] [ text "Steps" ]
                , ul [] (List.map stepView steps)
                ]

        Steps.Failure error ->
            div [] [ text error ]

        Steps.Loading ->
            div [] [ text "Loading..." ]


stepView : StepsDecoder.Step -> Html msg
stepView step =
    div []
        [ h2 [] [ text "Step" ]
        , div [] [ text <| "Goroutine ID: " ++ String.fromInt step.goroutine.id ]
        , div [] [ text <| "PC: " ++ String.fromInt step.goroutine.currentLoc.pc ]
        , div [] [ text <| "File: " ++ step.goroutine.currentLoc.file ]
        , div [] [ text <| "Line: " ++ String.fromInt step.goroutine.currentLoc.line ]
        , div [] [ text <| "Function: " ++ step.goroutine.currentLoc.function.name ]
        ]
