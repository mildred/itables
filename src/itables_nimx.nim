import strformat
import nimx / [ window, layout, button, text_field, split_view, scroll_view, context, button, text_field, collection_view, table_view, custom_view ]

import spreadsheet_file
import spreadsheet_db
import sheet_ui

const margin = 5.0

proc startApp(filename: string) =

  var w = newWindow(newRect(40, 40, 800, 600))

  let f = open_spreadsheet(filename)
  let sheet = SheetUi(
    file: f,
    sheet: f.db.get_root_sheet("default", (5,5)))
  sheet.cells.setlen(sheet.nrows() * sheet.ncols())

  echo &"start {sheet.breadcrumb_name()}"

  sheet.makeLayout(w)

proc start*(filename: string) =
  runApplication:
    startApp(filename)

