module Icons exposing (..)

{-| Lucide icons (https://lucide.dev), drawn with `currentColor` so they follow the text color.
-}

import Html.Attributes
import Html.Styled exposing (Html)
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr


icon : Int -> List (Svg Never) -> Html msg
icon size paths =
    Svg.svg
        [ SvgAttr.width (String.fromInt size)
        , SvgAttr.height (String.fromInt size)
        , SvgAttr.viewBox "0 0 24 24"
        , SvgAttr.fill "none"
        , SvgAttr.stroke "currentColor"
        , SvgAttr.strokeWidth "2"
        , SvgAttr.strokeLinecap "round"
        , SvgAttr.strokeLinejoin "round"
        , SvgAttr.style "flex-shrink: 0"
        , Html.Attributes.attribute "aria-hidden" "true"
        ]
        paths
        |> Html.Styled.fromUnstyled
        |> Html.Styled.map never


path : String -> Svg Never
path d =
    Svg.path [ SvgAttr.d d ] []


circle : String -> String -> String -> Svg Never
circle cx cy r =
    Svg.circle [ SvgAttr.cx cx, SvgAttr.cy cy, SvgAttr.r r ] []


chevronLeft : Int -> Html msg
chevronLeft size =
    icon size [ path "m15 18-6-6 6-6" ]


chevronRight : Int -> Html msg
chevronRight size =
    icon size [ path "m9 18 6-6-6-6" ]


chevronUp : Int -> Html msg
chevronUp size =
    icon size [ path "m18 15-6-6-6 6" ]


chevronFirst : Int -> Html msg
chevronFirst size =
    icon size [ path "m17 18-6-6 6-6", path "M7 6v12" ]


chevronLast : Int -> Html msg
chevronLast size =
    icon size [ path "m7 18 6-6-6-6", path "M17 6v12" ]


play : Int -> Html msg
play size =
    icon size [ Svg.polygon [ SvgAttr.points "6 3 20 12 6 21 6 3" ] [] ]


squarePen : Int -> Html msg
squarePen size =
    icon size
        [ path "M12 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"
        , path "M18.375 2.625a1 1 0 0 1 3 3l-9.013 9.014a2 2 0 0 1-.853.505l-2.873.84a.5.5 0 0 1-.62-.62l.84-2.873a2 2 0 0 1 .506-.852z"
        ]


share : Int -> Html msg
share size =
    icon size
        [ path "M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"
        , Svg.polyline [ SvgAttr.points "16 6 12 2 8 6" ] []
        , Svg.line [ SvgAttr.x1 "12", SvgAttr.x2 "12", SvgAttr.y1 "2", SvgAttr.y2 "15" ] []
        ]


alignLeft : Int -> Html msg
alignLeft size =
    icon size [ path "M15 12H3", path "M17 18H3", path "M21 6H3" ]


heart : Int -> Html msg
heart size =
    icon size [ path "M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z" ]


star : Int -> Html msg
star size =
    icon size [ path "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z" ]


coffee : Int -> Html msg
coffee size =
    icon size
        [ path "M10 2v2"
        , path "M14 2v2"
        , path "M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14a4 4 0 1 1 0 8h-1"
        , path "M6 2v2"
        ]


messageSquare : Int -> Html msg
messageSquare size =
    icon size [ path "M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" ]


loader : Int -> Html msg
loader size =
    icon size [ path "M21 12a9 9 0 1 1-6.219-8.56" ]


info : Int -> Html msg
info size =
    icon size [ circle "12" "12" "10", path "M12 16v-4", path "M12 8h.01" ]


circleAlert : Int -> Html msg
circleAlert size =
    icon size [ circle "12" "12" "10", path "M12 8v4", path "M12 16h.01" ]


x : Int -> Html msg
x size =
    icon size [ path "M18 6 6 18", path "m6 6 12 12" ]


terminal : Int -> Html msg
terminal size =
    icon size [ Svg.polyline [ SvgAttr.points "4 17 10 11 4 5" ] [], path "M12 19h8" ]


clock : Int -> Html msg
clock size =
    icon size [ circle "12" "12" "10", Svg.polyline [ SvgAttr.points "12 6 12 12 16 14" ] [] ]
