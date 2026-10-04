import AppKit

final class ThemeLibraryWindow: NSWindowController {
    private let list = NSStackView()
    private let currentID: () -> String
    private let select: (IconTheme) -> Void

    init(currentID: @escaping () -> String, select: @escaping (IconTheme) -> Void) {
        self.currentID = currentID
        self.select = select
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L10n.text("theme_library")
        window.minSize = NSSize(width: 780, height: 420)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let content = window.contentView!
        let header = NSStackView()
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 10
        let title = label(L10n.text("theme_library"), size: 24, weight: .bold)
        header.addArrangedSubview(title)
        let hint = NSTextField(wrappingLabelWithString: L10n.text("theme_library_hint"))
        hint.textColor = .secondaryLabelColor
        header.addArrangedSubview(hint)
        let actions = NSStackView(views: [
            button("theme_import", #selector(importTheme)),
            button("theme_open_folder", #selector(openFolder)),
            button("theme_export_template", #selector(exportTemplate)),
            button("theme_refresh", #selector(reload))
        ])
        actions.spacing = 10
        header.addArrangedSubview(actions)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 14
        list.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 16, right: 0)
        scroll.documentView = list
        for view in [header, scroll, list] { view.translatesAutoresizingMaskIntoConstraints = false }
        content.addSubview(header)
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            list.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            list.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            list.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
        reload()
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func present() {
        reload()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
    private func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular) -> NSTextField {
        let result = NSTextField(labelWithString: text)
        result.font = .systemFont(ofSize: size, weight: weight)
        return result
    }
    private func button(_ key: String, _ action: Selector) -> NSButton {
        NSButton(title: L10n.text(key), target: self, action: action)
    }
    @objc private func reload() {
        ThemeLibrary.shared.reload()
        if let theme = IconTheme(rawValue: currentID()) { select(theme) }
        for view in list.arrangedSubviews { list.removeArrangedSubview(view); view.removeFromSuperview() }
        for theme in IconTheme.allCases { addRow(theme) }
    }
    private func addRow(_ theme: IconTheme) {
        let card = NSBox()
        card.boxType = .custom
        card.borderWidth = 1
        card.borderColor = .separatorColor
        card.fillColor = .controlBackgroundColor
        card.cornerRadius = 10
        card.contentViewMargins = NSSize(width: 16, height: 14)
        let body = NSStackView()
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 12
        let use = button(theme.rawValue == currentID() ? "theme_active" : "theme_use", #selector(choose(_:)))
        use.identifier = NSUserInterfaceItemIdentifier(theme.rawValue)
        use.isEnabled = theme.rawValue != currentID()
        let heading = NSStackView(views: [label(theme.displayName, size: 17, weight: .semibold),
            label(L10n.text(theme.isImported ? "theme_imported" : "theme_builtin")), NSView(), use])
        heading.spacing = 12
        body.addArrangedSubview(heading)
        let states: [(String, BatteryState, CGFloat, Bool)] = [
            ("theme_low", BatteryState(percent: 12, charging: false, pluggedIn: false, minutes: nil), 1, false),
            ("theme_normal", BatteryState(percent: 52, charging: false, pluggedIn: false, minutes: nil), 1, false),
            ("theme_high", BatteryState(percent: 92, charging: false, pluggedIn: false, minutes: nil), 1, false),
            ("theme_unknown", .unavailable, 1, false),
            ("theme_bright", BatteryState(percent: 52, charging: true, pluggedIn: true, minutes: nil), 1, false),
            ("theme_dim", BatteryState(percent: 52, charging: true, pluggedIn: true, minutes: nil), 0.35, false),
            ("theme_blink", BatteryState(percent: 52, charging: true, pluggedIn: true, minutes: nil), 1, true)
        ]
        let previews = NSStackView()
        previews.distribution = .fillEqually
        previews.spacing = 8
        for (key, state, opacity, blink) in states {
            let image = NSImageView()
            image.image = theme.image(state, ink: .black, boltOpacity: opacity, blink: blink)
            image.contentTintColor = .labelColor
            image.imageScaling = .scaleProportionallyUpOrDown
            image.setAccessibilityLabel(theme.displayName + " · " + L10n.text(key))
            image.widthAnchor.constraint(equalToConstant: 56).isActive = true
            image.heightAnchor.constraint(equalToConstant: 36).isActive = true
            let native = NSImageView()
            native.image = theme.image(state, ink: .black, boltOpacity: opacity, blink: blink)
            native.contentTintColor = .labelColor
            native.widthAnchor.constraint(equalToConstant: 28).isActive = true
            native.heightAnchor.constraint(equalToConstant: 18).isActive = true
            let column = NSStackView(views: [image, native, label(L10n.text(key))])
            column.orientation = .vertical
            column.alignment = .centerX
            column.spacing = 5
            previews.addArrangedSubview(column)
        }
        body.addArrangedSubview(previews)
        card.contentView?.addSubview(body)
        body.translatesAutoresizingMaskIntoConstraints = false
        let container = card.contentView!
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            body.topAnchor.constraint(equalTo: container.topAnchor),
            body.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            heading.widthAnchor.constraint(equalTo: body.widthAnchor),
            previews.widthAnchor.constraint(equalTo: body.widthAnchor)
        ])
        list.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
    }
    @objc private func choose(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let theme = IconTheme(rawValue: id) else { return }
        select(theme)
        reload()
    }
    @objc private func openFolder() {
        do {
            let directory = try ThemeLibrary.shared.ensureDirectory()
            guard NSWorkspace.shared.open(directory) else { throw ThemeImportError("theme_folder_error") }
        } catch { showError(error) }
    }
    @objc private func importTheme() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = L10n.text("theme_import_hint")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let prompt = NSAlert()
        prompt.messageText = L10n.text("theme_name_prompt")
        let name = NSTextField(string: folder.lastPathComponent)
        name.frame = NSRect(x: 0, y: 0, width: 340, height: 24)
        prompt.accessoryView = name
        prompt.addButton(withTitle: L10n.text("theme_import"))
        prompt.addButton(withTitle: L10n.text("theme_cancel"))
        guard prompt.runModal() == .alertFirstButtonReturn else { return }
        do {
            _ = try ThemeLibrary.shared.importTheme(from: folder, name: name.stringValue)
            reload()
        } catch { showError(error) }
    }
    @objc private func exportTemplate() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Battery Pie SVG Template"
        panel.message = L10n.text("theme_export_hint")
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            let source = PineappleTheme.assets.directory
            guard !FileManager.default.fileExists(atPath: destination.path) else { throw ThemeImportError("theme_export_exists") }
            try FileManager.default.copyItem(at: source, to: destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch { showError(error) }
    }
    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.text("theme_error_title")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: L10n.text("ok"))
        alert.runModal()
    }
}
