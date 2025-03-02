module SyntaxHighlight.SyntaxHighlight.View exposing (toBlockHtml, toInlineHtml, toStaticBlockHtml, toStaticInlineHtml)

import Html exposing (Html, br, code, div, pre, span, text)
import Html.Attributes exposing (attribute, class, classList)
import SyntaxHighlight.SyntaxHighlight.Line exposing (..)
import SyntaxHighlight.SyntaxHighlight.Style exposing (Required(..))



-- Html


toBlockHtml : Maybe Int -> List Line -> Html msg
toBlockHtml maybeStart lines =
    case maybeStart of
        Nothing ->
            pre [ class "elmsh" ]
                [ toInlineHtml lines ]

        Just start ->
            lines
                |> List.indexedMap (lineView start)
                |> code []
                |> List.singleton
                |> pre [ class "elmsh" ]


lineView : Int -> Int -> Line -> Html msg
lineView start index { fragments, highlight } =
    div
        [ classList
            [ ( "elmsh-line", True )
            , ( "elmsh-hl", highlight == Just Normal )
            , ( "elmsh-add", highlight == Just Add )
            , ( "elmsh-del", highlight == Just Del )
            ]
        , attribute "data-elmsh-lc" (String.fromInt (start + index))
        ]
        (List.map fragmentView fragments)


toInlineHtml : List Line -> Html msg
toInlineHtml lines =
    lines
        |> List.map
            (\{ highlight, fragments } ->
                if highlight == Nothing then
                    List.map fragmentView fragments

                else
                    [ span
                        [ classList
                            [ ( "elmsh-hl", highlight == Just Normal )
                            , ( "elmsh-add", highlight == Just Add )
                            , ( "elmsh-del", highlight == Just Del )
                            ]
                        ]
                        (List.map fragmentView fragments)
                    ]
            )
        |> List.concat
        |> code [ class "elmsh" ]


fragmentView : Fragment -> Html msg
fragmentView { text, requiredStyle, additionalClass } =
    if requiredStyle == Default && String.isEmpty additionalClass then
        Html.text text

    else
        span
            [ classList
                [ ( requiredStyleToString requiredStyle
                  , requiredStyle /= Default
                  )
                , ( "elmsh-" ++ additionalClass
                  , additionalClass /= ""
                  )
                ]
            ]
            [ Html.text text ]


requiredStyleToString : Required -> String
requiredStyleToString required =
    (++) "elmsh" <|
        case required of
            Default ->
                "0"

            Comment ->
                "-comm"

            Style1 ->
                "1"

            Style2 ->
                "2"

            Style3 ->
                "3"

            Style4 ->
                "4"

            Style5 ->
                "5"

            Style6 ->
                "6"

            Style7 ->
                "7"



-- Static Html


toStaticBlockHtml : Maybe Int -> List Line -> String
toStaticBlockHtml maybeStart lines =
    case maybeStart of
        Nothing ->
            "<pre class=\"elmsh\">"
                ++ toStaticInlineHtml lines
                ++ "</pre>"

        Just start ->
            String.concat
                [ "<pre class=\"elmsh\"><code>"
                , List.indexedMap (staticLineView start) lines
                    |> String.concat
                , "</code></pre>"
                ]


staticLineView : Int -> Int -> Line -> String
staticLineView start index { fragments, highlight } =
    String.concat
        [ "<div class=\""
        , "elmsh-line "
        , emptyIfFalse (highlight == Just Normal) "elmsh-hl "
        , emptyIfFalse (highlight == Just Add) "elmsh-add "
        , emptyIfFalse (highlight == Just Del) "elmsh-del "
        , "\" data-elmsh-lc=\""
        , String.fromInt (start + index)
        , "\">"
        , List.map staticFragmentView fragments |> String.concat
        , "</div>"
        ]


toStaticInlineHtml : List Line -> String
toStaticInlineHtml lines =
    String.concat
        [ "<code class=\"elmsh\">"
        , List.map
            (\{ highlight, fragments } ->
                if highlight == Nothing then
                    List.map staticFragmentView fragments

                else
                    [ "<span class=\""
                    , emptyIfFalse (highlight == Just Normal)
                        "elmsh-hl "
                    , emptyIfFalse (highlight == Just Add)
                        "elmsh-add "
                    , emptyIfFalse (highlight == Just Del)
                        "elmsh-del "
                    , List.map staticFragmentView fragments
                        |> String.concat
                    , "</span>"
                    ]
            )
            lines
            |> List.concat
            |> String.concat
        , "</code>"
        ]


staticFragmentView : Fragment -> String
staticFragmentView { text, requiredStyle, additionalClass } =
    if requiredStyle == Default && String.isEmpty additionalClass then
        text

    else
        String.concat
            [ "<span class=\""
            , emptyIfFalse
                (requiredStyle /= Default)
                (requiredStyleToString requiredStyle)
            , " "
            , emptyIfFalse
                (additionalClass /= "")
                ("elmsh-" ++ additionalClass)
            , "\">"
            , text
            , "</span>"
            ]


emptyIfFalse : Bool -> String -> String
emptyIfFalse bool str =
    if bool then
        str

    else
        ""
