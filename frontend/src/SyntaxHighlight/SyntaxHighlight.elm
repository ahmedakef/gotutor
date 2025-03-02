module SyntaxHighlight.SyntaxHighlight exposing
    ( HCode
    , toBlockHtml, toInlineHtml, toStaticBlockHtml, toStaticInlineHtml
    , Highlight(..), highlightLines
    , css, elm, javascript, python, sql, xml, json, nix, kotlin, noLang
    , Theme, useTheme, monokai, gitHub, oneDark
    , ConsoleOptions, toConsole
    , CustomTransform, toCustom
    , go
    )

{-| Syntax highlighting in Elm.

@docs HCode


## Html view

@docs toBlockHtml, toInlineHtml, toStaticBlockHtml, toStaticInlineHtml


## Helpers

@docs Highlight, highlightLines


## Languages

Error while parsing should not happen. If it happens, please [open an issue](https://github.com/pablohirafuji/elm-syntax-highlight/issues) with the code that gives the error and the language.

@docs css, elm, javascript, python, sql, xml, json, nix, kotlin, noLang


## Themes

@docs Theme, useTheme, monokai, gitHub, oneDark


## Console view

@docs ConsoleOptions, toConsole


## Custom transformation

@docs CustomTransform, toCustom

-}

import Html exposing (Html, text)
import Parser
import SyntaxHighlight.SyntaxHighlight.Language.Css as Css
import SyntaxHighlight.SyntaxHighlight.Language.Elm as Elm
import SyntaxHighlight.SyntaxHighlight.Language.Go as Go
import SyntaxHighlight.SyntaxHighlight.Language.Javascript as Javascript
import SyntaxHighlight.SyntaxHighlight.Language.Json as Json
import SyntaxHighlight.SyntaxHighlight.Language.Kotlin as Kotlin
import SyntaxHighlight.SyntaxHighlight.Language.Nix as Nix
import SyntaxHighlight.SyntaxHighlight.Language.NoLang as NoLang
import SyntaxHighlight.SyntaxHighlight.Language.Python as Python
import SyntaxHighlight.SyntaxHighlight.Language.Sql as Sql
import SyntaxHighlight.SyntaxHighlight.Language.Xml as Xml
import SyntaxHighlight.SyntaxHighlight.Line as Line exposing (Highlight, Line)
import SyntaxHighlight.SyntaxHighlight.Style as Style
import SyntaxHighlight.SyntaxHighlight.Theme as Theme
import SyntaxHighlight.SyntaxHighlight.View as View


{-| A highlighted code.
-}
type HCode
    = HCode (List Line)


{-| Transform a highlighted code into a Html block.
The `Maybe Int` argument is for showing or not line count and, if so, starting from what number.
-}
toBlockHtml : Maybe Int -> HCode -> Html msg
toBlockHtml maybeStart (HCode lines) =
    View.toBlockHtml maybeStart lines


{-| Transform a highlighted code into inline Html.

    import SyntaxHighlight exposing (elm, toInlineHtml)

    info : Html msg
    info =
        p []
            [ text "This function signature "
            , elm "isEmpty : String -> Bool"
                |> Result.map toInlineHtml
                |> Result.withDefault
                    (code [] [ text "isEmpty : String -> Bool" ])
            , text " means that a String argument is taken, then a Bool is returned."
            ]

-}
toInlineHtml : HCode -> Html msg
toInlineHtml (HCode lines) =
    View.toInlineHtml lines


{-| Transform a highlighted code into a static (pure text) Html block. The `Maybe Int` argument is for showing or not line count and, if so, starting from what number.
-}
toStaticBlockHtml : Maybe Int -> HCode -> String
toStaticBlockHtml maybeStart (HCode lines) =
    View.toStaticBlockHtml maybeStart lines


{-| Transform a highlighted code into static (pure text) inline Html.
-}
toStaticInlineHtml : HCode -> String
toStaticInlineHtml (HCode lines) =
    View.toStaticInlineHtml lines


{-| Parse Elm syntax.
-}
elm : String -> Result (List Parser.DeadEnd) HCode
elm =
    Elm.toLines
        >> Result.map HCode


{-| Parse XML syntax.
-}
xml : String -> Result (List Parser.DeadEnd) HCode
xml =
    Xml.toLines
        >> Result.map HCode


{-| Parse Javascript syntax.
-}
javascript : String -> Result (List Parser.DeadEnd) HCode
javascript =
    Javascript.toLines
        >> Result.map HCode


{-| Parse CSS syntax.
-}
css : String -> Result (List Parser.DeadEnd) HCode
css =
    Css.toLines
        >> Result.map HCode


{-| Parse Python syntax.
-}
python : String -> Result (List Parser.DeadEnd) HCode
python =
    Python.toLines
        >> Result.map HCode


{-| Parse Go syntax.
-}
go : String -> Result (List Parser.DeadEnd) HCode
go =
    Go.toLines
        >> Result.map HCode


{-| Parse SQL syntax.
-}
sql : String -> Result (List Parser.DeadEnd) HCode
sql =
    Sql.toLines
        >> Result.map HCode


{-| Parse JSON syntax.
-}
json : String -> Result (List Parser.DeadEnd) HCode
json =
    Json.toLines
        >> Result.map HCode


{-| Parse Nix syntax.
-}
nix : String -> Result (List Parser.DeadEnd) HCode
nix =
    Nix.toLines
        >> Result.map HCode


{-| Parse Kotlin syntax.
-}
kotlin : String -> Result (List Parser.DeadEnd) HCode
kotlin =
    Kotlin.toLines
        >> Result.map HCode


{-| Parse code from an unknown language with generic styling.
-}
noLang : String -> Result (List Parser.DeadEnd) HCode
noLang =
    NoLang.toLines
        >> Result.map HCode


{-| A theme defines the background and syntax colors.
-}
type Theme
    = Theme String


{-| Transform a theme into Html. Any highlighted code transformed into Html in the same page will be themed according to the chosen `Theme`.

To preview the themes, check out the [demo](https://pablohirafuji.github.io/elm-syntax-highlight/).

    import SyntaxHighlight exposing (elm, monokai, toBlockHtml, useTheme)

    view : Model -> Html msg
    view model =
        div []
            [ useTheme monokai
            , elm model.elmCode
                |> Result.map (toBlockHtml (Just 1))
                |> Result.withDefault
                    (pre [] [ code [] [ text model.elmCode ] ])
            ]

If you prefer to use CSS external stylesheet, you do **not** need this,
just copy the theme CSS into your stylesheet.
All themes can be found [here](https://pablohirafuji.github.io/elm-syntax-highlight/themes.html).

-}
useTheme : Theme -> Html msg
useTheme (Theme theme) =
    Html.node "style" [] [ text theme ]


{-| Monokai inspired theme.
-}
monokai : Theme
monokai =
    Theme Theme.monokai


{-| GitHub inspired theme.
-}
gitHub : Theme
gitHub =
    Theme Theme.gitHub


{-| Atom One Dark inspired theme.
-}
oneDark : Theme
oneDark =
    Theme Theme.oneDark


{-| Highlight type.

  - `Highlight` will highlight the line in a way to differentiate it from the rest, like github's yellow background.
  - `Add` will highlight in a manner that gives the ideia of new content added.
  - `Del` will highlight in a manner that gives the ideia of removed content.

The specific styles will depend on the chosen `Theme`.

-}
type Highlight
    = Highlight
    | Add
    | Del


{-| Highlight lines given a highlight type, start and end index.
If no highlight type is given (`Nothing`), it will remove any
highlight from the line range.
Negative indexes are taken starting from the _end_ of the list.
-}
highlightLines : Maybe Highlight -> Int -> Int -> HCode -> HCode
highlightLines maybeHighlight start end (HCode lines) =
    let
        maybeHighlight_ =
            case maybeHighlight of
                Nothing ->
                    Nothing

                Just Highlight ->
                    Just Line.Normal

                Just Add ->
                    Just Line.Add

                Just Del ->
                    Just Line.Del
    in
    Line.highlightLines maybeHighlight_ start end lines
        |> HCode


{-| Console styling options.
You can use the [rtfeldman/console-print](http://package.elm-lang.org/packages/rtfeldman/console-print/latest) package to fill in the styles.

The common uses of the styles are the following:

  - **default**: Default style
  - **highlight**: Highlight style
  - **addition**: Addition style
  - **deletion**: Deletion style
  - **comment**: Comment
  - **style1**: Number
  - **style2**: Literal string, attribute value
  - **style3**: Keyword, tag, operator symbols (=+-\*/...)
  - **style4**: Keyword 2, group symbols ({}(),), type signature
  - **style5**: Function, attribute name
  - **style6**: Literal keyword, capitalized types
  - **style7**: Argument, parameter

-}
type alias ConsoleOptions =
    { default : String -> String
    , highlight : String -> String
    , addition : String -> String
    , deletion : String -> String
    , comment : String -> String
    , style1 : String -> String
    , style2 : String -> String
    , style3 : String -> String
    , style4 : String -> String
    , style5 : String -> String
    , style6 : String -> String
    , style7 : String -> String
    }


{-| Transform a highlighted code into a list of console highlighted strings given the styling options defined by `ConsoleOptions`.
Each string in the list is a line.
-}
toConsole : ConsoleOptions -> HCode -> List String
toConsole options =
    toCustom
        { noOperation = String.concat
        , highlight = String.concat >> options.highlight
        , addition = String.concat >> options.addition
        , deletion = String.concat >> options.deletion
        , default = options.default
        , comment = options.comment
        , style1 = options.style1
        , style2 = options.style2
        , style3 = options.style3
        , style4 = options.style4
        , style5 = options.style5
        , style6 = options.style6
        , style7 = options.style7
        }


{-| Custom transform options.
The common uses of the styles are the following:

  - **noOperation**: No operation (aplly to the whole line)
  - **highlight**: Highlight style (aplly to the whole line)
  - **addition**: Addition style (aplly to the whole line)
  - **deletion**: Deletion style (aplly to the whole line)
  - **default**: Default style
  - **comment**: Comment
  - **style1**: Number
  - **style2**: Literal string, attribute value
  - **style3**: Keyword, tag, operator symbols (=+-\*/...)
  - **style4**: Keyword 2, group symbols ({}(),), type signature
  - **style5**: Function, attribute name
  - **style6**: Literal keyword, capitalized types
  - **style7**: Argument, parameter

-}
type alias CustomTransform fragment line =
    { noOperation : List fragment -> line
    , highlight : List fragment -> line
    , addition : List fragment -> line
    , deletion : List fragment -> line
    , default : String -> fragment
    , comment : String -> fragment
    , style1 : String -> fragment
    , style2 : String -> fragment
    , style3 : String -> fragment
    , style4 : String -> fragment
    , style5 : String -> fragment
    , style6 : String -> fragment
    , style7 : String -> fragment
    }


{-| Transform a highlighted code into a list of anything you want. Each `line` in the list corresponds to a line in the original code.
-}
toCustom : CustomTransform fragment line -> HCode -> List line
toCustom options (HCode lines) =
    List.map
        (\{ highlight, fragments } ->
            List.map (toCustomFragment options) fragments
                |> (\n ->
                        case highlight of
                            Nothing ->
                                options.noOperation n

                            Just Line.Normal ->
                                options.highlight n

                            Just Line.Add ->
                                options.addition n

                            Just Line.Del ->
                                options.deletion n
                   )
        )
        lines


toCustomFragment : CustomTransform fragment line -> Line.Fragment -> fragment
toCustomFragment options { text, requiredStyle, additionalClass } =
    case requiredStyle of
        Style.Default ->
            options.default text

        Style.Comment ->
            options.comment text

        Style.Style1 ->
            options.style1 text

        Style.Style2 ->
            options.style2 text

        Style.Style3 ->
            options.style3 text

        Style.Style4 ->
            options.style4 text

        Style.Style5 ->
            options.style5 text

        Style.Style6 ->
            options.style6 text

        Style.Style7 ->
            options.style7 text
