//
//  MoverEffectView.swift
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

final class MoverEffectView: NSView {
    private var glassView: NSGlassEffectView?

    override func awakeFromNib() {
        super.awakeFromNib()
        configureGlass()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureGlass()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configureGlass() {
        guard glassView == nil else { return }

        let glassView = NSGlassEffectView()
        glassView.style = .regular
        glassView.cornerRadius = 12
        glassView.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 27.0, *) {
            glassView.effectIsInteractive = false
        }

        addSubview(glassView, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        self.glassView = glassView
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)
        return hitView === glassView ? self : hitView
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        window.performDrag(with: event)
    }
}
