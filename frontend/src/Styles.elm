module Styles exposing (..)

{-| Design tokens and shared component styles. Every color the UI uses should come from here,
so the look can be changed (or a dark theme added) in one place.
-}

import Css
import Css.Global
import Html.Styled exposing (Html)
import Tailwind.Theme as Tw
import Tailwind.Utilities as Tw



-- TOKENS


{-| The color of the GoTutor wordmark.
-}
brand : Css.Color
brand =
    Css.hex "007d9c"


brandHover : Css.Color
brandHover =
    Css.hex "00657e"


{-| Go's cyan, used for accents like the current line and focus rings.
-}
brandBright : Css.Color
brandBright =
    Css.hex "00add8"


stringColor : Css.Color
stringColor =
    Css.hex "df5000"


numberColor : Css.Color
numberColor =
    Css.hex "005cc5"


boolColor : Css.Color
boolColor =
    Css.hex "d73a49"


sansFontStack : String
sansFontStack =
    "Inter, ui-sans-serif, system-ui, -apple-system, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif"


monoFontStack : String
monoFontStack =
    "\"JetBrains Mono\", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"



-- GLOBAL


globalStyles : Html msg
globalStyles =
    Css.Global.global
        -- only the `--tw-*` variable defaults, so rings, shadows and blurs work; not the full preflight
        (List.take 2 Tw.globalStyles
            ++ [ Css.Global.everything [ Css.boxSizing Css.borderBox ]
               , Css.Global.selector "*, ::before, ::after"
                    [ Css.borderWidth Css.zero
                    , Css.borderStyle Css.solid
                    , Tw.border_color Tw.slate_200
                    ]
               , Css.Global.html [ fullHeight ]
               , Css.Global.body
                    [ fullHeight
                    , Css.property "font-family" sansFontStack
                    , Css.fontSize (Css.px 14)
                    , Css.lineHeight (Css.num 1.5)
                    , Tw.text_color Tw.slate_700
                    , Tw.bg_color Tw.slate_50
                    , Tw.antialiased
                    ]
               , Css.Global.each [ Css.Global.h1, Css.Global.h2, Css.Global.h3, Css.Global.p, Css.Global.ul, Css.Global.ol ]
                    [ Css.margin Css.zero ]
               , Css.Global.each [ Css.Global.button, Css.Global.input, Css.Global.select, Css.Global.textarea ]
                    [ Css.property "font" "inherit", Css.color Css.inherit ]
               , Css.Global.a
                    [ Css.color brand
                    , Css.textDecoration Css.none
                    , Css.hover [ Css.textDecoration Css.underline ]
                    ]
               ]
        )


fullHeight : Css.Style
fullHeight =
    Css.batch
        [ Css.height (Css.pct 100)
        , Css.margin (Css.px 0)
        ]



-- TEXT


mono : Css.Style
mono =
    Css.property "font-family" monoFontStack


{-| Small uppercase label used for section headings.
-}
sectionTitle : Css.Style
sectionTitle =
    Css.batch
        [ Tw.text_xs
        , Tw.font_semibold
        , Tw.uppercase
        , Tw.tracking_wide
        , Tw.text_color Tw.slate_500
        ]


muted : Css.Style
muted =
    Css.batch [ Tw.text_xs, Tw.text_color Tw.slate_500 ]


focusRing : Css.Style
focusRing =
    Css.batch
        [ Css.focus [ Css.outline Css.none ]
        , Css.pseudoClass "focus-visible"
            [ Css.outline3 (Css.px 2) Css.solid brandBright
            , Css.outlineOffset (Css.px 2)
            ]
        ]



-- BUTTONS


{-| Hover styles that don't apply to disabled buttons.
-}
hoverEnabled : List Css.Style -> Css.Style
hoverEnabled =
    Css.pseudoClass "hover:not(:disabled)"


buttonBase : Css.Style
buttonBase =
    Css.batch
        [ Css.property "appearance" "none"
        , Tw.inline_flex
        , Tw.items_center
        , Tw.justify_center
        , Tw.gap_2
        , Tw.whitespace_nowrap
        , Tw.text_sm
        , Tw.font_medium
        , Tw.leading_5
        , Tw.h_9
        , Tw.px_3
        , Tw.rounded_md
        , Tw.border
        , Tw.border_color Tw.transparent
        , Tw.bg_color Tw.transparent
        , Css.color Css.inherit
        , Css.margin Css.zero
        , Css.textDecoration Css.none
        , Css.cursor Css.pointer
        , Tw.transition_colors
        , Css.hover [ Css.textDecoration Css.none ]
        , focusRing
        , Css.disabled [ Css.opacity (Css.num 0.55), Css.cursor Css.notAllowed ]
        ]


