module Styles exposing (..)

import Css exposing (..)
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (..)

-- Define the styles for the horizontal list
horizontalUlStyle : List (Css.Style)
horizontalUlStyle =
    [ listStyleType none
    , padding (px 0)
    , margin (px 0)
    , display inlineFlex
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

-- Apply the styles in your view
view : Html msg
view =
    horizontalUL
        [ text "Item 1"
        , text "Item 2"
        , text "Item 3"
        ]
