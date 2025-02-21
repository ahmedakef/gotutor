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


type alias Scroll =
    { top : Float
    , left : Float
    }



-- Msg


type Msg
    = GotExecutionResponse (Result String ExecutionResponse)
    | GotSourceCode (Result Http.Error String)
    | EditCode
    | OnScroll Scroll
    | CodeUpdated String
    | Visualize
    | Next
    | Prev
    | SliderChange Int
    | Highlight Int
    | Unhighlight Int



-- load data


getSteps : String -> Common.Env -> Cmd Msg
getSteps sourceCode env =
    let
        backendUrl =
            case env of
                Common.Dev ->
                    "http://localhost:8080"

                Common.Prod ->
                    "https://201jhj1vqwsk20me57hggnvabsp.env.us.restate.cloud:8080"
    in
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "Authorization" ("Bearer " ++ "key_10uzQuWRXs7INU41qdqDe0a.FbaLJCEJ2daXJCoNPmKsxz3VUPnR3d7dU4WKnv1gLvSR")
            ]
        , url = backendUrl ++ "/Handler/GetExecutionSteps"
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
                                    ( Failure ("Error while getting execution steps: " ++ err), Cmd.none )

                GotSourceCode sourceCodeResult ->
                    case sourceCodeResult of
                        Ok sourceCode ->
                            ( Success { successState | sourceCode = sourceCode }, Cmd.none )

                        Err err ->
                            ( Failure ("Error while reading program source code: " ++ HttpHelper.errorToString err), Cmd.none )

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
