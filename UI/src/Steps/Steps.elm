module Steps.Steps exposing (..)
import Steps.Decoder as StepsDecoder
import Helpers.Http as HttpHelper

import Http

-- Msg

type Msg
    = GotSteps (Result Http.Error (List StepsDecoder.Step))
    | Next
    | Prev

-- load data

getSteps : (Msg -> msg) -> Cmd msg
getSteps toMsg =
    Http.get
        { url = "http://localhost:8000/steps.json"
        , expect = Http.expectJson (GotSteps >> toMsg) StepsDecoder.stepsDecoder
        }


-- Model

type alias StepsState =
    { steps : (List StepsDecoder.Step)
    , position : Int
    }

type State
    = Success StepsState
    | Failure String
    | Loading

-- Update

update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case msg of
        GotSteps (Ok steps) ->
            (  Success {steps =  steps, position = 0} , Cmd.none )

        GotSteps (Err err) ->
            (   Failure (err |> HttpHelper.errorToString) , Cmd.none )
        Next ->
            case state of
                Success {steps, position} ->
                    if position + 1 > List.length steps then
                        (  Success {steps = steps, position = position} , Cmd.none )
                    else
                        (  Success {steps = steps, position = position + 1} , Cmd.none )
                _ ->
                    (  state , Cmd.none )

        Prev ->
            case state of
                Success {steps, position} ->
                    if position - 1 < 0 then
                        (  Success {steps = steps, position = position} , Cmd.none )
                    else
                        (  Success {steps = steps, position = position - 1} , Cmd.none )
                _ ->
                    (  state , Cmd.none )
