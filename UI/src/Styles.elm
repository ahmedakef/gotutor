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
        , flexDirection column
        , alignItems center
        ]



-- Define the styles for the horizontal list


horizontalUlStyle : List Css.Style
horizontalUlStyle =
    [ listStyleType none
    , padding (px 0)
    , margin (px 0)
    , displayFlex
    ]


horizontalLiStyle : List Css.Style
horizontalLiStyle =
    [ marginRight (px 20)
    ]



-- Define the horizontalUL component


horizontalUL : List (Html msg) -> Html msg
horizontalUL items =
    ul [ css horizontalUlStyle ]
        (List.map (\item -> li [ css horizontalLiStyle ] [ item ]) items)


codeBlock : Css.Style
codeBlock =
    Css.batch
        [ backgroundColor (hex "f5f5f5")
        , border3 (px 1) solid (hex "ddd")
        , borderRadius (px 5)
        , fontFamilies ["Courier New", "Courier", "monospace"]
        , fontSize (px 14)
        , overflowX auto
        , color (hex"333")
        ]
