module Styles exposing (..)

import Css exposing (..)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)

import Css.Global

-- Define global styles
globalStyles :  Html msg
globalStyles =
    Css.Global.global
        [ Css.Global.body
            [ backgroundColor (hex "FAFAFA")
            , color (hex "333333")
            ]
        ]


container :  Css.Style
container =
     Css.batch [ displayFlex
    ]

flexColumn : Css.Style
flexColumn =
    Css.batch [ flex (num 1)
    , padding (px 10)
    ]

flexCenter : Css.Style
flexCenter =
    Css.batch [ displayFlex
    , flexDirection column
    , alignItems center
    ]


-- Define the styles for the horizontal list
horizontalUlStyle : List (Css.Style)
horizontalUlStyle =
    [ listStyleType none
    , padding (px 0)
    , margin (px 0)
    , displayFlex
    ]

horizontalLiStyle : List (Css.Style)
horizontalLiStyle =
    [ marginRight (px 20)
    ]

-- Define the horizontalUL component
horizontalUL : List (Html msg) -> Html msg
horizontalUL items =
    ul [ css horizontalUlStyle ]
        (List.map (\item -> li [ css horizontalLiStyle ] [ item ]) items)
