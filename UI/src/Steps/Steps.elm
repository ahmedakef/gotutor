module Steps.Steps exposing (..)
import Steps.Decoder as StepsDecoder
import Helpers.Http as HttpHelper

import Http

-- Msg

type Msg
    = GotSteps (Result Http.Error (List StepsDecoder.Step))
    | GotSourceCode (Result Http.Error String)
    | Next
    | Prev

-- load data

getSteps : Cmd Msg
getSteps  =
    Http.get
        { url = "http://localhost:8000/steps.json"
        , expect = Http.expectJson GotSteps StepsDecoder.stepsDecoder
        }

getSourceCode :  Cmd Msg
getSourceCode  =
    Http.get
        { url = "http://localhost:8000/main.txt"
        , expect = Http.expectString GotSourceCode
        }



-- Model

type alias StepsState =
    { steps : (List StepsDecoder.Step)
    , position : Int
    , sourceCode : String
    }

type State
    = Success StepsState
    | Failure String
    | Loading

-- Update

update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case msg of
        GotSteps gotStepsResult ->
            case gotStepsResult of
                Ok steps ->
                    case state of
                        Success successState ->
                            (  Success { successState | steps = steps} , Cmd.none )
                        _ ->
                           (  Success (StepsState steps 0 "") , Cmd.none )
                Err err ->
                    (   Failure (err |> HttpHelper.errorToString) , Cmd.none )

        GotSourceCode sourceCodeResult ->
            case sourceCodeResult of
                Ok sourceCode ->
                    case state of
                        Success successState ->
                            (  Success { successState | sourceCode = sourceCode} , Cmd.none )
                        _ ->
                           (  Success (StepsState [] 0 sourceCode) , Cmd.none )
                Err err ->
                    (   Failure (err |> HttpHelper.errorToString) , Cmd.none )
        Next ->
            case state of
                Success successState ->
                    if successState.position + 1 > List.length successState.steps then
                        (  Success successState , Cmd.none )
                    else
                        (  Success {successState | position = successState.position + 1} , Cmd.none )
                _ ->
                    (  state , Cmd.none )

        Prev ->
            case state of
                Success successState ->
                    if successState.position - 1 < 0 then
                        (  Success successState , Cmd.none )
                    else
                        (  Success {successState | position = successState.position - 1} , Cmd.none )
                _ ->
                    (  state , Cmd.none )
