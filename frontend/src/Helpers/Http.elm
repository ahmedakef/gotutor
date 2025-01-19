module Helpers.Http exposing (..)

import Http
import Json.Decode



-- Failure Decoder


type alias ErrorResponse =
    { message : String
    , code : Int
    }


errorDecoder : Json.Decode.Decoder ErrorResponse
errorDecoder =
    Json.Decode.map2 ErrorResponse
        (Json.Decode.field "message" Json.Decode.string)
        (Json.Decode.field "code" Json.Decode.int)


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "The URL " ++ url ++ " was invalid"

        Http.Timeout ->
            "Unable to reach the server, try again"

        Http.NetworkError ->
            "Unable to reach the server, check your network connection"

        Http.BadStatus 500 ->
            "The server had a problem, try again later, or change your request"

        Http.BadStatus 400 ->
            "Verify your input and try again"

        Http.BadStatus num ->
            "Unknown error " ++ String.fromInt num

        Http.BadBody errorMessage ->
            errorMessage


expectJson : (Result String a -> msg) -> Json.Decode.Decoder a -> Http.Expect msg
expectJson toMsg successDecoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.GoodStatus_ _ body ->
                    case Json.Decode.decodeString successDecoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (Json.Decode.errorToString err)

                Http.BadStatus_ _ body ->
                    case Json.Decode.decodeString errorDecoder body of
                        Ok value ->
                            Err value.message

                        Err err ->
                            Err (Json.Decode.errorToString err)

                Http.BadUrl_ url ->
                    Err ("The URL " ++ url ++ " was invalid")

                Http.Timeout_ ->
                    Err "Unable to reach the server, try again"

                Http.NetworkError_ ->
                    Err "Unable to reach the server, check your network connection"
