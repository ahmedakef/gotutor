module SyntaxHighlight.SyntaxHighlight.Language.Nix exposing
    ( Syntax(..)
    , syntaxToStyle
      -- Exposing for test purposes
    , toLines
    , toRevTokens
    )

import Parser exposing ((|.), DeadEnd, Parser, Step(..), andThen, backtrackable, getChompedString, loop, map, oneOf, succeed, symbol)
import Regex exposing (Regex)
import Set exposing (Set)
import SyntaxHighlight.SyntaxHighlight.Language.Helpers exposing (Delimiter, chompIfThenWhile, delimited, escapable, isEscapable, isLineBreak, isSpace, isWhitespace, thenChompWhile)
import SyntaxHighlight.SyntaxHighlight.Language.Type as T
import SyntaxHighlight.SyntaxHighlight.Line exposing (Line)
import SyntaxHighlight.SyntaxHighlight.Line.Helpers as Line
import SyntaxHighlight.SyntaxHighlight.Style as Style exposing (Required(..))


type alias Token =
    T.Token Syntax


type Syntax
    = Number
    | String
    | Keyword
    | Operator
    | Function
    | Punctuation
    | Literal


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
        [ space
            |> map (\n -> Loop (n :: revTokens))
        , lineBreak
            |> map (\n -> Loop (n :: revTokens))
        , punctuationChar
            |> map (\n -> Loop (n :: revTokens))
        , number
            |> map (\n -> Loop (n :: revTokens))
        , comment
            |> map (\n -> Loop (n ++ revTokens))
        , stringLiteral
            |> andThen (\n -> loop (n ++ revTokens) stringBody)
            |> map Loop
        , chompIfThenWhile isIdentifierChar
            |> getChompedString
            |> andThen (keywordParser revTokens)
            |> map Loop
        , succeed (Done revTokens)
        ]


isIdentifierChar : Char -> Bool
isIdentifierChar c =
    not
        (isWhitespace c
            || isPunctuationChar c
        )


stringBody : List Token -> Parser (Step (List Token) (List Token))
stringBody revTokens =
    oneOf
        [ whitespaceOrCommentStep revTokens
        , stringLiteral |> map (\s -> Loop (s ++ revTokens))
        , succeed (Done revTokens)
        ]


punctuationChar : Parser Token
punctuationChar =
    chompIfThenWhile isPunctuationChar
        |> getChompedString
        |> map (\b -> ( T.C Punctuation, b ))


isPunctuationChar : Char -> Bool
isPunctuationChar c =
    Set.member c punctuatorSet


punctuatorSet : Set Char
punctuatorSet =
    Set.fromList [ '{', '}', '(', ')', '[', ']', '.', ',', ':', ';' ]



-- Keywords


keywordParser : List Token -> String -> Parser (List Token)
keywordParser revTokens s =
    if isOperator s then
        succeed (( T.C Operator, s ) :: revTokens)

    else if isFunction s then
        succeed (( T.C Function, s ) :: revTokens)

    else if isKeyword s then
        succeed (( T.C Keyword, s ) :: revTokens)

    else if isLiteral s then
        succeed (( T.C Literal, s ) :: revTokens)

    else
        succeed (( T.Normal, s ) :: revTokens)


isKeyword : String -> Bool
isKeyword =
    Regex.contains keywordPattern


keywordPattern : Regex
keywordPattern =
    "^(assert|builtins|else|if|in|inherit|let|null|or|then|with)$"
        |> Regex.fromStringWith { caseInsensitive = False, multiline = False }
        |> Maybe.withDefault Regex.never


isLiteral : String -> Bool
isLiteral str =
    Set.member (String.toUpper str) literalSet


literalSet : Set String
literalSet =
    Set.fromList [ "false", "true" ]


isFunction : String -> Bool
isFunction =
    Regex.contains functionPattern


