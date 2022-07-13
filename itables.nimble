# Package

version       = "0.1.0"
author        = "Mildred"
description   = "Spreadsheet"
license       = "AGPL-3.0-or-later"
srcDir        = "src"
bin           = @["itables"]


# Dependencies

requires "nim >= 1.6.4"

requires "docopt"
requires "easysqlite3"

requires "nimx"
