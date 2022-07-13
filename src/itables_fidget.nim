import std/strformat, std/hashes, std/sequtils, std/os, strutils

import fidgetty
import fidgetty/themes
import fidgetty/[button, dropdown, checkbox]
import fidgetty/[slider, progressbar, animatedProgress]
import fidgetty/[listbox]
import fidgetty/[textinput]

when defined(emscripten):
  {.emit: """
  void glfwGetMonitorContentScale(void *monitor, float *xscale, float *yscale) {
    if(xscale) *xscale = 1.0;
    if(yscale) *yscale = 1.0;
  }
  """.}

echo "Hello from nim"

loadFont("IBM Plex Sans", "IBMPlexSans-Regular.ttf")

echo "font loaded"

proc iTables*(): ITables {.appFidget.} =
  properties:
    num: int

  render:
    #echo "windowFrame: " & $windowFrame.x & " " & $windowFrame.y
    #echo "windowSize: " & $windowSize.x & " " & $windowSize.y
    echo "render " & $root.box.w & " " & $root.box.h
    frame "main":
      box_of root
      layout lmVertical
      item_spacing 0

      group "head":
        fill "#0000FF"
        #org_box 0, 0, 256, 48
        size parent.box.w, 48
        constraints cStretch, cMin
        layout lmHorizontal
        item_spacing 8
        horizontalPadding 8
        verticalPadding 8

        rectangle "coords":
          fill "#FFFFFF"
          size 128, parent.box.h

        rectangle "formula":
          fill "#FFFFFF"
          # 128 == parent.nodes[^1].box.w ???
          size parent.box.w - 128 - 3*8, parent.box.h
          #size 256 - 128 - 3*8, parent.box.h
          #constraints cStretch, cMin

      group:
        fill "#888800"
        orgBox 0, 0, 100, 100
        size 25'vw, 25'vh

        rectangle:
          box 90, 90, 10, 10 - 100
          constraints cMax, cStretch
          fill "#000000"

      group:
        fill "#00FF00"
        size 128, 128

        frame:
          orgBox 16, 32, 96, 64
          #orgBox 0, 0, 128, 128
          #box 16, 32, 64, 64
          box parent.box
          fill "#0000ff"

          rectangle:
            box 8, 8, 8, 8
            constraints cStretch, cStretch
            fill "#000000"

      group "body":
        fill "#00FF00"
        horizontalPadding 8
        verticalPadding 8
        size 25'vw, 25'vh
        #size 400, 400
        size 100, 100


        frame "constraints":
          # Got to specify orgBox for constraints to work.
          orgBox 0, 0, 400, 400
          # Then grow the normal box.
          box parent.box
          # Constraints will work on the difference between orgBox and box.
          fill "#88ff88"
          rectangle "Center":
            box 150, 150, 100, 100
            constraints cCenter, cCenter
            fill "#f8c5a8"
            fill "#ff9999"
          rectangle "Scale":
            box 100, 100, 200, 200
            constraints cScale, cScale
            fill "#ffac7d"
            fill "#006666"
          rectangle "LRTB":
            box 40, 40, 320, 320
            constraints cStretch, cStretch
            fill "#ff8846"
            fill "#003333"
          rectangle "TR":
            box 360, 20, 20, 20
            constraints cMax, cMin
            fill "#ff5b00"
            fill "#ee0000"
          rectangle "TL":
            box 20, 20, 20, 20
            constraints cMin, cMin
            fill "#ff5b00"
            fill "#aa0000"
          rectangle "BR":
            box 360, 360, 20, 20
            constraints cMax, cMax
            fill "#ff5b00"
            fill "#660000"
          rectangle "BL":
            box 20, 360, 20, 20
            constraints cMin, cMax
            fill "#ff5b00"
            fill "#220000"

      #box 0, 0, root.box.w, root.box.h
      #group "head":
      #  box 0, 0, parent.box.w, 48
      #  fill "#0000FF"
      #  rectangle "coords":
      #    box 8, 8, 128, 32
      #    fill "#FFFFFF"
      #  rectangle "formula":
      #    box 8+128+8, 8, parent.box.w-(8+128+8)-8, 32
      #    fill "#FFFFFF"
      #group "workArea":
      #  box 0, 48, parent.box.w, parent.box.h-48
      #  fill "#00FF00"

