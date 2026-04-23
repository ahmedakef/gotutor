module Steps.Steps exposing (..)

import Browser.Dom
import Helpers.Common as Common
import Helpers.Http as HttpHelper
import Http
import Json.Encode
import Steps.Decoder exposing (..)
import Task



-- Init


init : Route -> ( State, Cmd Msg )
init route =
    let
        initialModel =
            Loading

        combinedCmd =
            case route of
                Home (Just id) ->
                    getSharedCode id

                _ ->
                    Cmd.batch [ getInitSteps, getInitSourceCode ]
    in
    ( initialModel, combinedCmd )



-- Model


type Route
    = Home (Maybe String) -- String is the id parameter


type alias StepsState =
    { mode : Mode
    , executionResponse : ExecutionResponse
    , position : Int
    , sourceCode : String
    , highlightedLine : Maybe Int
    , scroll : Scroll
    , errorMessage : Maybe String
    , shareUrl : Maybe String
    , config : Config
    }


type alias Config =
    { showOnlyExportedFields : Bool
    , showMemoryAddresses : Bool
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
    | WaitingLLM


type alias Scroll =
    { top : Float
    , left : Float
    }



-- Msg


type Msg
    = GotExecutionResponse (Result String ExecutionResponse)
    | GotSourceCode (Result Http.Error String)
    | GotExampleSourceCode (Result Http.Error String)
    | GotFmt (Result String FmtResponse)
    | GotShareID (Result Http.Error String)
    | GotSharedCode (Result Http.Error String)
    | GotFixedCode (Result String FixCodeResponse)
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
    | Fmt
    | Share
    | FixCodeWithAI
    | ShowOnlyExportedFields Bool
    | ShowMemoryAddresses Bool
    | ScrollResult (Result Browser.Dom.Error ())



-- load data


backendUrl : Common.Env -> String
backendUrl env =
    case env of
        Common.Dev ->
            "http://localhost:8080"

        Common.Prod ->
            "https://backend.gotutor.dev"


getSteps : String -> Common.Env -> Cmd Msg
getSteps sourceCode env =
    Http.request
        { method = "POST"
        , headers = []
        , url = backendUrl env ++ "/GetExecutionSteps"
        , body = Http.jsonBody (Json.Encode.object [ ( "source_code", Json.Encode.string sourceCode ) ])
        , expect = HttpHelper.expectJson GotExecutionResponse executionResponseDecoder
        , timeout = Just (180 * 1000) -- ms
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


getFmt : String -> Common.Env -> Cmd Msg
getFmt sourceCode env =
    Http.request
        { method = "POST"
        , headers = []
        , url = backendUrl env ++ "/fmt"
        , body =
            Http.multipartBody
                [ Http.stringPart "body" sourceCode
                , Http.stringPart "imports" "true"
                ]
        , expect = HttpHelper.expectJson GotFmt fmtResponseDecoder
        , timeout = Just (60 * 1000) -- ms
        , tracker = Nothing
        }


getFixCode : String -> Maybe String -> Common.Env -> Cmd Msg
getFixCode sourceCode maybeError env =
    let
        bodyFields =
            ( "source_code", Json.Encode.string sourceCode )
                :: (case maybeError of
                        Just error ->
                            [ ( "error", Json.Encode.string error ) ]

                        Nothing ->
                            []
                   )
    in
    Http.request
        { method = "POST"
        , headers = []
        , url = backendUrl env ++ "/fix-code"
        , body = Http.jsonBody (Json.Encode.object bodyFields)
        , expect = HttpHelper.expectJson GotFixedCode fixCodeResponseDecoder
        , timeout = Just (120 * 1000) -- ms
        , tracker = Nothing
        }


callShare : String -> Cmd Msg
callShare sourceCode =
    Http.request
        { method = "POST"
        , headers = []
        , url = "https://play.golang.org/share"
        , body = Http.stringBody "text/plain" sourceCode
        , expect = Http.expectString GotShareID
        , timeout = Just (60 * 1000) -- ms
        , tracker = Nothing
        }


getSharedCode : String -> Cmd Msg
getSharedCode id =
    Http.request
        { method = "GET"
        , headers = []
        , url = "https://play.golang.org/p/" ++ id ++ ".go"
        , body = Http.emptyBody
        , expect = Http.expectString GotSharedCode
        , timeout = Just (60 * 1000) -- ms
        , tracker = Nothing
        }


shareUrl : String -> String
shareUrl id =
    "https://gotutor.dev/?id=" ++ id


goToPosition : StepsState -> Int -> ( State, Cmd Msg )
goToPosition stepsState position =
    let
        clampedPosition =
            clamp 0 (List.length stepsState.executionResponse.steps) position

        newState =
            { stepsState | position = clampedPosition }

        scrollCmd =
            case getCurrentLine newState of
                Just line ->
                    scrollToLineIfNeeded line (String.lines newState.sourceCode |> List.length)

                Nothing ->
                    Cmd.none
    in
    ( Success newState, scrollCmd )


scrollToLineIfNeeded : Int -> Int -> Cmd Msg
scrollToLineIfNeeded lineNumber totalLines =
    Browser.Dom.getViewportOf "code-textarea"
        |> Task.andThen
            (\viewport ->
                let
                    lineHeight =
                        viewport.scene.height / toFloat totalLines

                    lineTop =
                        lineHeight * toFloat (lineNumber - 1)

                    lineBottom =
                        lineTop + lineHeight

                    visibleTop =
                        viewport.viewport.y

                    visibleBottom =
                        visibleTop + viewport.viewport.height
                in
                if lineTop < visibleTop || lineBottom > visibleBottom then
                    Browser.Dom.setViewportOf "code-textarea" viewport.viewport.x (max 0 (lineTop - viewport.viewport.height / 2))

                else
                    Task.succeed ()
            )
        |> Task.attempt ScrollResult


getCurrentLine : StepsState -> Maybe Int
getCurrentLine stepsState =
    stepsState.executionResponse.steps
        |> List.take stepsState.position
        |> List.reverse
        |> List.head
        |> Maybe.andThen
            (\step ->
                List.head step.goroutinesData
                    |> Maybe.map .stacktrace
                    |> Maybe.map (List.filter (\frame -> String.endsWith "main.go" frame.file))
                    |> Maybe.andThen List.head
                    |> Maybe.map .line
            )



-- Update


update : Msg -> State -> Common.Env -> ( State, Cmd Msg )
update msg state env =
    case state of
        Success successState ->
            let
                currentConfig =
                    successState.config
            in
            case msg of
                GotExecutionResponse gotExecutionStepsResponseResult ->
                    case gotExecutionStepsResponseResult of
                        Ok executionResponse ->
                            ( Success { successState | executionResponse = executionResponse, position = 1, mode = View, errorMessage = Nothing }, Cmd.none )

                        Err err ->
                            case successState.mode of
                                WaitingSteps ->
                                    -- waiting after clicking visualize
                                    ( Success { successState | mode = Edit, executionResponse = { steps = [], duration = "", stdout = "", stderr = "" }, position = 0, errorMessage = Just err }, Cmd.none )

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

                GotFmt fmtResponseResult ->
                    case fmtResponseResult of
                        Ok fmtResponse ->
                            ( Success { successState | sourceCode = fmtResponse.body, mode = Edit, errorMessage = Nothing }, Cmd.none )

                        Err err ->
                            ( Success { successState | mode = Edit, errorMessage = Just ("Error while formatting source code: " ++ err) }, Cmd.none )

                GotFixedCode fixCodeResponseResult ->
                    case fixCodeResponseResult of
                        Ok fixCodeResponse ->
                            ( Success { successState | sourceCode = fixCodeResponse.fixedCode, mode = Edit, errorMessage = Nothing }, Cmd.none )

                        Err err ->
                            ( Success { successState | mode = Edit, errorMessage = Just ("Error while fixing code with AI: " ++ err) }, Cmd.none )

                GotShareID shareResult ->
                    case shareResult of
                        Ok id ->
                            ( Success { successState | shareUrl = Just (shareUrl id) }, Cmd.none )

                        Err err ->
                            ( Success { successState | mode = Edit, errorMessage = Just ("Error while sharing source code: " ++ HttpHelper.errorToString err) }, Cmd.none )

                CodeUpdated code ->
                    ( Success { successState | sourceCode = code, shareUrl = Nothing }, Cmd.none )

                EditCode ->
                    ( Success { successState | mode = Edit }, Cmd.none )

                OnScroll scroll ->
                    ( Success { successState | scroll = scroll }, Cmd.none )

                Visualize ->
                    ( Success { successState | mode = WaitingSteps, executionResponse = { steps = [], duration = "", stdout = "", stderr = "" }, position = 0 }, getSteps successState.sourceCode env )

                Next ->
                    goToPosition successState (successState.position + 1)

                Prev ->
                    goToPosition successState (successState.position - 1)

                SliderChange position ->
                    goToPosition successState position

                Highlight line ->
                    ( Success { successState | highlightedLine = Just line }, Cmd.none )

                Unhighlight _ ->
                    ( Success { successState | highlightedLine = Nothing }, Cmd.none )

                ExampleSelected example ->
                    ( Success { successState | mode = WaitingSourceCode }, getExampleSourceCode example )

                Fmt ->
                    ( Success { successState | mode = WaitingSourceCode }, getFmt successState.sourceCode env )

                FixCodeWithAI ->
                    ( Success { successState | mode = WaitingLLM }, getFixCode successState.sourceCode successState.errorMessage env )

                Share ->
                    ( state, callShare successState.sourceCode )

                ShowOnlyExportedFields showOnlyExportedFields ->
                    ( Success { successState | config = { currentConfig | showOnlyExportedFields = showOnlyExportedFields } }, Cmd.none )

                ShowMemoryAddresses showMemoryAddresses ->
                    ( Success { successState | config = { currentConfig | showMemoryAddresses = showMemoryAddresses } }, Cmd.none )

                _ ->
                    ( state, Cmd.none )

        Failure _ ->
            ( state, Cmd.none )

        Loading ->
            case msg of
                GotExecutionResponse gotExecutionStepsResponseResult ->
                    case gotExecutionStepsResponseResult of
                        Ok executionResponse ->
                            ( Success (StepsState View executionResponse 1 "" Nothing (Scroll 0 0) Nothing Nothing { showOnlyExportedFields = True, showMemoryAddresses = False }), Cmd.none )

                        Err err ->
                            ( Failure ("Error while getting program execution steps: " ++ err), Cmd.none )

                GotSourceCode sourceCodeResult ->
                    case sourceCodeResult of
                        Ok sourceCode ->
                            ( Success (StepsState View { steps = [], duration = "", stdout = "", stderr = "" } 0 sourceCode Nothing (Scroll 0 0) Nothing Nothing { showOnlyExportedFields = True, showMemoryAddresses = False }), Cmd.none )

                        Err err ->
                            ( Failure ("Error while reading program source code: " ++ HttpHelper.errorToString err), Cmd.none )

                GotSharedCode sharedCodeResult ->
                    case sharedCodeResult of
                        Ok sharedCode ->
                            ( Success (StepsState WaitingSteps { steps = [], duration = "", stdout = "", stderr = "" } 0 sharedCode Nothing (Scroll 0 0) Nothing Nothing { showOnlyExportedFields = True, showMemoryAddresses = False }), getSteps sharedCode env )

                        Err err ->
                            ( Failure ("Error while loading shared source code: " ++ HttpHelper.errorToString err), Cmd.none )

                _ ->
                    ( state, Cmd.none )
