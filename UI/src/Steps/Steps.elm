module Steps.Steps exposing (..)

import Helpers.Http as HttpHelper
import Http
import Steps.Decoder exposing (..)



-- Msg


type Msg
    = GotSteps (Result Http.Error (List Step))
    | GotSourceCode (Result Http.Error String)
    | Next
    | Prev



-- load data


getSteps : Cmd Msg
getSteps =
    Http.get
        { url = "http://localhost:8000/steps.json"
        , expect = Http.expectJson GotSteps stepsDecoder
        }


getSourceCode : Cmd Msg
getSourceCode =
    Http.get
        { url = "http://localhost:8000/main.txt"
        , expect = Http.expectString GotSourceCode
        }



-- Model


type alias StepsState =
    { steps : List Step
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
                            ( Success { successState | steps = steps }, Cmd.none )

                        Failure _ ->
                            ( state, Cmd.none )

                        Loading ->
                            ( Success (StepsState steps 0 ""), getSourceCode )

                Err err ->
                    ( Failure (err |> HttpHelper.errorToString), Cmd.none )

        GotSourceCode sourceCodeResult ->
            case sourceCodeResult of
                Ok sourceCode ->
                    case state of
                        Success successState ->
                            ( Success { successState | sourceCode = sourceCode }, Cmd.none )

                        Failure _ ->
                            ( state, Cmd.none )

                        Loading ->
                            ( Success (StepsState [] 0 sourceCode), Cmd.none )

                Err err ->
                    ( Failure (err |> HttpHelper.errorToString), Cmd.none )

        Next ->
            case state of
                Success successState ->
                    let
                        _ =
                            state |> Debug.toString |> Debug.log "state"
                    in
                    if successState.position + 1 > List.length successState.steps then
                        ( Success successState, Cmd.none )

                    else
                        ( Success { successState | position = successState.position + 1 }, Cmd.none )

                _ ->
                    let
                        _ =
                            state |> Debug.toString |> Debug.log "state"
                    in
                    ( state, Cmd.none )

        Prev ->
            case state of
                Success successState ->
                    if successState.position - 1 < 0 then
                        ( Success successState, Cmd.none )

                    else
                        ( Success { successState | position = successState.position - 1 }, Cmd.none )

                _ ->
                    ( state, Cmd.none )
