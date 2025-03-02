module SyntaxHighlight.SyntaxHighlight.Language.Go exposing
    ( Syntax(..)
    , syntaxToStyle
      -- Exposing for tests purpose
    , toLines
    , toRevTokens
    )

import Parser exposing ((|.), (|=), DeadEnd, Parser, Step(..), andThen, chompIf, getChompedString, loop, map, oneOf, succeed, symbol)
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
    | DeclarationKeyword
    | Type
    | Function
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
        , chompIf (always True)
            |> getChompedString
            |> map (\b -> Loop (( T.Normal, b ) :: revTokens))
        , succeed (Done revTokens)
        ]


keywordParser : List Token -> String -> Parser (List Token)
keywordParser revTokens n =
    if isKeyword n then
        succeed (( T.C Keyword, n ) :: revTokens)

    else if isType n then
        succeed (( T.C Type, n ) :: revTokens)

    else if isPackage n then
        succeed (( T.C Package, n ) :: revTokens)

    else
        succeed (( T.Normal, n ) :: revTokens)


isIdentifierNameChar : Char -> Bool
isIdentifierNameChar c =
    Char.isAlphaNum c || c == '_' || Char.toCode c > 127


isIdentifierStartChar : Char -> Bool
isIdentifierStartChar c =
    Char.isAlpha c || c == '_' || Char.toCode c > 127



-- numbers


number : Parser Token
number =
    oneOf
        [ hexNumber
        , octalNumber
        , float
        , integer
        ]
        |> map (\s -> ( T.C Number, s ))


hexNumber : Parser String
hexNumber =
    succeed (\n -> "0x" ++ n)
        |. symbol "0"
        |. oneOf [ symbol "x", symbol "X" ]
        |= getChompedString (chompIfThenWhile isHexDigit)


octalNumber : Parser String
octalNumber =
    succeed (\n -> "0o" ++ n)
        |. symbol "0"
        |. oneOf [ symbol "o", symbol "O" ]
        |= getChompedString (chompIfThenWhile isOctalDigit)


float : Parser String
float =
    succeed (++)
        |= getChompedString (chompIfThenWhile Char.isDigit)
        |. symbol "."
        |= getChompedString (chompIfThenWhile Char.isDigit)


integer : Parser String
integer =
    getChompedString (chompIfThenWhile Char.isDigit)


isHexDigit : Char -> Bool
isHexDigit c =
    Char.isDigit c || Set.member c hexLetterSet


isOctalDigit : Char -> Bool
isOctalDigit c =
    c >= '0' && c <= '7'


hexLetterSet : Set Char
hexLetterSet =
    Set.fromList [ 'a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D', 'E', 'F' ]



-- Reserved Words


isKeyword : String -> Bool
isKeyword str =
    Set.member str keywords || Set.member str types


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


lineBreakList : Parser (List Token)
lineBreakList =
    symbol "\n"
        |> map (\_ -> [ ( T.LineBreak, "\n" ) ])


syntaxToStyle : Syntax -> ( Style.Required, String )
syntaxToStyle syntax =
    case syntax of
        Number ->
            ( Style1, "number" )

        String ->
            ( Style2, "string" )

        Keyword ->
            ( Style3, "keyword" )

        DeclarationKeyword ->
            ( Style3, "declaration-keyword" )

        Type ->
            ( Style4, "type" )

        Function ->
            ( Style5, "function" )

        Package ->
            ( Style3, "package" )

        Operator ->
            ( Style3, "operator" )

        Param ->
            ( Style3, "param" )
