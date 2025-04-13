module Steps.Decoder exposing (..)

import Css.Global exposing (children)
import Json.Decode exposing (..)
import Json.Decode.Field as Field


type alias ExecutionResponse =
    { steps : List Step
    , duration : String
    , output : String
    }



executionResponseDecoder : Decoder ExecutionResponse
executionResponseDecoder =
    map3 ExecutionResponse
        (field "steps" stepsDecoder)
        (field "duration" string)
        (field "output" string)


type alias FmtResponse =
    { body : String
    }

fmtResponseDecoder : Decoder FmtResponse
fmtResponseDecoder =
    map FmtResponse
        (field "body" string)


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


type Variable
    = VariableI
        { name : String
        , addr : Int
        , onlyAddr : Bool
        , type_ : String
        , realType : String
        , flags : Int
        , kind : Int
        , value : String
        , len : Int
        , cap : Int
        , children : List Variable
        , base : Int
        , unreadable : String
        , locationExpr : String
        , declLine : Int
        }


type alias Step =
    { packageVars : List Variable
    , goroutinesData : List GoroutinesData
    }


type alias GoroutinesData =
    { goroutine : Goroutine
    , stacktrace : List StackFrame
    }


functionDecoder : Decoder Function
functionDecoder =
    map5 Function
        (field "name" string)
        (field "value" int)
        (field "type" int)
        (field "goType" int)
        (field "optimized" bool)


locationDecoder : Decoder Location
locationDecoder =
    map4 Location
        (field "pc" int)
        (field "file" string)
        (field "line" int)
        (field "function" functionDecoder)


goroutineDecoder : Decoder Goroutine
goroutineDecoder =
    map3 Goroutine
        (field "id" int)
        (field "currentLoc" locationDecoder)
        (field "userCurrentLoc" locationDecoder)


variableDecoder : Decoder Variable
variableDecoder =
    Field.require "name" string <|
        \name ->
            Field.require "addr" int <|
                \addr ->
                    Field.require "onlyAddr" bool <|
                        \onlyAddr ->
                            Field.require "type" string <|
                                \type_ ->
                                    Field.require "realType" string <|
                                        \realType ->
                                            Field.require "flags" int <|
                                                \flags ->
                                                    Field.require "kind" int <|
                                                        \kind ->
                                                            Field.require "value" string <|
                                                                \value ->
                                                                    Field.require "len" int <|
                                                                        \len ->
                                                                            Field.require "children" (list variableDecoder) <|
                                                                                \children ->
                                                                                    Field.require "cap" int <|
                                                                                        \cap ->
                                                                                            Field.require "base" int <|
                                                                                                \base ->
                                                                                                    Field.require "unreadable" string <|
                                                                                                        \unreadable ->
                                                                                                            Field.require "LocationExpr" string <|
                                                                                                                \locationExpr ->
                                                                                                                    Field.require "DeclLine" int <|
                                                                                                                        \declLine ->
                                                                                                                            Json.Decode.succeed
                                                                                                                                (VariableI
                                                                                                                                    { name = name
                                                                                                                                    , addr = addr
                                                                                                                                    , onlyAddr = onlyAddr
                                                                                                                                    , type_ = type_
                                                                                                                                    , realType = realType
                                                                                                                                    , flags = flags
                                                                                                                                    , kind = kind
                                                                                                                                    , value = value
                                                                                                                                    , len = len
                                                                                                                                    , cap = cap
                                                                                                                                    , children = children
                                                                                                                                    , base = base
                                                                                                                                    , unreadable = unreadable
                                                                                                                                    , locationExpr = locationExpr
                                                                                                                                    , declLine = declLine
                                                                                                                                    }
                                                                                                                                )


type alias StackFrame =
    { pc : Int
    , file : String
    , line : Int
    , function : Function
    , locals : Maybe (List Variable)
    , arguments : Maybe (List Variable)
    , frameOffset : Int
    , framePointerOffset : Int
    , defers : List String
    , err : String
    }


stacktraceDecoder : Decoder (List StackFrame)
stacktraceDecoder =
    list <|
        Field.require "pc" int <|
            \pc ->
                Field.require "file" string <|
                    \file ->
                        Field.require "line" int <|
                            \line ->
                                Field.require "function" functionDecoder <|
                                    \function ->
                                        Field.require "Locals" (maybe (list variableDecoder)) <|
                                            \locals ->
                                                Field.require "Arguments" (maybe (list variableDecoder)) <|
                                                    \arguments ->
                                                        Field.require "FrameOffset" int <|
                                                            \frameOffset ->
                                                                Field.require "FramePointerOffset" int <|
                                                                    \framePointerOffset ->
                                                                        Field.require "Defers" (list string) <|
                                                                            \defers ->
                                                                                Field.require "Err" string <|
                                                                                    \err ->
                                                                                        Json.Decode.succeed
                                                                                            { pc = pc
                                                                                            , file = file
                                                                                            , line = line
                                                                                            , function = function
                                                                                            , locals = locals
                                                                                            , arguments = arguments
                                                                                            , frameOffset = frameOffset
                                                                                            , framePointerOffset = framePointerOffset
                                                                                            , defers = defers
                                                                                            , err = err
                                                                                            }


stepDecoder : Decoder Step
stepDecoder =
    map2 Step
        (field "PackageVariables" (list variableDecoder))
        (field "GoroutinesData" (list goroutinesDataDecoder))


goroutinesDataDecoder : Decoder GoroutinesData
goroutinesDataDecoder =
    map2 GoroutinesData
        (field "Goroutine" goroutineDecoder)
        (field "Stacktrace" stacktraceDecoder)


stepsDecoder : Decoder (List Step)
stepsDecoder =
    list stepDecoder
