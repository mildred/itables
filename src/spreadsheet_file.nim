import easy_sqlite3
import spreadsheet_db
import spreadsheet_migrations

type Spreadsheet = ref object
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
