//
//  PreferencesWindowController.swift
//
//  Fluor
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import Cocoa

final class PreferencesWindowController: NSWindowController, StoryboardInstantiable {
    static var storyboardName: NSStoryboard.Name = .preferences

    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window = window else { return }

        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        }

        setupGlassToolbar()

        let toolbar = window.toolbar
        let insertionIndex = max(0, (toolbar?.items.count ?? 0) - 1)
        toolbar?.insertItem(withItemIdentifier: .flexibleSpace, at: insertionIndex)
    }

    private func setupGlassToolbar() {
        guard let window = window, let toolbar = window.toolbar else { return }

        toolbar.allowsUserCustomization = false

        if let superview = toolbar.items.first?.view?.superview?.superview {
            superview.wantsLayer = true
            superview.layer?.backgroundColor = NSColor.clear.cgColor
        }

        for item in toolbar.items {
            item.view?.wantsLayer = true
            item.view?.layer?.backgroundColor = NSColor.clear.cgColor
            if let button = item.view as? NSButton {
                button.bezelStyle = .rounded
                button.isBordered = false
                button.contentTintColor = .labelColor
            }
        }
    }
}
