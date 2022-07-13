import docopt
import itables_nimx

const version {.strdefine.}: string = "(no version information)"
const doc = ("""
iTables is a new generation spreadsheet

Usage: itables [options]

Options:
  -h, --help                Print help
  -f, --file <file>         Spreadsheet file [default: spreadsheet.its]
""") & (when not defined(version): "" else: &"""

Version: {version}
""")

let args = docopt(doc)

start($args["--file"])
