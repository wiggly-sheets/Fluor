//
//  PreferencesTabViewController.swift
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

class PreferencesTabViewController: NSTabViewController, TriggerSectionVisibilityDidChangePoster, SwitchMethodDidChangePoster {
    private var glassEffectView: NSVisualEffectView?
    private var tabGlassPanels: [NSView: NSVisualEffectView] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGlassBackground()
        setupTabGlassPanels()
        tabView.delegate = self
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        glassEffectView?.frame = view.bounds
    }

    private func setupGlassBackground() {
        let effectView = NSVisualEffectView()
        effectView.material = .sidebar
        effectView.blendingMode = .withinWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(effectView, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        glassEffectView = effectView

        tabView.drawsBackground = false
        tabView.wantsLayer = true
        tabView.layer?.backgroundColor = NSColor.clear.cgColor

        for tabViewItem in tabViewItems {
            tabViewItem.view?.wantsLayer = true
            tabViewItem.view?.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func setupTabGlassPanels() {
        for tabViewItem in tabViewItems {
            guard let tabView = tabViewItem.view else { continue }
            addGlassPanel(to: tabView)
        }
    }

    private func addGlassPanel(to tabView: NSView) {
        let panelView = NSVisualEffectView()
        panelView.material = .popover
        panelView.blendingMode = .withinWindow
        panelView.state = .active
        panelView.wantsLayer = true
        panelView.layer?.cornerRadius = 12
        panelView.layer?.masksToBounds = true
        panelView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addSubview(panelView, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: tabView.leadingAnchor, constant: 16),
            panelView.trailingAnchor.constraint(equalTo: tabView.trailingAnchor, constant: -16),
            panelView.topAnchor.constraint(equalTo: tabView.topAnchor, constant: 16),
            panelView.bottomAnchor.constraint(equalTo: tabView.bottomAnchor, constant: -16)
        ])

        tabGlassPanels[tabView] = panelView

        for subview in tabView.subviews {
            if subview is NSTextField || subview is NSButton || subview is NSSegmentedControl || subview is NSStackView {
                subview.wantsLayer = true
                subview.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }

    @IBAction func requestAccessibilityPermission(_ sender: Any) {
        guard !AXIsProcessTrusted() else { return }
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }

    @IBAction func changeTriggerSectionVisibility(_ sender: NSButton) {
        let visible = sender.state == .off
        if !visible {
            self.postSwitchMethodDidChangeNotification(method: .window)
            AppManager.default.switchMethod = .window
        }
        self.postTriggerSectionVisibilityDidChange(visible: visible)
    }
}

extension PreferencesTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let tabView = tabViewItem?.view else { return }
        if tabGlassPanels[tabView] == nil {
            addGlassPanel(to: tabView)
        }
    }
}