functionPattern : Regex
functionPattern =
    "^(?:abort|add|all|any|attrNames|attrValues|baseNameOf|compareVersions|concatLists|currentSystem|deepSeq|derivation|dirOf|div|elem(?:At)?|fetch(?:Tarball|url)|filter(?:Source)?|fromJSON|genList|getAttr|getEnv|hasAttr|hashString|head|import|intersectAttrs|is(?:Attrs|Bool|Function|Int|List|Null|String)|length|lessThan|listToAttrs|map|mul|parseDrvName|pathExists|read(?:Dir|File)|removeAttrs|replaceStrings|seq|sort|stringLength|sub(?:string)?|tail|throw|to(?:File|JSON|Path|String|XML)|trace|typeOf)|foldl'$"
        |> Regex.fromStringWith { caseInsensitive = False, multiline = False }
        |> Maybe.withDefault Regex.never


isOperator : String -> Bool
isOperator =
    Regex.contains operatorPattern


operatorPattern : Regex
operatorPattern =
    "^([=!<>]=?|\\+\\+?|\\|\\||&&|\\/\\/|->?|[?@])$"
        |> Regex.fromStringWith { caseInsensitive = False, multiline = False }
        |> Maybe.withDefault Regex.never



-- Strings


stringLiteral : Parser (List Token)
stringLiteral =
    oneOf
        [ multilineString
        , quote
        , doubleQuote
        ]


quote : Parser (List Token)
quote =
    delimited quoteDelimiter


quoteDelimiter : Delimiter Token
quoteDelimiter =
    { start = "'"
    , end = "'"
    , isNestable = False
    , defaultMap = \b -> ( T.C String, b )
    , innerParsers = [ lineBreakList, nixEscapable ]
    , isNotRelevant = \c -> not (isLineBreak c || isEscapable c)
    }


multilineString : Parser (List Token)
multilineString =
    delimited
        { quoteDelimiter
            | start = "''"
            , end = "''"
        }


doubleQuote : Parser (List Token)
doubleQuote =
    delimited
        { quoteDelimiter
            | start = "\""
            , end = "\""
        }


isStringLiteralChar : Char -> Bool
isStringLiteralChar c =
    c == '\'' || c == '"'



-- Comments


comment : Parser (List Token)
comment =
    oneOf
        [ inlineComment
        , multilineComment
        ]


inlineComment : Parser (List Token)
inlineComment =
    [ "#" ]
        |> List.map (symbol >> thenChompWhile (not << isLineBreak) >> getChompedString >> map (\b -> [ ( T.Comment, b ) ]))
        |> oneOf


multilineComment : Parser (List Token)
multilineComment =
    delimited
        { start = "/*"
        , end = "*/"
        , isNestable = False
        , defaultMap = \b -> ( T.Comment, b )
        , innerParsers = [ lineBreakList ]
        , isNotRelevant = not << isLineBreak
        }



-- Helpers


whitespaceOrCommentStep : List Token -> Parser (Step (List Token) (List Token))
whitespaceOrCommentStep revTokens =
    oneOf
        [ space |> map (\s -> Loop (s :: revTokens))
        , lineBreak
            |> map (\s -> s :: revTokens)
            |> andThen checkContext
        , comment |> map (\s -> Loop (s ++ revTokens))
        ]


checkContext : List Token -> Parser (Step (List Token) (List Token))
checkContext revTokens =
    oneOf
        [ whitespaceOrCommentStep revTokens
        , succeed (Done revTokens)
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


lineBreakList : Parser (List Token)
lineBreakList =
    symbol "\n"
        |> map (\_ -> [ ( T.LineBreak, "\n" ) ])


number : Parser Token
number =
    oneOf
        [ hexNumber
        , SyntaxHighlight.SyntaxHighlight.Language.Helpers.number
        ]
        |> getChompedString
        |> map (\b -> ( T.C Number, b ))


hexNumber : Parser ()
hexNumber =
    succeed ()
        |. backtrackable (symbol "0x")
        |. chompIfThenWhile Char.isHexDigit


nixEscapable : Parser (List Token)
nixEscapable =
    escapable
        |> getChompedString
        |> map (\b -> [ ( T.C Function, b ) ])


syntaxToStyle : Syntax -> ( Style.Required, String )
syntaxToStyle syntax =
    case syntax of
        Number ->
            ( Style1, "nix-n" )

        String ->
            ( Style2, "nix-s" )

        Keyword ->
            ( Style3, "nix-k" )

        Operator ->
            ( Style4, "nix-o" )

        Function ->
            ( Style5, "nix-f" )

        Punctuation ->
            ( Style6, "nix-p" )

        Literal ->
            ( Style7, "nix-l" )
