module Steps.Steps exposing (getSteps, Step, Msg(..))

import Http
import Json.Decode as Json
type Msg
    = GotSteps (Result Http.Error (List Step))

getSteps : (Msg -> msg) -> Cmd msg
getSteps toMsg =
    Http.get
        { url = "http://localhost:8000/steps.json"
        , expect = Http.expectJson (GotSteps >> toMsg) stepsDecoder
        }


type alias Function =
    { name : String
    , value : Int
    , type_ : Int
    , goType : Int
    , optimized : Bool
    }

type alias Location =
    { pc : Int
    , file : String
    , line : Int
    , function : Function
    }

type alias Goroutine =
    { id : Int
    , currentLoc : Location
    , userCurrentLoc : Location
    }

type alias Step =
    { goroutine : Goroutine
    }

functionDecoder : Json.Decoder Function
functionDecoder =
    Json.map5 Function
        (Json.field "name" Json.string)
        (Json.field "value" Json.int)
        (Json.field "type" Json.int)
        (Json.field "goType" Json.int)
        (Json.field "optimized" Json.bool)

locationDecoder : Json.Decoder Location
locationDecoder =
    Json.map4 Location
        (Json.field "pc" Json.int)
        (Json.field "file" Json.string)
        (Json.field "line" Json.int)
        (Json.field "function" functionDecoder)

goroutineDecoder : Json.Decoder Goroutine
goroutineDecoder =
    Json.map3 Goroutine
        (Json.field "id" Json.int)
        (Json.field "currentLoc" locationDecoder)
        (Json.field "userCurrentLoc" locationDecoder)

stepDecoder : Json.Decoder Step
stepDecoder =
    Json.map Step (Json.field "Goroutine" goroutineDecoder)

stepsDecoder : Json.Decoder (List Step)
stepsDecoder =
    Json.list stepDecoder
