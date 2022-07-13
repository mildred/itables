import strutils
import strformat
import easy_sqlite3
import spreadsheet_db

proc migrate*(db: var Database): bool =
  var user_version = db.get_user_version().value
  if user_version == 0:
    echo "Initialise database..."
  var migrating = true
  while migrating:
    db.transaction:
      var description: string
      let old_version = user_version
      case user_version
      of 0:
        description = "database initialized"
        db.exec("""
          CREATE TABLE IF NOT EXISTS templates (
            id            INTEGER PRIMARY KEY NOT NULL,
            parent_id     INTEGER,
            name          TEXT NOT NULL,
            nargs         INTEGER NOT NULL,
            nrows         INTEGER NOT NULL,
            ncols         INTEGER NOT NULL,
            result_col    INTEGER NOT NULL,
            result_row    INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES templates (id),
            CONSTRAINT sheet_unique_name UNIQUE (parent_id, name)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS sheets (
            id            INTEGER PRIMARY KEY NOT NULL,
            parent_id     INTEGER,
            template_id   INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES sheets (id)
            FOREIGN KEY (template_id) REFERENCES templates (id)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS cells (
            template_id   INTEGER NOT NULL,
            row           INTEGER NOT NULL,
            col           INTEGER NOT NULL,
            formula       TEXT NOT NULL,
            PRIMARY KEY (template_id, row, col),
            FOREIGN KEY (template_id) REFERENCES templates (id)
          );
        """)
        db.exec("""
          CREATE TABLE IF NOT EXISTS results (
            sheet_id      INTEGER NOT NULL,
            row           INTEGER NOT NULL,
            col           INTEGER NOT NULL,
            type          TEXT NOT NULL,
            value         JSON NOT NULL,
            PRIMARY KEY (sheet_id, row, col),
            FOREIGN KEY (sheet_id) REFERENCES sheets (id)
          );
        """)
        user_version = 1
      else:
        migrating = false
      if migrating:
        if old_version == user_version:
          echo &"Failed migration at v{user_version}"
          return false
        db.set_user_version(user_version)
        if description == "":
          echo &"Migrated database v{old_version} to v{user_version}"
        else:
          echo &"Migrated database v{old_version} to v{user_version}: {description}"
  echo "Finished database initialization"
  return true

