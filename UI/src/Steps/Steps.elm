module Steps.Steps exposing (..)
import Steps.Decoder as StepsDecoder
import Helpers.Http as HttpHelper

import Http

-- Msg

type Msg
    = GotSteps (Result Http.Error (List StepsDecoder.Step))


-- load data

getSteps : (Msg -> msg) -> Cmd msg
getSteps toMsg =
    Http.get
        { url = "http://localhost:8000/steps.json"
        , expect = Http.expectJson (GotSteps >> toMsg) StepsDecoder.stepsDecoder
        }


-- Model

type State
    = Success (List StepsDecoder.Step)
    | Failure String
    | Loading

-- Update

update : Msg -> State -> ( State, Cmd Msg )
update msg _ =
    case msg of
        GotSteps (Ok steps) ->
            (  Success steps , Cmd.none )

        GotSteps (Err err) ->
            (   Failure (err |> HttpHelper.errorToString) , Cmd.none )
