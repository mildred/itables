import strformat

import nimx / [ view, context, scroll_view, event, layout, text_field, button ]

import nimx/custom_view
import spreadsheet_db

type
  Coords* = ref object of RootObj
    col*: int
    row*: int

  SheetView* = ref object of View
    sheet*:       Sheet
    selected*:    proc(v: SheetView, cell: CustomView, coords: Coords)
    cellValue*:   proc(v: SheetView, coords: Coords): string
    defineCols*:  proc(v: SheetView, left: Coord, widths: seq[int])
    defineRows*:  proc(v: SheetView, top: Coord, widths: seq[int])
    visibleRect*: Rect
    lastSelectedCell: CustomView

proc ncols*(s: Sheet): int = s.template.ncols
proc nrows*(s: Sheet): int = s.template.nrows

method init*(v: SheetView, r: Rect) =
  procCall v.View.init(r)
  v.visibleRect = zeroRect

proc scrolled(view: SheetView) =
  echo &"update layout visible = {view.visibleRect}"
  #echo &"SheetView.frame = {view.frame}"
  view.removeAllSubviews()
  view.addConstraint(view.layout.vars.height == float(view.sheet.nrows * 32))
  view.addConstraint(view.layout.vars.width == float(view.sheet.ncols * 128))
  var colHead: seq[int]
  var rowHead: seq[int]
  for row in 1 .. view.sheet.nrows:
    rowHead.add(32)
  for col in 1 .. view.sheet.ncols:
    colHead.add(128)
    for row in 1 .. view.sheet.nrows:
      let coords = Coords(col: col, row: row)
      #echo &"Generate cell ${col}.{row}"
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
          text: view.cellValue(view, Coords(col: col, row: row)) # &"cell ${col}.{row}"
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
  if view.defineRows != nil: view.defineRows(view, view.visibleRect.origin.y, rowHead)
  if view.defineCols != nil: view.defineCols(view, view.visibleRect.origin.x, colHead)

method updateLayout*(v: SheetView) =
  let vr = visibleRect(v)
  if v.visibleRect != vr:
    v.visibleRect = vr
    v.scrolled()
  procCall v.View.updateLayout()

proc get_cell(v: SheetView, col, row: int): CustomView =
  for child in v.subviews:
    if not (child of CustomView): continue
    let cell = CustomView(child)
    if not (cell.data of Coords): continue
    let coords = Coords(cell.data)
    if coords.row == row and coords.col == col:
      return cell
  return nil


proc set_value*(v: SheetView, col, row: int, value: string) =
  let cell = v.get_cell(col, row)
  if cell != nil:
    for child in cell.subviews:
      if not (child of Label): continue
      let label = Label(child)
      label.text = value

type ClipView* = ref object of View

method clipType*(v: ClipView): ClipType = ctDefaultClip

type ScrolledSheetView* = ref object of View
  sheet_view*: SheetView
  onNewRow*: proc()
  onNewCol*: proc()

method init*(view: ScrolledSheetView, rect: Rect) =
  proc_call view.View.init(rect)
  view.makeLayout:
    - ClipView as rowHeader:
      left == super
      width == 64
      top == next.bottom
      bottom == super.bottom
      background_color: new_color(1, 0, 0)
    - ClipView as colHeader:
      top == super
      left == prev.right
      right == super
      height == 32
      background_color: new_color(0.5, 0, 0)
    - ScrollView as scroll_view:
      top == prev.bottom
      left == prev.left
      right == super
      bottom == super

      - SheetView as sheet_view:
        top == super.top
        defineCols do(v: SheetView, left: Coord, cols: seq[int]):
          #echo &"SheetView.frame = {sheet_view.frame}"
          #echo &"ScrollView.frame = {scroll_view.frame}"
          #echo &"ScrolledSheetView.frame = {view.frame}"
          #echo &"defineCols {left}"
          colHeader.removeAllSubviews()
          var lastHeader: View
          for i, width in cols.pairs():
            let header = Label.newView()
            header.text = &"${i+1}"
            if lastHeader == nil:
              header.addConstraint(header.layout.vars.left == colHeader.layout.vars.left - float(left))
            else:
              header.addConstraint(header.layout.vars.left == lastHeader.layout.vars.right)
            header.addConstraint(header.layout.vars.top == colHeader.layout.vars.top)
            header.addConstraint(header.layout.vars.bottom == colHeader.layout.vars.bottom)
            header.addConstraint(header.layout.vars.width == float(width))
            colHeader.addSubview(header)
            lastHeader = header
          let newButton = Button.newView()
          newButton.title = "+"
          if lastHeader == nil:
            newButton.addConstraint(newButton.layout.vars.left == colHeader.layout.vars.left - float(left))
          else:
            newButton.addConstraint(newButton.layout.vars.left == lastHeader.layout.vars.right)
          newButton.addConstraint(newButton.layout.vars.top == colHeader.layout.vars.top)
          newButton.addConstraint(newButton.layout.vars.bottom == colHeader.layout.vars.bottom)
          newButton.addConstraint(newButton.layout.vars.width == 32)
          newButton.onAction do():
            if view.onNewCol != nil: view.onNewCol()
            #echo "new col"
          colHeader.addSubview(newButton)
        defineRows do(v: SheetView, top: Coord, rows: seq[int]):
          rowHeader.removeAllSubviews()
          #echo &"defineRows {top}"
          var lastHeader: View
          for i, height in rows.pairs():
            let header = Label.newView()
            header.text = &".{i+1}"
            if lastHeader == nil:
              header.addConstraint(header.layout.vars.top == rowHeader.layout.vars.top - float(top))
            else:
              header.addConstraint(header.layout.vars.top == lastHeader.layout.vars.bottom)
            header.addConstraint(header.layout.vars.left == rowHeader.layout.vars.left)
            header.addConstraint(header.layout.vars.right == rowHeader.layout.vars.right)
            header.addConstraint(header.layout.vars.height == float(height))
            rowHeader.addSubview(header)
            lastHeader = header
          let newButton = Button.newView()
          newButton.title = "+"
          if lastHeader == nil:
            newButton.addConstraint(newButton.layout.vars.top == rowHeader.layout.vars.top - float(top))
          else:
            newButton.addConstraint(newButton.layout.vars.top == lastHeader.layout.vars.bottom)
          newButton.addConstraint(newButton.layout.vars.left == rowHeader.layout.vars.left)
          newButton.addConstraint(newButton.layout.vars.right == rowHeader.layout.vars.right)
          newButton.addConstraint(newButton.layout.vars.height == 32)
          newButton.onAction do():
            if view.onNewRow != nil: view.onNewRow()
            #echo "new row"
          rowHeader.addSubview(newButton)

  view.sheet_view = sheet_view

proc `sheet=`*(v: ScrolledSheetView, sheet: Sheet) =
  v.sheet_view.sheet = sheet

proc `selected=`*(v: ScrolledSheetView, selected: typeof(v.sheet_view.selected)) =
  v.sheet_view.selected = selected

proc `cellValue=`*(v: ScrolledSheetView, cellValue: typeof(v.sheet_view.cellValue)) =
  v.sheet_view.cellValue = cellValue

proc set_value*(v: ScrolledSheetView, col, row: int, value: string) =
  v.sheet_view.set_value(col, row, value)
