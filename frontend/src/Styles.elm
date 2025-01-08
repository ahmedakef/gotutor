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
        , fontSize (px 20)
        ]


horizontalLiStyle : Css.Style
horizontalLiStyle =
    Css.batch
        [ margin2 (px 0) (px 10)
        , padding (px 5)
        , borderRadius (px 5)
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


requiredShStyles : String
requiredShStyles =
    """
pre.elmsh {
    padding: 5px;
    margin: 0;
    text-align: left;
    overflow: auto;
    // my styles
    background-color: #f5f5f5;
    border: 1px solid #ddd;
    border-radius: 5px;


}
code.elmsh {
    padding: 0;
    // my styles
    font-family: "Courier New", Courier, monospace;
    font-size: 14px;
    font-family: "Courier New", Courier, monospace;
    overflow-x: auto;
    color: #333;

}
.elmsh-line:before {
    content: attr(data-elmsh-lc);
    display: inline-block;
    text-align: right;
    width: 20px;
    padding: 0 20px 0 0;
    opacity: 0.3;
}
.elmsh-add {
    background-color: #b3e0b3;
    }
.elmsh-hl {
    background-color:#dce5ef;
    }
    """
