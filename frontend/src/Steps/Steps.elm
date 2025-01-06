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
    | SliderChange Int
    | Highlight Int
    | Unhighlight Int



-- load data


getSteps : Cmd Msg
getSteps =
    Http.get
        { url = "http://localhost:8000/example/steps.json"
        , expect = Http.expectJson GotSteps stepsDecoder
        }


getSourceCode : Cmd Msg
getSourceCode =
    Http.get
        { url = "http://localhost:8000/example/main.txt"
        , expect = Http.expectString GotSourceCode
        }



-- Model


type alias StepsState =
    { steps : List Step
    , position : Int
    , sourceCode : String
    , highlightedLine : Maybe Int
    }


type State
    = Success StepsState
    | Failure String
    | Loading



-- Update


update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case state of
        Success successState ->
            case msg of
                GotSteps gotStepsResult ->
                    case gotStepsResult of
                        Ok steps ->
                            ( Success { successState | steps = steps }, Cmd.none )

                        Err err ->
                            ( Failure (err |> HttpHelper.errorToString), Cmd.none )

                GotSourceCode sourceCodeResult ->
                    case sourceCodeResult of
                        Ok sourceCode ->
                            ( Success { successState | sourceCode = sourceCode }, Cmd.none )

                        Err err ->
                            ( Failure (err |> HttpHelper.errorToString), Cmd.none )

                Next ->
                    if successState.position + 1 > List.length successState.steps then
                        ( Success successState, Cmd.none )

                    else
                        ( Success { successState | position = successState.position + 1 }, Cmd.none )

                Prev ->
                    if successState.position - 1 < 0 then
                        ( Success successState, Cmd.none )

                    else
                        ( Success { successState | position = successState.position - 1 }, Cmd.none )

                SliderChange position ->
                    ( Success { successState | position = position }, Cmd.none )

                Highlight line ->
                    ( Success { successState | highlightedLine = Just line }, Cmd.none )

                Unhighlight _ ->
                    ( Success { successState | highlightedLine = Nothing }, Cmd.none )

        Failure _ ->
            ( state, Cmd.none )

        Loading ->
            case msg of
                GotSteps gotStepsResult ->
                    case gotStepsResult of
                        Ok steps ->
                            ( Success (StepsState steps 0 "" Nothing), getSourceCode )

                        Err err ->
                            ( Failure (err |> HttpHelper.errorToString), Cmd.none )

                GotSourceCode sourceCodeResult ->
                    case sourceCodeResult of
                        Ok sourceCode ->
                            ( Success (StepsState [] 0 sourceCode Nothing), Cmd.none )

                        Err err ->
                            ( Failure (err |> HttpHelper.errorToString), Cmd.none )

                Next ->
                    ( state, Cmd.none )

                Prev ->
                    ( state, Cmd.none )

                SliderChange _ ->
                    ( state, Cmd.none )

                Highlight _ ->
                    ( state, Cmd.none )

                Unhighlight _ ->
                    ( state, Cmd.none )
