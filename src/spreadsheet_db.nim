import options
import strformat
import easy_sqlite3

type
  Template* = ref object
    id*: int
    parent_id*: Option[int]
    parent*: Template
    name*: string
    nargs*: int
    nrows*: int
    ncols*: int
    result_row*: int
    result_col*: int
  Sheet* = ref object
    id*: int
    parent_id*: Option[int]
    template_id*: int
    `template`*: Template
    parent*: Sheet

proc get_user_version*(): tuple[value: int] {.importdb: "PRAGMA user_version".}
proc set_user_version*(db: var Database, v: int) =
  discard db.exec(&"PRAGMA user_version = {$v}")

proc get_root_sheet(): Option[tuple[id: int, template_id: int]] {.importdb: """
  SELECT id, template_id FROM sheets WHERE parent_id IS NULL LIMIT 1
""".}

proc insert_root_sheet(template_id: int): int {.importdb: """
  INSERT INTO sheets (parent_id, template_id) VALUES (NULL, $template_id)
""".}

proc get_template(id: int): Option[tuple[
    id: int,
    parent_id: int,
    name: string,
    nargs: int,
    nrows: int,
    ncols: int,
    result_row: int,
    result_col: int
  ]] {.importdb: """
  SELECT id, parent_id, name, nargs, nrows, ncols, result_row, result_col
  FROM templates WHERE id = $id
""".}

proc insert_root_template(name: string, nrows, ncols: int): int {.importdb: """
  INSERT INTO templates(parent_id, name, nrows, ncols, nargs, result_row, result_col)
  VALUES (NULL, $name, $nrows, $ncols, 0, -1, -1)
""".}

proc get_root_sheet*(db: var Database, defaultname: string, default_size: tuple[rows: int, cols: int]): Sheet =
  db.transaction:
    new result
    let root = db.get_root_sheet()
    result.template_id =
      if root.is_some: root.get.template_id
      else: db.insert_root_template(defaultname, default_size.rows, default_size.cols)
    result.id =
      if root.is_some: root.get.id
      else: db.insert_root_sheet(result.template_id)
    let templ = db.get_template(result.template_id).get
    result.template = Template(
      id: templ.id,
      parent_id: some templ.parent_id,
      name: templ.name,
      nargs: templ.nargs,
      nrows: templ.nrows,
      ncols: templ.ncols,
      result_row: templ.result_row,
      result_col: templ.result_col)

