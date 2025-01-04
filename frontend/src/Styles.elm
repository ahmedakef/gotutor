module Styles exposing (..)

import Css exposing (..)
import Css.Global
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)



-- Define global styles


globalStyles : Html msg
globalStyles =
    Css.Global.global
        [ Css.Global.body
            [ backgroundColor (hex "FAFAFA")
            , color (hex "333333")
            ]
        ]


container : Css.Style
container =
    Css.batch
        [ displayFlex
        ]


flexColumn : Css.Style
flexColumn =
    Css.batch
        [ flex (num 1)
        , padding (px 10)
        ]


flexCenter : Css.Style
flexCenter =
    Css.batch
        [ displayFlex
        , alignItems center
        , flexDirection column
        ]


horizontalUlStyle : Css.Style
horizontalUlStyle =
    Css.batch
        [ listStyleType none
        , padding (px 0)
        , margin (px 0)
        , displayFlex
        ]


horizontalLiStyle : Css.Style
horizontalLiStyle =
    Css.batch
        [ marginRight (px 20)
        ]


navItems : Css.Style
navItems =
    Css.batch
        [ textDecoration none
        , color (hex "333")
        ]


codeBlock : Css.Style
codeBlock =
    Css.batch
        [ backgroundColor (hex "f5f5f5")
        , border3 (px 1) solid (hex "ddd")
        , borderRadius (px 5)
        , fontFamilies [ "Courier New", "Courier", "monospace" ]
        , fontSize (px 14)
        , overflowX auto
        , color (hex "333")
        , padding (px 5)
        ]