{-| A smaller button for pane toolbars.
-}
buttonSm : Css.Style
buttonSm =
    Css.batch [ Tw.h_8, Tw.px_2_dot_5, Tw.gap_1_dot_5 ]


buttonPrimary : Css.Style
buttonPrimary =
    Css.batch
        [ buttonBase
        , Css.backgroundColor brand
        , Tw.text_color Tw.white
        , Tw.shadow_sm
        , hoverEnabled [ Css.backgroundColor brandHover ]
        ]


buttonSecondary : Css.Style
buttonSecondary =
    Css.batch
        [ buttonBase
        , Tw.bg_color Tw.white
        , Tw.border_color Tw.slate_300
        , Tw.text_color Tw.slate_700
        , Tw.shadow_sm
        , hoverEnabled [ Tw.bg_color Tw.slate_50, Tw.text_color Tw.slate_900 ]
        ]


buttonGhost : Css.Style
buttonGhost =
    Css.batch
        [ buttonBase
        , Tw.text_color Tw.slate_600
        , hoverEnabled [ Tw.bg_color Tw.slate_100, Tw.text_color Tw.slate_900 ]
        ]


{-| A square button holding only an icon; give it an `aria-label`.
-}
iconButton : Css.Style
iconButton =
    Css.batch [ Tw.px_0, Tw.w_9 ]



-- FORMS


input : Css.Style
input =
    Css.batch
        [ Tw.h_9
        , Tw.px_3
        , Tw.text_sm
        , Tw.bg_color Tw.white
        , Tw.border
        , Tw.border_color Tw.slate_300
        , Tw.rounded_md
        , Tw.shadow_sm
        , Css.focus
            [ Css.outline Css.none
            , Css.borderColor brandBright
            , Tw.ring_2
            , Tw.ring_color Tw.cyan_100
            ]
        ]


select : Css.Style
select =
    Css.batch
        [ Css.property "appearance" "none"
        , Tw.h_8
        , Tw.pl_2_dot_5
        , Tw.pr_8
        , Tw.text_sm
        , Tw.bg_color Tw.white
        , Tw.border
        , Tw.border_color Tw.slate_300
        , Tw.rounded_md
        , Tw.shadow_sm
        , Tw.text_color Tw.slate_700
        , Css.cursor Css.pointer
        , Css.property "background-image" "url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2364748b' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3e%3cpath d='m6 9 6 6 6-6'/%3e%3c/svg%3e\")"
        , Css.property "background-position" "right 0.5rem center"
        , Css.property "background-size" "1rem"
        , Css.property "background-repeat" "no-repeat"
        , hoverEnabled [ Tw.bg_color Tw.slate_50 ]
        , focusRing
        ]


checkbox : Css.Style
checkbox =
    Css.batch
        [ Css.margin Css.zero
        , Css.cursor Css.pointer
        , Css.property "accent-color" "#007d9c"
        ]



-- SURFACES


card : Css.Style
card =
    Css.batch
        [ Tw.bg_color Tw.white
        , Tw.border
        , Tw.border_color Tw.slate_200
        , Tw.rounded_lg
        , Tw.shadow_sm
        ]


{-| The bar at the top of the editor and state panes.
-}
panelHeader : Css.Style
panelHeader =
    Css.batch
        [ Tw.flex_none
        , Tw.flex
        , Tw.flex_wrap
        , Tw.items_center
        , Tw.justify_between
        , Tw.gap_2
        , Css.minHeight (Css.rem 2.75)
        , Tw.px_3
        , Tw.py_1_dot_5
        , Tw.border_b
        , Tw.bg_color Tw.white
        ]


alertBase : Css.Style
alertBase =
    Css.batch
        [ Tw.rounded_lg
        , Tw.border
        , Tw.px_4
        , Tw.py_3
        , Tw.text_sm
        ]


alertInfo : Css.Style
alertInfo =
    Css.batch
        [ alertBase
        , Tw.bg_color Tw.sky_50
        , Tw.border_color Tw.sky_200
        , Tw.text_color Tw.sky_900
        ]


alertDanger : Css.Style
alertDanger =
    Css.batch
        [ alertBase
        , Tw.bg_color Tw.red_50
        , Tw.border_color Tw.red_200
        , Tw.text_color Tw.red_800
        ]


{-| A small rounded label, e.g. a duration or a file location.
-}
chip : Css.Style
chip =
    Css.batch
        [ mono
        , Tw.inline_flex
        , Tw.items_center
        , Tw.gap_1
        , Tw.text_xs
        , Tw.leading_5
        , Tw.px_1_dot_5
        , Tw.rounded
        , Tw.bg_color Tw.slate_100
        , Tw.text_color Tw.slate_600
        ]
