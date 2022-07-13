import nimx / [ view, context, scroll_view, event ]

type
  CustomView* = ref object of View
    data*:         RootRef
    init*:         proc(v: CustomView)
    updateLayout*: proc(v: CustomView)
    scrolled*:     proc(v: CustomView)
    draw*:         proc(v: CustomView, c: GraphicsContext, rect: Rect)
    event*:        proc(v: CustomView, ev: var CustomEvent): bool
    visibleRect*:  Rect

  CustomEventKind* = enum
    Touch

  CustomEvent* = object
    ev*: Event
    kind*: CustomEventKind

proc newView*[T](t: typedesc[T]): T =
  new result
  init(result, zeroRect)

method init*(v: CustomView, r: Rect) =
  procCall v.View.init(r)
  v.visibleRect = zeroRect
  if v.init != nil:
    v.init(v)

method onTouchEv*(v: CustomView, e: var Event): bool =
  var ce = CustomEvent(
    ev: e,
    kind: Touch)
  if v.event == nil:
    return false
  else:
    result = v.event(v, ce)
    e = ce.ev

method draw*(v: CustomView, rect: Rect) =
  if v.draw == nil:
    procCall v.View.draw(rect)
  else:
    v.draw(v, currentContext(), rect)

# Taken from nimx/table_view
proc visibleRect*(v: View): Rect = # TODO: This can be more generic. Move to view.nim
    let s = v.superview
    if s.isNil: return zeroRect
    result = v.bounds
    if s of ScrollView:
        let o = v.frame.origin
        let sb = s.bounds.size
        if o.x < 0:
            result.origin.x += -o.x
            result.size.width += o.x
        if o.y < 0:
            result.origin.y += -o.y
            result.size.height += o.y

        if o.x + result.width > sb.width: result.size.width = sb.width - o.x
        if o.y + result.height > sb.height: result.size.height = sb.height - o.y
    else:
        result = v.bounds

method updateLayout*(v: CustomView) =
  let vr = visibleRect(v)
  if v.visibleRect != vr:
    v.visibleRect = vr
    if v.scrolled != nil:
      v.scrolled(v)
  if v.updateLayout == nil:
    procCall v.View.updateLayout()
  else:
    v.updateLayout(v)
