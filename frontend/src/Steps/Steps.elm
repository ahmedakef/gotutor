module Steps.Steps exposing (..)

import Helpers.Common as Common
import Helpers.Http as HttpHelper
import Http
import Json.Encode
import Steps.Decoder exposing (..)



-- Init


init : ( State, Cmd Msg )
init =
    let
        initialModel =
            Loading

        combinedCmd =
            Cmd.batch [ getInitSteps, getInitSourceCode ]
    in
    ( initialModel, combinedCmd )



-- Model


type alias StepsState =
    { mode : Mode
    , executionResponse : ExecutionResponse
    , position : Int
    , sourceCode : String
    , highlightedLine : Maybe Int
    , scroll : Scroll
    , errorMessage : Maybe String
    }


type State
    = Success StepsState
    | Failure String
    | Loading


type Mode
    = Edit
    | View
    | WaitingSteps
    | WaitingSourceCode


type alias Scroll =
    { top : Float
    , left : Float
    }



-- Msg


type Msg
    = GotExecutionResponse (Result String ExecutionResponse)
    | GotSourceCode (Result Http.Error String)
    | GotExampleSourceCode (Result Http.Error String)
    | EditCode
    | OnScroll Scroll
    | CodeUpdated String
    | Visualize
    | Next
    | Prev
    | SliderChange Int
    | Highlight Int
    | Unhighlight Int
    | ExampleSelected String



-- load data


getSteps : String -> Common.Env -> Cmd Msg
getSteps sourceCode env =
    let
        backendUrl =
            case env of
                Common.Dev ->
                    "http://localhost:8080"

                Common.Prod ->
                    "https://backend.gotutor.dev"
    in
    Http.request
        { method = "POST"
        , headers = []
        , url = backendUrl ++ "/GetExecutionSteps"
        , body = Http.jsonBody (Json.Encode.object [ ( "source_code", Json.Encode.string sourceCode ) ])
        , expect = HttpHelper.expectJson GotExecutionResponse executionResponseDecoder
        , timeout = Just (60 * 1000) -- ms
        , tracker = Nothing
        }


getInitSteps : Cmd Msg
getInitSteps =
    Http.get
        { url = "initialProgram/steps.json"
        , expect = HttpHelper.expectJson GotExecutionResponse executionResponseDecoder
        }


getInitSourceCode : Cmd Msg
getInitSourceCode =
    Http.get
        { url = "initialProgram/main.txt"
        , expect = Http.expectString GotSourceCode
        }


getExampleSourceCode : String -> Cmd Msg
getExampleSourceCode example =
    Http.get
        { url = "examples/" ++ example
        , expect = Http.expectString GotExampleSourceCode
        }



-- Update


update : Msg -> State -> Common.Env -> ( State, Cmd Msg )
update msg state env =
    case state of
        Success successState ->
            case msg of
                GotExecutionResponse gotExecutionStepsResponseResult ->
                    case gotExecutionStepsResponseResult of
                        Ok executionResponse ->
                            ( Success { successState | executionResponse = executionResponse, position = 1, mode = View, errorMessage = Nothing }, Cmd.none )

                        Err err ->
                            case successState.mode of
                                WaitingSteps ->
                                    -- waiting after clicking visualize
                                    ( Success { successState | mode = Edit, executionResponse = { steps = [], duration = "", output = "" }, position = 0, errorMessage = Just err }, Cmd.none )

                                _ ->
                                    ( Success { successState | mode = Edit, errorMessage = Just ("Error while getting execution steps: " ++ err) }, Cmd.none )

                GotSourceCode sourceCodeResult ->
                    case sourceCodeResult of
                        Ok sourceCode ->
                            ( Success { successState | sourceCode = sourceCode, errorMessage = Nothing }, Cmd.none )

                        Err err ->
                            ( Failure ("Error while reading program source code: " ++ HttpHelper.errorToString err), Cmd.none )

                GotExampleSourceCode sourceCodeResult ->
                    case sourceCodeResult of
                        Ok sourceCode ->
                            ( Success { successState | sourceCode = sourceCode, mode = Edit, errorMessage = Nothing }, Cmd.none )

                        Err err ->
                            ( Success { successState | mode = Edit, errorMessage = Just ("Error while reading example source code: " ++ HttpHelper.errorToString err) }, Cmd.none )

                CodeUpdated code ->
                    ( Success { successState | sourceCode = code }, Cmd.none )

                EditCode ->
                    ( Success { successState | mode = Edit }, Cmd.none )

                OnScroll scroll ->
                    ( Success { successState | scroll = scroll }, Cmd.none )

                Visualize ->
                    ( Success { successState | mode = WaitingSteps, executionResponse = { steps = [], duration = "", output = "" }, position = 0 }, getSteps successState.sourceCode env )

                Next ->
                    if successState.position + 1 > List.length successState.executionResponse.steps then
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

                ExampleSelected example ->
                    ( Success { successState | mode = WaitingSourceCode }, getExampleSourceCode example )

        Failure _ ->
            ( state, Cmd.none )

        Loading ->
            case msg of
                GotExecutionResponse gotExecutionStepsResponseResult ->
                    case gotExecutionStepsResponseResult of
                        Ok executionResponse ->
                            ( Success (StepsState View executionResponse 1 "" Nothing (Scroll 0 0) Nothing), Cmd.none )

                        Err err ->
                            ( Failure ("Error while getting program execution steps: " ++ err), Cmd.none )

                GotSourceCode sourceCodeResult ->
                    case sourceCodeResult of
                        Ok sourceCode ->
                            ( Success (StepsState View { steps = [], duration = "", output = "" } 0 sourceCode Nothing (Scroll 0 0) Nothing), Cmd.none )

                        Err err ->
                            ( Failure ("Error while reading program source code: " ++ HttpHelper.errorToString err), Cmd.none )

                _ ->
                    ( state, Cmd.none )
