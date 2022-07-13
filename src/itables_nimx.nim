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

  # First create a window. Window is the root of view hierarchy.
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
    #- CollectionView as collection: # TODO: CollectionView does not work with layout constraints
    #  left == super.left
    #  right == super.right
    #  top == prev.bottom
    #  bottom == super.bottom
    #  width == super.width
    #  height == super.height - 32 - 32
    #  item_size: new_size(128, 16)
    #  layout_direction: LayoutDirection.LeftToRight
    #  background_color: new_color(0, 0, 1)
    #  number_of_items do() -> int:
    #    echo "collection size: " & $(sheet.template.nrows * sheet.template.ncols)
    #    sheet.template.nrows * sheet.template.ncols
    #  view_for_item do(i: int) -> View:
    #    echo &"making cell #{i}"
    #    result = newView(newRect(0, 0, 128, 16))
    #    result.makeLayout:
    #      top == super.top + float(i * 16)
    #      left == super.left
    #      width == 128
    #      height == 16
    #      background_color: new_color(1, 1, 0)
    #      - Label:
    #        size == super.size
    #        origin == super.origin
    #        text: &"cell {i}"
    #    #discard newLabel(result, newPoint(0, 0), newSize(64, 8), &"cell {i}")
    #    result.background_color = new_color(0, 1, 1)
    #    #result = newView(newRect(0, 0, 100, 100))
    #    #discard newLabel(result, newPoint(0, 0), newSize(50, 50), &"cell {i}")
    #    #result.backgroundColor = newColor(1.0, 0.0, 0.0, 0.8)
    #    echo &"collection: {$collection.frame}"
    #    echo &"cell {i}: {$result.frame}"
    #    #echo w.dump()
    # - ScrollView:
    #   background_color: new_color(0, 0, 1)
    #   top == prev.bottom
    #   left == super.left
    #   width == super.width / 2
    #   #right == super.right
    #   bottom == super.bottom
    #   #frame == inset(super, margin)
    #   #size >= [200, 500]
    #   #- View:
    #   #  size == [100, 900]
    #   - TableView as tv:
    #     #height == float(sheet.template.nrows * 32)
    #     numberOfRows do() -> int:
    #       sheet.template.nrows * sheet.template.ncols

    #     heightOfRow do(row: int) -> Coord:
    #       32

    #     createCell do() -> TableViewCell:
    #       result = TableViewCell.new(zeroRect)
    #       result.makeLayout:
    #         top == super
    #         #bottom == super
    #         height == 32

    #         - Label:
    #           frame == super
    #           width == 128
    #           #height == 32

    #     configureCell do(c: TableViewCell):
    #       Label(c.subviews[0]).text = &"cell {c.row}"

    - ScrollView:
      top == prev.bottom
      left == super
      right == super
      bottom == super
      # top == prev
      # bottom == prev
      # left == prev.right
      # right == super.right
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

  #tv.reloadData()
  #for c in tv.constraints: tv.removeConstraint(c)
  #tv.constraints.setLen(0)
  #tv.constraints.add(tv.layout.vars.height == float(sheet.template.nrows * 32))
  #tv.addConstraint(tv.constraints[0])
  #tv.addConstraint(tv.layout.vars.height == float(sheet.template.nrows * sheet.template.ncols * 32))

  #w.updateLayout()
  #collection.updateLayout()

  #w.recursiveUpdateLayout(newPoint(0, 0))

  #collection.setFrame(new_rect(0, 0, 512, 512))

  #echo &"breadcrumb: {breadcrumb.frame}"
  #echo &"top_bar:    {top_bar.frame}"
  #echo &"collection: {collection.frame}"
  #echo w.dump()

# Run the app
proc start*(filename: string) =
  runApplication:
    startApp(filename)

