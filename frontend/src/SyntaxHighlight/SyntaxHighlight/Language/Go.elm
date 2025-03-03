module SyntaxHighlight.SyntaxHighlight.Language.Go exposing
    ( Syntax(..)
    , syntaxToStyle
      -- Exposing for tests purpose
    , toLines
    , toRevTokens
    )

import Parser exposing ((|.), (|=), DeadEnd, Parser, Step(..), andThen, backtrackable, chompIf, getChompedString, loop, map, oneOf, succeed, symbol)
import Set exposing (Set)
import SyntaxHighlight.SyntaxHighlight.Language.Helpers exposing (Delimiter, chompIfThenWhile, delimited, isLineBreak, isSpace, isWhitespace, thenChompWhile)
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
    | DeclarationKeyword
    | Type
    | Function
    | LiteralKeyword
    | Package
    | Operator
    | Param


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
        [ whitespaceOrCommentStep revTokens
        , stringLiteral
            |> map (\s -> Loop (s ++ revTokens))
        , oneOf
            [ operatorChar
            , groupChar
            , number
            ]
            |> map (\s -> Loop (s :: revTokens))
        , chompIfThenWhile isIdentifierNameChar
            |> getChompedString
            |> andThen (keywordParser revTokens)
            |> map Loop
        , succeed (Done revTokens)
        ]


keywordParser : List Token -> String -> Parser (List Token)
keywordParser revTokens n =
    if n == "func" then
        loop (( T.C DeclarationKeyword, n ) :: revTokens) functionDeclarationLoop

    else if isType n then
        succeed (( T.C Type, n ) :: revTokens)

    else if isPackage n then
        succeed (( T.C Package, n ) :: revTokens)

    else if isKeyword n then
        succeed (( T.C Keyword, n ) :: revTokens)

    else if isDeclarationKeyword n then
        succeed (( T.C DeclarationKeyword, n ) :: revTokens)

    else if isLiteralKeyword n then
        succeed (( T.C LiteralKeyword, n ) :: revTokens)

    else
        succeed (( T.Normal, n ) :: revTokens)


functionDeclarationLoop : List Token -> Parser (Step (List Token) (List Token))
functionDeclarationLoop revTokens =
    oneOf
        [ whitespaceOrCommentStep revTokens
        , chompIfThenWhile isIdentifierNameChar
            |> getChompedString
            |> map (\b -> Loop (( T.C Function, b ) :: revTokens))
        , symbol "("
            |> andThen
                (\_ -> loop (( T.Normal, "(" ) :: revTokens) argLoop)
            |> map Loop
        , succeed (Done revTokens)
        ]


argLoop : List Token -> Parser (Step (List Token) (List Token))
argLoop revTokens =
    oneOf
        [ whitespaceOrCommentStep revTokens
        , chompIfThenWhile (\c -> not (isCommentChar c || isWhitespace c || c == ',' || c == ')'))
            |> getChompedString
            |> andThen (argParser revTokens)
            |> map Loop
        , chompIfThenWhile (\c -> c == '/' || c == ',')
            |> getChompedString
            |> map (\b -> Loop (( T.Normal, b ) :: revTokens))
        , succeed (Done revTokens)
        ]


argParser : List Token -> String -> Parser (List Token)
argParser revTokens n =
    if isType n || String.startsWith n "[]" then
        succeed (( T.C Type, n ) :: revTokens)

    else
        succeed (( T.C Param, n ) :: revTokens)


isIdentifierNameChar : Char -> Bool
isIdentifierNameChar c =
    Char.isAlphaNum c || c == '_' || Char.toCode c > 127



-- numbers


number : Parser Token
number =
    oneOf
        [ hexNumber
        , SyntaxHighlight.SyntaxHighlight.Language.Helpers.number
        , SyntaxHighlight.SyntaxHighlight.Language.Helpers.numberExponentialNotation
        ]
        |> getChompedString
        |> map (\b -> ( T.C Number, b ))


hexNumber : Parser ()
hexNumber =
    succeed ()
        |. backtrackable (symbol "0x")
        |. chompIfThenWhile Char.isHexDigit



-- Reserved Words


isKeyword : String -> Bool
isKeyword str =
    Set.member str keywords


keywords : Set String
keywords =
    Set.fromList
        [ "break"
        , "case"
        , "chan"
        , "continue"
        , "default"
        , "defer"
        , "else"
        , "fallthrough"
        , "for"
        , "go"
        , "goto"
        , "if"
        , "interface"
        , "map"
        , "range"
        , "return"
        , "select"
        , "struct"
        , "switch"
        ]


isType : String -> Bool
isType str =
    Set.member str types


