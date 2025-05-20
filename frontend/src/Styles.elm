module Styles exposing (..)

import Css exposing (..)
import Css.Global
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)



-- Define global styles


primaryBackgroundColor : Color
primaryBackgroundColor =
    hsla 210 0.40 0.98 1


globalStyles : Html msg
globalStyles =
    Css.Global.global
        [ Css.Global.body
            [ backgroundColor primaryBackgroundColor
            , color (hex "484848")
            , fullHeight
            ]
        , Css.Global.html
            [ fullHeight
            ]
        ]


fullHeight : Css.Style
fullHeight =
    batch
        [ Css.height (pct 100)
        , margin (px 0)
        ]


horizontalUlStyle : Css.Style
horizontalUlStyle =
    Css.batch
        [ listStyleType none
        , displayFlex
        , alignItems center
        ]



navItems : Css.Style
navItems =
    Css.batch
        [ textDecoration none
        , color (hex "333")
        ]


noMargin : Css.Style
noMargin =
    margin (px 0)
