module SyntaxHighlight.SyntaxHighlight.Language.Json exposing
    ( Syntax(..)
    , syntaxToStyle
      -- Exposing for tests purpose
    , toLines
    , toRevTokens
    )

import Parser exposing ((|.), DeadEnd, Parser, Step(..), andThen, chompIf, getChompedString, keyword, loop, map, oneOf, succeed, symbol)
import Set exposing (Set)
import SyntaxHighlight.SyntaxHighlight.Language.Helpers exposing (Delimiter, chompIfThenWhile, delimited, isEscapable, isLineBreak, isSpace, isWhitespace, thenChompWhile, whitespaceCharSet)
import SyntaxHighlight.SyntaxHighlight.Language.Type as T
import SyntaxHighlight.SyntaxHighlight.Line exposing (Line)
import SyntaxHighlight.SyntaxHighlight.Line.Helpers as Line
import SyntaxHighlight.SyntaxHighlight.Style as Style exposing (Required(..))


type alias Token =
    T.Token Syntax


type Syntax
    = String
    | Escapable
    | Number
    | Boolean
    | Null
    | ObjectKey
    | Object
    | Array


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
        , object
            |> map (\n -> Loop (n ++ revTokens))
        , chompIf (always True)
            |> getChompedString
            |> map (\b -> Loop (( T.Normal, b ) :: revTokens))
        , succeed (Done revTokens)
        ]


object : Parser (List Token)
object =
    symbol "{"
        |> andThen
            (\_ -> loop [ ( T.C Object, "{" ) ] objectLoop)


objectLoop : List Token -> Parser (Step (List Token) (List Token))
objectLoop revTokens =
    oneOf
        [ whitespace
            |> map (\n -> Loop (n :: revTokens))
        , stringLiteral ObjectKey revTokens
            |> map Loop
        , symbol ":"
            |> andThen
                (\_ ->
                    let
                        revTokens_ =
                            ( T.C Object, ":" )
                                :: revTokens
                    in
                    oneOf
                        [ whitespace
                            |> andThen
                                (\ws ->
                                    oneOf
                                        [ value
                                            |> map (\v -> v ++ [ ws ])
                                        , succeed [ ws ]
                                        ]
                                )
                        , value
                        , succeed []
                        ]
                        |> map (\ns -> ns ++ revTokens_)
                )
            |> map Loop
        , symbol ","
            |> map (\_ -> ( T.C Object, "," ))
            |> map (\n -> Loop (n :: revTokens))
        , symbol "}"
            |> map (\_ -> ( T.C Object, "}" ))
            |> map (\n -> Done (n :: revTokens))
        , succeed (Done revTokens)
        ]


value : Parser (List Token)
value =
    oneOf
        [ stringLiteral String []
        , number
            |> map (\n -> [ n ])
        , object
        , array
        , keyword "null"
            |> getChompedString
            |> map (\s -> [ ( T.C Null, s ) ])
        , oneOf
            [ keyword "true"
            , keyword "false"
            ]
            |> getChompedString
            |> map (\s -> [ ( T.C Boolean, s ) ])
        ]


array : Parser (List Token)
array =
    symbol "["
        |> andThen
            (\_ -> loop [ ( T.C Array, "[" ) ] arrayLoop)


arrayLoop : List Token -> Parser (Step (List Token) (List Token))
arrayLoop revTokens =
    oneOf
        [ whitespace
            |> map (\n -> Loop (n :: revTokens))
        , symbol ","
            |> map (\_ -> ( T.C Array, "," ))
            |> map (\n -> Loop (n :: revTokens))
        , symbol "]"
            |> map (\_ -> ( T.C Array, "]" ))
            |> map (\n -> Done (n :: revTokens))
        , value
            |> map (\ns -> Loop (ns ++ revTokens))
        , succeed (Done revTokens)
        ]



-- String literal


stringLiteral : Syntax -> List Token -> Parser (List Token)
stringLiteral syntax_ revTokens =
    delimited (doubleQuoteDelimiter syntax_)
        |> map (\n -> n ++ revTokens)


doubleQuoteDelimiter : Syntax -> Delimiter Token
doubleQuoteDelimiter syntax_ =
    { start = "\""
    , end = "\""
    , isNestable = False
    , defaultMap = \b -> ( T.C syntax_, b )
    , innerParsers =
        [ map List.singleton lineBreak
        , stringEscapable
        ]
    , isNotRelevant = \c -> not (isLineBreak c || isEscapable c)
    }



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


number : Parser Token
number =
    SyntaxHighlight.SyntaxHighlight.Language.Helpers.numberExponentialNotation
        |> getChompedString
        |> map (\b -> ( T.C Number, b ))


stringEscapable : Parser (List Token)
stringEscapable =
    escapable
        |> getChompedString
        |> map (\b -> [ ( T.C Escapable, b ) ])


escapable : Parser ()
escapable =
    succeed ()
        |. Parser.backtrackable (symbol "\\")
        |. chompIf isEscapableChar


isEscapableChar : Char -> Bool
isEscapableChar c =
    Set.member c escapableSet


escapableSet : Set Char
escapableSet =
    Set.fromList
        [ '"'
        , '\\'
        , '/'
        , 'b'
        , 'f'
        , 'n'
        , 'r'
        , 't'
        , 'u'
        ]


syntaxToStyle : Syntax -> ( Style.Required, String )
syntaxToStyle syntax =
    case syntax of
        String ->
            ( Style2, "json-s" )

        Escapable ->
            ( Style1, "json-e" )

        Number ->
            ( Style1, "json-n" )

        Boolean ->
            ( Style3, "json-b" )

        Null ->
            ( Style3, "json-null" )

        ObjectKey ->
            ( Style4, "json-k" )

        Object ->
            ( Default, "json-o" )

        Array ->
            ( Default, "json-a" )
