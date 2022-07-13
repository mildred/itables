import strformat

import nimx / [ custom_view, text_field, layout, scroll_view ]

import sheet_view

import spreadsheet_file
import spreadsheet_db

const margin = 5.0

type
  Cell* = ref object of RootObj
    coords*: Coords

  SheetUi* = ref object
    file*: Spreadsheet
    sheet*: Sheet
    selected*: Coords
    viewCoords*: Label

proc breadcrumb_name*(s: SheetUi): string = s.sheet.template.name

proc selectCell*(s: SheetUI, coords: Coords, cellView: CustomView) =
  s.selected = coords
  s.viewCoords.text = &"${coords.col}.{coords.row}"
  s.viewCoords.setNeedsDisplay()

proc makeLayout*(sheet: SheetUi, v: View) =
  v.makeLayout:
    - View as breadcrumb:
      background_color: new_color(1, 0, 0, 0.5)
      top == super.top
      left == super.left
      height == 32
      right == super.right
      - Label:
        text: "Sheet:"
        top == super.top + margin
        left == super.left + margin
        bottom == super.bottom - margin
        width == 64
      - TextField:
        text: sheet.breadcrumb_name()
        autoresizingMask: { afFlexibleWidth, afFlexibleMaxY }
        top == super.top + margin
        left == prev.right + margin
        bottom == super.bottom - margin
        right == super.right - margin
        width == super.width - prev.width - 3 * margin
    - View as top_bar:
      background_color: new_color(0, 1, 0, 0.5)
      top == prev.bottom
      left == super.left
      right == super.right
      height == 32
      - Label as viewCoords:
        text: ""
        top == super.top + margin
        left == super.left + margin
        bottom == super.bottom - margin
        width == 128
      - TextField:
        text: "=foo()"
        autoresizingMask: { afFlexibleWidth, afFlexibleMaxY }
        top == super.top + margin
        left == prev.right + margin
        right == super.right - margin
        bottom == super.bottom - margin
        width == super.width - prev.width - 3 * margin

    - ScrolledSheetView:
      background_color: new_color(0, 0, 0, 0.5)
      top == prev.bottom
      left == super
      right == super
      bottom == super
      sheet: sheet.sheet
      selected do(v: SheetView, cell: CustomView, coords: Coords):
        sheet.selectCell(coords, cell)
      onNewCol do():
        echo "on new col"
      onNewRow do():
        echo "on new row"

  sheet.viewCoords = viewCoords
