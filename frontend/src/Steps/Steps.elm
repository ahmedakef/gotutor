module Steps.Steps exposing (..)

import Helpers.Http as HttpHelper
import Http
import Json.Encode
import Steps.Decoder exposing (..)



-- Model


type alias StepsState =
    { mode : Mode
    , steps : List Step
    , position : Int
    , sourceCode : String
    , highlightedLine : Maybe Int
    , scroll : Scroll
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
    = GotSteps (Result Http.Error (List Step))
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


getSteps : String -> Cmd Msg
getSteps sourceCode =
    let
        prefix =
            "http://localhost:9090/"

        -- TODO: remove when fixing CORS issue
    in
    Http.post
        { url = prefix ++ "http://localhost:8080/Handler/GetExecutionSteps"
        , body = Http.jsonBody (Json.Encode.object [ ( "source_code", Json.Encode.string sourceCode ) ])
        , expect = Http.expectJson GotSteps stepsDecoder
        }


getInitSteps : Cmd Msg
getInitSteps =
    Http.get
        { url = "gotutor/initialProgram/steps.json"
        , expect = Http.expectJson GotSteps stepsDecoder
        }


getInitSourceCode : Cmd Msg
getInitSourceCode =
    Http.get
        { url = "gotutor/initialProgram/main.txt"
        , expect = Http.expectString GotSourceCode
        }



-- Update


update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case state of
        Success successState ->
            case msg of
                GotSteps gotStepsResult ->
                    case gotStepsResult of
                        Ok steps ->
                            ( Success { successState | steps = steps, mode = View }, Cmd.none )

                        Err err ->
                            ( Failure ("Error while getting program execution steps: " ++ HttpHelper.errorToString err), Cmd.none )

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
                    ( Success { successState | mode = WaitingSteps }, getSteps successState.sourceCode )

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
                            ( Success (StepsState View steps 0 "" Nothing (Scroll 0 0)), Cmd.none )

                        Err err ->
                            ( Failure ("Error while getting program execution steps: " ++ HttpHelper.errorToString err), Cmd.none )

                GotSourceCode sourceCodeResult ->
                    case sourceCodeResult of
                        Ok sourceCode ->
                            ( Success (StepsState View [] 0 sourceCode Nothing (Scroll 0 0)), Cmd.none )

                        Err err ->
                            ( Failure ("Error while reading program source code: " ++ HttpHelper.errorToString err), Cmd.none )

                _ ->
                    ( state, Cmd.none )
