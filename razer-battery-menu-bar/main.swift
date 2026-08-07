//
//  main.swift
//  razer-battery-menu-bar
//
//  `@main` on the delegate routes to NSApplicationMain(), which on macOS assigns
//  NSApp.delegate from the main nib's File's Owner outlet. This target has no nib,
//  so the delegate stayed nil and applicationDidFinishLaunching() never ran - the
//  process sat in its run loop with no status item. Wire it up by hand instead.
//

import AppKit

let app = NSApplication.shared
// NSApp.delegate is weak: the delegate has to be owned by something that outlives run().
let delegate = AppDelegate()
app.delegate = delegate
app.run()
