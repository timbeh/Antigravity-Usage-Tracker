//
//  MenuBarManager.swift
//  Antigravity Usage Tracker
//
//  Created by Tim Behrends on 04.05.26.
//

import SwiftUI
import AppKit
import Combine

class MenuBarManager: NSObject {
    private var quotaManager: QuotaManager
    private var statusItems: [UUID: NSStatusItem] = [:]
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    
    init(quotaManager: QuotaManager) {
        self.quotaManager = quotaManager
        super.init()
        
        // Observe changes to menuBarItems
        quotaManager.$menuBarItems
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateItems()
            }
            .store(in: &cancellables)
            
        // Also observe changes to data to refresh icons
        quotaManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Small delay to ensure data is updated
                DispatchQueue.main.async {
                    self?.refreshIcons()
                }
            }
            .store(in: &cancellables)
            
        setupPopover()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("CloseMenuBarPopover"), object: nil, queue: .main) { [weak self] _ in
            self?.popover?.performClose(nil)
        }
    }
    
    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(quotaManager: quotaManager))
        self.popover = popover
    }
    
    func updateItems() {
        // Clear existing items
        for item in statusItems.values {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()
        
        // Create new items
        for config in quotaManager.menuBarItems {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            if let button = statusItem.button {
                let iconView = MenuBarIconView(mode: config.mode, quotaManager: quotaManager)
                let hostingView = NSHostingView(rootView: iconView)
                
                // Set frame based on content
                let size = hostingView.intrinsicContentSize
                hostingView.frame = NSRect(x: 0, y: 0, width: max(size.width, 22), height: 22)
                
                button.addSubview(hostingView)
                button.frame = hostingView.frame
                
                button.target = self
                button.action = #selector(statusItemClicked(_:))
            }
            
            statusItems[config.id] = statusItem
        }
    }
    
    func refreshIcons() {
        for (id, statusItem) in statusItems {
            if let config = quotaManager.menuBarItems.first(where: { $0.id == id }),
               let button = statusItem.button {
                
                // Re-create the hosting view to force refresh
                let iconView = MenuBarIconView(mode: config.mode, quotaManager: quotaManager)
                let hostingView = NSHostingView(rootView: iconView)
                let size = hostingView.intrinsicContentSize
                hostingView.frame = NSRect(x: 0, y: 0, width: max(size.width, 22), height: 22)
                
                // Remove old hosting views
                button.subviews.forEach { $0.removeFromSuperview() }
                button.addSubview(hostingView)
                button.frame = hostingView.frame
            }
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
