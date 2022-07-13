import strformat
import nimx / [ window, layout, button, text_field, split_view, scroll_view, context, button, text_field, collection_view, table_view, custom_view ]

import spreadsheet_file
import spreadsheet_db

const margin = 5.0

type
  Coords = ref object of RootObj
    col: int
    row: int

proc startApp(filename: string) =

  let f = open_spreadsheet(filename)

  let sheet = f.db.get_root_sheet("default", (5,5))

  var w = newWindow(newRect(40, 40, 800, 600))

  echo &"start {sheet.template.name}"

  w.makeLayout:
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
        text: sheet.template.name
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
      - Label as cellCoords:
        text: "A1"
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
          v.addConstraint(v.layout.vars.height == float(sheet.template.nrows * 32))
          v.addConstraint(v.layout.vars.width == float(sheet.template.ncols * 128))
          for col in 1 .. sheet.template.ncols:
            for row in 1 .. sheet.template.nrows:
              let coords = new(Coords)
              coords.col = col
              coords.row = row
              echo &"Generate cell ${col}.{row}"
              let cell = CustomView.newView()
              cell.makeLayout:
                data: coords
                background_color: new_color(0.75, 0.75, 0)
                event do(v: CustomView, e: var CustomEvent) -> bool:
                  if e.kind == Touch:
                    echo &"Touch cell {cellCoords.text} {v.background_color}"
                    v.background_color = newColor(0, 0, 1, 0.5)
                    v.setNeedsDisplay()
                    let coords = Coords(v.data)
                    cellCoords.text = &"${coords.col}.{coords.row}"
                    cellCoords.setNeedsDisplay()
                    return true
                  else:
                    return false
                - Label:
                  frame == super
                  text: &"cell ${col}.{row}"
              cell.addConstraint(cell.layout.vars.left == v.layout.vars.left + float(128 * (col-1)))
              cell.addConstraint(cell.layout.vars.top == v.layout.vars.top + float(32 * (row-1)))
              cell.addConstraint(cell.layout.vars.height == 32)
              cell.addConstraint(cell.layout.vars.width == 128)
              v.addSubview(cell)
          # Determine the cells that are visible
          # lookup children and recycle cells that are not visible any more,
          # mark missing cells
          # create missing cells recycling cell objects that went invisible

proc start*(filename: string) =
  runApplication:
    startApp(filename)