types : Set String
types =
    Set.fromList
        [ "bool"
        , "byte"
        , "complex64"
        , "complex128"
        , "error"
        , "float32"
        , "float64"
        , "int"
        , "int8"
        , "int16"
        , "int32"
        , "int64"
        , "rune"
        , "string"
        , "uint"
        , "uint8"
        , "uint16"
        , "uint32"
        , "uint64"
        , "uintptr"
        ]


isDeclarationKeyword : String -> Bool
isDeclarationKeyword str =
    Set.member str declarationKeywords


declarationKeywords : Set String
declarationKeywords =
    Set.fromList
        [ "func"
        , "type"
        , "var"
        , "const"
        , "import"
        ]


isPackage : String -> Bool
isPackage str =
    str == "package"


operatorChar : Parser Token
operatorChar =
    chompIf isOperator
        |> getChompedString
        |> map (\s -> ( T.C Operator, s ))


isOperator : Char -> Bool
isOperator c =
    Set.member c operatorSet


operatorSet : Set Char
operatorSet =
    Set.fromList [ '+', '-', '*', '/', '%', '&', '|', '^', '<', '>', '=', '!', ':', '.' ]


groupChar : Parser Token
groupChar =
    chompIf isGroupChar
        |> getChompedString
        |> map (\s -> ( T.Normal, s ))


isGroupChar : Char -> Bool
isGroupChar c =
    Set.member c groupCharSet


groupCharSet : Set Char
groupCharSet =
    Set.fromList [ '(', ')', '[', ']', '{', '}', ',', ';' ]


isLiteralKeyword : String -> Bool
isLiteralKeyword str =
    Set.member str literalKeywordSet


literalKeywordSet : Set String
literalKeywordSet =
    Set.fromList
        [ "true"
        , "false"
        , "nil"
        ]



-- String literal


stringLiteral : Parser (List Token)
stringLiteral =
    oneOf
        [ rawString
        , normalString
        ]


rawString : Parser (List Token)
rawString =
    let
        delimiter : Delimiter (T.Token Syntax)
        delimiter =
            { start = "`"
            , end = "`"
            , isNestable = False
            , defaultMap = \b -> ( T.C String, b )
            , innerParsers = []
            , isNotRelevant = \_ -> True
            }
    in
    delimited delimiter


normalString : Parser (List Token)
normalString =
    let
        delimiter : Delimiter (T.Token Syntax)
        delimiter =
            { start = "\""
            , end = "\""
            , isNestable = False
            , defaultMap = \b -> ( T.C String, b )
            , innerParsers = []
            , isNotRelevant = \c -> not (c == '"')
            }
    in
    delimited delimiter



-- Comments


comment : Parser (List Token)
comment =
    oneOf
        [ inlineComment
        , multilineComment
        ]


inlineComment : Parser (List Token)
inlineComment =
    symbol "//"
        |> thenChompWhile (not << isLineBreak)
        |> getChompedString
        |> map (\b -> [ ( T.Comment, b ) ])


multilineComment : Parser (List Token)
multilineComment =
    delimited
        { start = "/*"
        , end = "*/"
        , isNestable = False
        , defaultMap = \b -> ( T.Comment, b )
        , innerParsers = [ lineBreakList ]
        , isNotRelevant = \c -> not (isLineBreak c)
        }


isCommentChar : Char -> Bool
isCommentChar c =
    c == '/'



-- Helpers


whitespaceOrCommentStep : List Token -> Parser (Step (List Token) (List Token))
whitespaceOrCommentStep revTokens =
    oneOf
        [ chompIfThenWhile isSpace
            |> getChompedString
            |> map (\b -> Loop (( T.Normal, b ) :: revTokens))
        , lineBreakList
            |> map (\ns -> Loop (ns ++ revTokens))
        , comment
            |> map (\ns -> Loop (ns ++ revTokens))
        ]


lineBreakList : Parser (List Token)
lineBreakList =
    symbol "\n"
        |> map (\_ -> [ ( T.LineBreak, "\n" ) ])


syntaxToStyle : Syntax -> ( Style.Required, String )
syntaxToStyle syntax =
    case syntax of
        Number ->
            ( Style1, "go-n" )

        String ->
            ( Style2, "go-s" )

        Keyword ->
            ( Style3, "go-k" )

        DeclarationKeyword ->
            ( Style3, "go-dk" )

        Type ->
            ( Style4, "go-t" )

        Function ->
            ( Style5, "go-f" )

        LiteralKeyword ->
            ( Style6, "go-lk" )

        Package ->
            ( Style3, "go-p" )

        Operator ->
            ( Style3, "go-o" )

        Param ->
            ( Style7, "go-param" )
