# Views

## Overview
Custom AppKit view subclasses for interactive UI controls.

## Interface
- `HyperlinkTextField.swift:HyperlinkTextField` — `@IBDesignable class HyperlinkTextField: NSTextField` exposing `@IBInspectable var href: String = ""`, `override func resetCursorRects()`, and `override func mouseDown(with theEvent: NSEvent)`.

## Invariants
- `HyperlinkTextField.swift:HyperlinkTextField.resetCursorRects()` discards existing cursor rects before adding `NSCursor.pointingHand` over `self.bounds`.
- `HyperlinkTextField.swift:HyperlinkTextField.mouseDown(with:)` only opens `href` when `URL(string: href)` returns a non-nil `URL`; empty or invalid strings are ignored.

## Side Effects
- `HyperlinkTextField.swift:HyperlinkTextField.resetCursorRects()` mutates AppKit cursor tracking rects for the view.
- `HyperlinkTextField.swift:HyperlinkTextField.mouseDown(with:)` calls `NSWorkspace.shared.open(_:)`, opening the target URL in the system's default handler.

## Verification
- Run: `make test`
