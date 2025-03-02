module SyntaxHighlight.SyntaxHighlight.Language.NoLang exposing
    ( Syntax(..)
    , syntaxToStyle
      -- Exposed for testing
    , toLines
    , toRevTokens
    )

import Parser exposing (DeadEnd, Parser, Step(..), chompIf, getChompedString, loop, map, oneOf, succeed, symbol)
import SyntaxHighlight.SyntaxHighlight.Language.Helpers exposing (chompIfThenWhile, isSpace)
import SyntaxHighlight.SyntaxHighlight.Language.Type as T
import SyntaxHighlight.SyntaxHighlight.Line exposing (Line)
import SyntaxHighlight.SyntaxHighlight.Line.Helpers as Line
import SyntaxHighlight.SyntaxHighlight.Style as Style exposing (Required(..))


type alias Token =
    T.Token Syntax


type Syntax
    = String


syntaxToStyle : Syntax -> ( Style.Required, String )
syntaxToStyle syntax =
    case syntax of
        String ->
            ( Default, "nolang" )


toLines : String -> Result (List DeadEnd) (List Line)
toLines =
    Parser.run toRevTokens
        >> Result.map (Line.toLines syntaxToStyle)


toRevTokens : Parser (List Token)
toRevTokens =
    loop [] mainLoop


mainLoop : List Token -> Parser (Step (List Token) (List Token))
mainLoop revTokens =
    oneOf
        [ whitespace
            |> map (\n -> Loop (n :: revTokens))
        , chompIf (always True)
            |> getChompedString
            |> map (\b -> Loop (( T.Normal, b ) :: revTokens))
        , succeed (Done revTokens)
        ]



-- Helpers


whitespace : Parser Token
whitespace =
    oneOf
        [ space
        , lineBreak
        ]


space : Parser Token
space =
    chompIfThenWhile isSpace
        |> getChompedString
        |> map (\b -> ( T.Normal, b ))


lineBreak : Parser Token
lineBreak =
    symbol "\n"
        |> map (\_ -> ( T.LineBreak, "\n" ))
