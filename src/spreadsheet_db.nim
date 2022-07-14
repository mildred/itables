import options
import strformat
import easy_sqlite3

import values

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

proc index*(ncols: int, coords: tuple[col, row: int]): int =
  result = (coords.row-1) * ncols + (coords.col-1)

proc coords*(ncols: int, idx: int): tuple[col, row: int] =
  result.col = idx %% ncols
  result.row = idx /% ncols

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

proc select_cell(template_id, col, row: int): Option[tuple[formula: string]] {.importdb: """
  SELECT formula FROM cells WHERE
    template_id = $template_id AND
    col = $col AND
    row = $row
""".}

proc upsert_cell(template_id, col, row: int, formula: string) {.importdb: """
  INSERT INTO cells (template_id, col, row, formula)
  VALUES ($template_id, $col, $row, $formula)
  ON CONFLICT (template_id, col, row) DO UPDATE SET
    formula = excluded.formula;
""".}

proc delete_from_cell_xref(template_id, col, row: int) {.importdb: """
  DELETE FROM cell_xref
  WHERE template_id = $template_id AND col = $col AND row = $row
""".}

proc insert_cell_xref(template_id, col, row, ref_template_id, ref_col, ref_row: int) {.importdb: """
  INSERT INTO cell_xref (template_id, col, row, ref_template_id, ref_col, ref_row)
  VALUES ($template_id, $col, $row, $ref_template_id, $ref_col, $ref_row)
""".}

iterator select_cell_xref_rdep(ref_template_id, ref_col, ref_row: int): tuple[template_id: int, col: int, row: int] {.importdb: """
  SELECT template_id, col, row
  FROM cell_xref
  WHERE ref_template_id = $ref_template_id AND ref_col = $ref_col AND ref_row = $ref_row
""".} = discard

iterator select_cell_xref_deep_rdep(ref_template_id, ref_col, ref_row: int): tuple[template_id: int, col: int, row: int] {.importdb: """
  WITH RECURSIVE t(template_id, col, row) AS (
    SELECT template_id, col, row
    FROM cell_xref
    WHERE ref_template_id = $ref_template_id AND ref_col = $ref_col AND ref_row = $ref_row
    UNION ALL
    SELECT x.template_id, x.col, x.row
    FROM cell_xref x JOIN t ON
      x.ref_template_id = t.template_id AND x.ref_col = t.col AND x.ref_row = t.row)
  SELECT template_id, col, row FROM t
""".} = discard

proc delete_results_recursive(template_id, col, row: int) {.importdb: """
  WITH RECURSIVE t(template_id, col, row) AS (
    SELECT $template_id, $col, $row
    UNION ALL
    SELECT cell_xref.template_id, cell_xref.col, cell_xref.row
    FROM cell_xref, t
    WHERE
      t.template_id = cell_xref.ref_template_id AND
      t.col = cell_xref.ref_col AND
      t.row = cell_xref.ref_row)
  DELETE FROM results WHERE EXISTS (
    SELECT 1 FROM t JOIN sheets ON sheets.template_id = t.template_id WHERE
      results.sheet_id = sheets.id AND
      results.col = t.col AND
      results.row = t.row)
""".}

proc upsert_result(sheet_id, col, row: int, valuetype, value: string) {.importdb: """
  INSERT INTO results (sheet_id, col, row, type, value)
  VALUES ($sheet_id, $col, $row, $valuetype, $value)
  ON CONFLICT (sheet_id, col, row) DO UPDATE SET
    type = excluded.type,
    value = excluded.value;
""".}

proc select_result(sheet_id, col, row: int): Option[tuple[value: string, typ: string]] {.importdb: """
  SELECT value, type
  FROM results
  WHERE sheet_id = $sheet_id AND col = $col AND row = $row
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

proc get_formula*(db: var Database, t: Template, col, row: int): string =
  let cell = db.select_cell(t.id, col, row)
  if cell.is_some:
    result = cell.get.formula

# Updates the formula, update the xrefs and delete stale results
# return the list of cells that needs update
proc set_formula*(db: var Database, t: Template, col, row: int, formula: string, deps: seq[tuple[col, row: int]]): seq[tuple[col, row: int]] =
  db.delete_from_cell_xref(t.id, col, row)
  db.delete_results_recursive(t.id, col, row)
  db.upsert_cell(t.id, col, row, formula)
  for dep in deps:
    db.insert_cell_xref(t.id, col, row, t.id, dep.col, dep.row)
  result.add((col: col, row: row))
  for rdep in db.select_cell_xref_deep_rdep(t.id, col, row):
    if rdep.template_id == t.id:
      result.add((col: rdep.col, row: rdep.row))

proc set_result*(db: var Database, s: Sheet, col, row: int, v: Value) =
  db.upsert_result(s.id, col, row, $v.type, v.toJSON())

proc get_result*(db: var Database, s: Sheet, col, row: int): Value =
  let res = db.select_result(s.id, col, row)
  if res.is_some and res.get.typ != "null":
    result = fromStrings(res.get.typ, res.get.value)