proc exampleApp*(): ExampleApp {.appFidget.} =
  ## defines a stateful app widget
  properties:
    count1: int
    count2: int
    value: float
    scrollValue: float
    myCheck: bool
    mySlider: float
    dropIndexes: int = -1
    textInput: string

  render:

    let currEvents = useEvents()
    let dropItems = @["Nim", "UI", "in", "100%", "Nim", "to",
                      "OpenGL", "Immediate", "mode"]

    setTitle(fmt"Fidget Animated Progress Example")
    textStyle theme
    fill palette.background.lighten(0.11)

    # font "IBM Plex Sans", 16, 200, 0, hCenter, vCenter

    Vertical:
      ## Debugging button
      Button:
        label: "Dump"
        setup:
          fill "#DFDFF0"
        onClick:
          echo "dump: "
          dumpTree(root)

    group "center":
      box 50, 0, 100'vw - 100, 100'vh
      orgBox 50, 0, 100'vw, 100'vw
      fill palette.background.darken(1'PP)
      strokeWeight 1

      self.value = (self.count1.toFloat * 0.10) mod 1.0
      var delta = 0.0
      Vertical:
        blank: size(0, 0)
        itemSpacing 1.5'em

        Vertical:
          itemSpacing 1.5'em
          # Trigger an animation on animatedProgress below
          Button:
            label: fmt"Arg Incr {self.count1:4d}"
            onClick:
              self.count1.inc()
              delta = 0.02
          Horizontal:
            itemSpacing 4'em
            Button:
              label: fmt"Evt Incr {self.count2:4d}"
              onClick:
                self.count2.inc()
                currEvents["pbc1"] = IncrementBar(increment = 0.02)
            Theme(warningPalette()):
              Checkbox:
                value: self.myCheck
                text: fmt"Click {self.myCheck}"

        let ap1 = AnimatedProgress:
          delta: delta
          setup:
            bindEvents "pbc1", currEvents
            width 100'pw - 8'em

        Horizontal:
          Button:
            label: fmt"Animate"
            onClick:
              self.count2.inc()
              currEvents["pbc1"] = JumpToValue(target = 0.01)
          Button:
            label: fmt"Cancel"
            onClick:
              currEvents["pbc1"] = CancelJump()
          Dropdown:
            items: dropItems
            selected: self.dropIndexes
            label: "Menu"
            setup: size 12'em, 2'em

        text "data":
          size 60'vw, 2'em
          fill "#000000"
          # characters: fmt"AnimatedProgress value: {ap1.value:>6.2f}"
          characters: fmt"selected: {self.dropIndexes}"
        Slider:
          value: ap1.value
          setup: size 60'vw, 2'em
        Listbox:
          items: dropItems
          selected: self.dropIndexes
          itemsVisible: 4
          setup:
            size 60'vw, 2'em
            bindEvents "lstbx", currEvents
        Slider:
          value: self.scrollValue
          setup: size 60'vw, 2'em
          onChange:
            currEvents["lstbx"] = ScrollTo(self.scrollValue)
        TextInputBind:
          value: self.textInput
          setup: size 60'vw, 2'em
        Button:
          label: fmt"{self.textInput}"
          disabled: true
          setup: size 60'vw, 2'em
      palette.accent = parseHtml("#87E3FF", 0.67).spin(ap1.value * 36)

when defined(emscripten):
  let w = getEnv("WINDOW_WIDTH", "800").parseInt
  let h = getEnv("WINDOW_HEIGHT", "600").parseInt
else:
  let w = 800
  let h = 600

startFidget(
  #wrapApp(exampleApp, ExampleApp),
  wrapApp(iTables, ITables),
  setup =
    when defined(demoBulmaTheme): setup(bulmaTheme)
    else: setup(grayTheme),
  w = w,
  h = h,
  uiScale = 1.0
)
