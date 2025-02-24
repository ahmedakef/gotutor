module Helpers.Hex exposing (intToHex)

import BigInt



-- limitation: gives correct results for 23-bit integers only
-- e.g. 13758215386640155000 -> 0x32e00000000000 while it should be 0xBEEF000000000178
-- show only last 8 digits of the hex number


intToHex : Int -> String
intToHex n =
    let
        hexN =
            BigInt.fromInt n
                |> BigInt.toHexString

        nStr =
            String.slice (String.length hexN - 8) (String.length hexN) hexN
    in
    if n < 0 then
        "-0x" ++ nStr

    else
        "0x" ++ nStr



-- toHexHelper : Int -> String
-- toHexHelper n =
--     if n < 16 then
--         singleHexDigit n
--     else
--         let
--             quotient =
--                 n // 16
--             remainder =
--                 modBy 16 n
--         in
--         toHexHelper quotient ++ singleHexDigit remainder
-- singleHexDigit : Int -> String
-- singleHexDigit n =
--     case n of
--         0 ->
--             "0"
--         1 ->
--             "1"
--         2 ->
--             "2"
--         3 ->
--             "3"
--         4 ->
--             "4"
--         5 ->
--             "5"
--         6 ->
--             "6"
--         7 ->
--             "7"
--         8 ->
--             "8"
--         9 ->
--             "9"
--         10 ->
--             "a"
--         11 ->
--             "b"
--         12 ->
--             "c"
--         13 ->
--             "d"
--         14 ->
--             "e"
--         15 ->
--             "f"
--         _ ->
--             ""
