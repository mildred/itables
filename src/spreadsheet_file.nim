import easy_sqlite3
import spreadsheet_db
import spreadsheet_migrations

import formula
import formula_parser
import values

type Spreadsheet* = ref object
  filename*: string
  db*: Database

export Sheet
export Template

proc open_spreadsheet*(filename: string): Spreadsheet =
  new(result)
  result.filename = filename
  result.db = initDatabase(filename)
  if not result.db.migrate():
    return nil

proc set_formula*(s: Spreadsheet, t: Template, col, row: int, f: Formula): seq[tuple[col, row: int]] =
  let deps = f.expr.get_deps()
  result = s.db.set_formula(t, col, row, f.code, deps)

proc get_or_compute_cell*(s: Spreadsheet, sh: Sheet, col, row: int): Value

proc compute_cell*(s: Spreadsheet, sh: Sheet, f: Formula, col, row: int): Value =
  result = f.expr.compute() do(c, r: int) -> Value:
    if col == c and row == r:
      Value(type: ErrorType, valueError: "RECURSIVE")
    else:
      s.get_or_compute_cell(sh, c, r)
  s.db.set_result(sh, col, row, result)

proc get_or_compute_cell*(s: Spreadsheet, sh: Sheet, col, row: int): Value =
  result = s.db.get_result(sh, col, row)
  if result.isNil:
    let code = s.db.get_formula(sh.template, col, row)
    let f: Formula = parse(code)
    result = s.compute_cell(sh, f, col, row)

