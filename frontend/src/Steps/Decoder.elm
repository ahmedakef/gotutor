module Steps.Decoder exposing (..)

import Json.Decode exposing (..)
import Json.Decode.Field as Field


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


type alias Variable =
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
    , base : Int
    , unreadable : String
    , locationExpr : String
    , declLine : Int
    }


type alias Step =
    { goroutine : Goroutine
    , packageVars : List Variable
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
                                                                                                                        , base = base
                                                                                                                        , unreadable = unreadable
                                                                                                                        , locationExpr = locationExpr
                                                                                                                        , declLine = declLine
                                                                                                                        }


stepDecoder : Decoder Step
stepDecoder =
    map2 Step
        (field "Goroutine" goroutineDecoder)
        (field "PackageVariables" (list variableDecoder))


stepsDecoder : Decoder (List Step)
stepsDecoder =
    list stepDecoder
