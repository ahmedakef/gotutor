module SyntaxHighlight.SyntaxHighlight.Theme exposing
    ( all
    , gitHub
    , monokai
    , oneDark
    )

import SyntaxHighlight.SyntaxHighlight.Theme.GitHub as GitHub
import SyntaxHighlight.SyntaxHighlight.Theme.Monokai as Monokai
import SyntaxHighlight.SyntaxHighlight.Theme.OneDark as OneDark



-- Add all themes name and code here to show in the Demo and Themes page


all : List ( String, String )
all =
    [ ( "Monokai", monokai )
    , ( "GitHub", gitHub )
    , ( "One Dark", oneDark )
    ]


monokai : String
monokai =
    Monokai.css


gitHub : String
gitHub =
    GitHub.css


oneDark : String
oneDark =
    OneDark.css
