import strformat

import nimx / [ custom_view, text_field, layout, scroll_view ]

import spreadsheet_file
import spreadsheet_db

const margin = 5.0

type
  Coords* = tuple[row: int, col: int]

  Cell* = ref object of RootObj
    coords*: Coords

  SheetUi* = ref object
    file*: Spreadsheet
    sheet*: Sheet
    cells*: seq[tuple[cell: Cell, view: CustomView]]
    selected*: Coords
    viewCoords*: Label

proc breadcrumb_name*(s: SheetUi): string = s.sheet.template.name
proc ncols*(s: SheetUi): int = s.sheet.template.ncols
proc nrows*(s: SheetUi): int = s.sheet.template.nrows

proc index*(s: SheetUi, coords: Coords): int =
  result = (coords.row-1) * s.ncols() + (coords.col-1)

proc coords*(s: SheetUI, idx: int): Coords =
  result.col = idx %% s.ncols()
  result.row = idx /% s.ncols()

proc selectCell*(s: SheetUI, cell: Cell, cellView: CustomView) =
  if s.selected.row > 0 and s.selected.col > 0:
    let v = s.cells[s.index(s.selected)].view
    v.background_color = new_color(0.75, 0.75, 0)
    v.setNeedsDisplay()
  s.selected = cell.coords
  cellView.background_color = new_color(0, 0, 1, 0.5)
  cellView.setNeedsDisplay()
  s.viewCoords.text = &"${cell.coords.col}.{cell.coords.row}"
  s.viewCoords.setNeedsDisplay()

proc makeLayout*(sheet: SheetUi, v: View) =
  v.makeLayout:
    - View as breadcrumb:
      background_color: new_color(1, 0, 0)
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
      background_color: new_color(0, 1, 0)
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

    - ScrollView:
      top == prev.bottom
      left == super
      right == super
      bottom == super
      background_color: new_color(0.5, 0.5, 0)

      - CustomView as spreadsheet:
        scrolled do(v: CustomView):
          echo &"update layout visible = {v.visibleRect}"
          v.removeAllSubviews()
          v.addConstraint(v.layout.vars.height == float(sheet.nrows * 32))
          v.addConstraint(v.layout.vars.width == float(sheet.ncols * 128))
          for col in 1 .. sheet.ncols:
            for row in 1 .. sheet.nrows:
              let cell = new(Cell)
              cell.coords.col = col
              cell.coords.row = row
              echo &"Generate cell ${col}.{row}"
              let cellView = CustomView.newView()
              cellView.makeLayout:
                data: cell
                background_color: new_color(0.75, 0.75, 0)
                event do(v: CustomView, e: var CustomEvent) -> bool:
                  if e.kind == Touch:
                    sheet.selectCell(Cell(v.data), v)
                    return true
                  else:
                    return false
                - Label:
                  frame == super
                  text: &"cell ${col}.{row}"
              cellView.addConstraint(cellView.layout.vars.left == v.layout.vars.left + float(128 * (col-1)))
              cellView.addConstraint(cellView.layout.vars.top == v.layout.vars.top + float(32 * (row-1)))
              cellView.addConstraint(cellView.layout.vars.height == 32)
              cellView.addConstraint(cellView.layout.vars.width == 128)
              v.addSubview(cellView)
              let idx = sheet.index((row, col))
              sheet.cells[idx] = (cell, cellView)
          # TODO: Determine the cells that are visible
          # TODO: lookup children and recycle cells that are not visible any more,
          # mark missing cells
          # TODO: create missing cells recycling cell objects that went invisible
  sheet.viewCoords = viewCoords
