module Styles exposing (..)

import Css exposing (..)
import Css.Global
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)



-- Define global styles


primaryBackgroundColor : Color
primaryBackgroundColor =
    hex "FAFAFA"


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
        , padding (px 0)
        , margin (px 0)
        , displayFlex
        , alignItems center
        , fontSize (px 20)
        ]


horizontalLiStyle : Css.Style
horizontalLiStyle =
    Css.batch
        [ margin2 (px 0) (px 10)
        , padding (px 5)
        , borderRadius (px 2)
        , hover
            [ backgroundColor (hex "f5f5f5") ]
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
