import strformat

import nimx / [ view, context, scroll_view, event, layout, text_field ]

import nimx/custom_view
import spreadsheet_db

type
  Coords* = ref object of RootObj
    col*: int
    row*: int

  SheetView* = ref object of View
    sheet*:       Sheet
    selected*:    proc(v: SheetView, cell: CustomView, coords: Coords)
    visibleRect:  Rect
    lastSelectedCell: CustomView

proc ncols*(s: Sheet): int = s.template.ncols
proc nrows*(s: Sheet): int = s.template.nrows

method init*(v: SheetView, r: Rect) =
  procCall v.View.init(r)
  v.visibleRect = zeroRect

proc scrolled(view: SheetView) =
  echo &"update layout visible = {view.visibleRect}"
  view.removeAllSubviews()
  view.addConstraint(view.layout.vars.height == float(view.sheet.nrows * 32))
  view.addConstraint(view.layout.vars.width == float(view.sheet.ncols * 128))
  for col in 1 .. view.sheet.ncols:
    for row in 1 .. view.sheet.nrows:
      let coords = Coords(col: col, row: row)
      echo &"Generate cell ${col}.{row}"
      let cellView = CustomView.newView()
      cellView.makeLayout:
        data: coords
        background_color: new_color(0.75, 0.75, 0)
        event do(v: CustomView, e: var CustomEvent) -> bool:
          if e.kind == Touch:
            let coords = Coords(v.data)
            if view.lastSelectedCell != nil:
              view.lastSelectedCell.background_color = new_color(0.75, 0.75, 0)
              view.lastSelectedCell.setNeedsDisplay()
            view.lastSelectedCell = v
            v.background_color = new_color(0, 0, 1, 0.5)
            v.setNeedsDisplay()
            view.selected(view, v, coords)
            return true
          else:
            return false
        - Label:
          frame == super
          text: &"cell ${col}.{row}"
      cellView.addConstraint(cellView.layout.vars.left == view.layout.vars.left + float(128 * (col-1)))
      cellView.addConstraint(cellView.layout.vars.top == view.layout.vars.top + float(32 * (row-1)))
      cellView.addConstraint(cellView.layout.vars.height == 32)
      cellView.addConstraint(cellView.layout.vars.width == 128)
      view.addSubview(cellView)
      #let idx = index(view.sheet.template.ncols, (col, row))
      #view.cells[idx] = (cell, cellView)
  # TODO: Determine the cells that are visible
  # TODO: lookup children and recycle cells that are not visible any more,
  # mark missing cells
  # TODO: create missing cells recycling cell objects that went invisible

method updateLayout*(v: SheetView) =
  let vr = visibleRect(v)
  if v.visibleRect != vr:
    v.visibleRect = vr
    v.scrolled()
  procCall v.View.updateLayout()

type ScrolledSheetView* = ref object of View
  sheet_view*: SheetView

method init*(v: ScrolledSheetView, rect: Rect) =
  proc_call v.View.init(rect)
  v.makeLayout:
    - ScrollView:
      frame == super
      background_color: new_color(0.5, 0.5, 0)

      - SheetView as sheet_view:
        top == 0

  v.sheet_view = sheet_view

proc `sheet=`*(v: ScrolledSheetView, sheet: Sheet) =
  v.sheet_view.sheet = sheet

proc `selected=`*(v: ScrolledSheetView, selected: typeof(v.sheet_view.selected)) =
  v.sheet_view.selected = selected
