//
//  ManageCustomViewController.swift
//  Menu Bar Splitter
//
//  Created by Justin Hamilton on 3/19/21.
//  Copyright © 2021 Justin Hamilton. All rights reserved.
//

import Cocoa
import CoreGraphics

class ManageCustomViewController: NSViewController {

    var appDelegate: AppDelegate!
    var icons: [CustomIcon] = []
    var window: NSWindow!
    @IBOutlet weak var collectionView: NSCollectionView!

    // Bottom controls
    var bottomStack: NSStackView!
    var paddingRow: NSStackView!
    var thicknessRow: NSStackView!
    var heightRow: NSStackView!
    var bottomRow: NSStackView!   // color + Add Icon combined

    var paddingLabel: NSTextField!
    var paddingSlider: NSSlider!
    var thicknessLabel: NSTextField!
    var thicknessSlider: NSSlider!
    var heightLabel: NSTextField!
    var heightSlider: NSSlider!
    var colorLabel: NSTextField!
    var colorWell: NSColorWell!
    var resetColorButton: NSButton!

    var colorDebounceWork: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.refreshIcons()
        self.configureCollectionView()
        self.setupBottomControls()
    }

    func setupBottomControls() {
        // Hide the storyboard Add Icon button — we create our own below
        if let storyboardBtn = view.subviews.compactMap({ $0 as? NSButton }).first {
            storyboardBtn.isHidden = true
        }

        let labelWidth: CGFloat = 72
        let margin: CGFloat = 20

        func makeLabel(_ text: String) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.font = NSFont.systemFont(ofSize: 12)
            l.translatesAutoresizingMaskIntoConstraints = false
            l.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
            return l
        }

        // --- Padding row ---
        paddingLabel = makeLabel("Padding")
        paddingSlider = NSSlider(value: 0, minValue: 0, maxValue: 50, target: self, action: #selector(paddingChanged(_:)))
        paddingSlider.isContinuous = true
        paddingRow = NSStackView(views: [paddingLabel, paddingSlider])
        paddingRow.orientation = .horizontal
        paddingRow.spacing = 8

        // --- Thickness row ---
        thicknessLabel = makeLabel("Thickness")
        thicknessSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 10, target: self, action: #selector(thicknessChanged(_:)))
        thicknessSlider.isContinuous = true
        thicknessRow = NSStackView(views: [thicknessLabel, thicknessSlider])
        thicknessRow.orientation = .horizontal
        thicknessRow.spacing = 8

        // --- Height row (line only) ---
        heightLabel = makeLabel("Height")
        heightSlider = NSSlider(value: 16, minValue: 4, maxValue: 24, target: self, action: #selector(heightChanged(_:)))
        heightSlider.isContinuous = true
        heightRow = NSStackView(views: [heightLabel, heightSlider])
        heightRow.orientation = .horizontal
        heightRow.spacing = 8

        // --- Bottom row: color controls + spacer + Add Icon (always visible) ---
        colorLabel = makeLabel("Color")
        colorWell = NSColorWell()
        colorWell.color = .labelColor
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

        resetColorButton = NSButton(title: "Reset", target: self, action: #selector(resetColor(_:)))
        resetColorButton.bezelStyle = .rounded
        resetColorButton.font = NSFont.systemFont(ofSize: 11)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let addButton = NSButton(title: "Add Icon", target: self, action: #selector(addIcon(_:)))
        addButton.bezelStyle = .rounded

        bottomRow = NSStackView(views: [colorLabel, colorWell, resetColorButton, spacer, addButton])
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 8

        // --- Main vertical stack ---
        bottomStack = NSStackView(views: [paddingRow, thicknessRow, heightRow, bottomRow])
        bottomStack.orientation = .vertical
        bottomStack.alignment = .width
        bottomStack.spacing = 10
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomStack)

        // Initially hide control rows (bottom row with Add Icon always visible)
        paddingRow.isHidden = true
        thicknessRow.isHidden = true
        heightRow.isHidden = true
        colorLabel.isHidden = true
        colorWell.isHidden = true
        resetColorButton.isHidden = true

        NSLayoutConstraint.activate([
            bottomStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            bottomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            bottomStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),
        ])

        // Constrain the scroll view to end above the controls with padding
        if let scrollView = collectionView.enclosingScrollView {
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -12),
            ])
        }
    }

    @objc func paddingChanged(_ sender: NSSlider) {
        let value = sender.integerValue
        guard let selectedIndex = collectionView.selectionIndexPaths.first?.item else { return }
        let iconData = icons[selectedIndex]

        if iconData.id == "__builtin_line__" {
            UserDefaults.standard.set(value, forKey: "linePadding")
        } else if iconData.id == "__builtin_dot__" {
            UserDefaults.standard.set(value, forKey: "dotPadding")
        } else {
            setPaddingForCustomIcon(id: iconData.id, value)
        }
        iconData.padding = value

        appDelegate.reapplyAllIcons()
    }

    @objc func thicknessChanged(_ sender: NSSlider) {
        guard let selectedIndex = collectionView.selectionIndexPaths.first?.item else { return }
        let iconData = icons[selectedIndex]
        let value = sender.doubleValue

        if iconData.id == "__builtin_line__" {
            UserDefaults.standard.set(value, forKey: "lineThickness")
        } else if iconData.id == "__builtin_dot__" {
            UserDefaults.standard.set(value, forKey: "dotThickness")
        }

        appDelegate.reapplyAllIcons()
        refreshIconPreview(at: selectedIndex)
    }

    @objc func heightChanged(_ sender: NSSlider) {
        guard let selectedIndex = collectionView.selectionIndexPaths.first?.item else { return }
        let value = sender.doubleValue
        UserDefaults.standard.set(value, forKey: "lineHeight")
        appDelegate.reapplyAllIcons()
        refreshIconPreview(at: selectedIndex)
    }

    @objc func colorChanged(_ sender: NSColorWell) {
        colorDebounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard let selectedIndex = self.collectionView.selectionIndexPaths.first?.item else { return }
            let iconData = self.icons[selectedIndex]
            let color = sender.color

            if iconData.id == "__builtin_line__" {
                UserDefaults.standard.setColor(color, forKey: "lineColor")
            } else if iconData.id == "__builtin_dot__" {
                UserDefaults.standard.setColor(color, forKey: "dotColor")
            }

            self.appDelegate.reapplyAllIcons()
            self.refreshIconPreview(at: selectedIndex)
        }
        colorDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    @objc func resetColor(_ sender: Any) {
        guard let selectedIndex = collectionView.selectionIndexPaths.first?.item else { return }
        let iconData = icons[selectedIndex]

        if iconData.id == "__builtin_line__" {
            UserDefaults.standard.setColor(nil, forKey: "lineColor")
        } else if iconData.id == "__builtin_dot__" {
            UserDefaults.standard.setColor(nil, forKey: "dotColor")
        }

        colorWell.color = .labelColor
        appDelegate.reapplyAllIcons()
        refreshIconPreview(at: selectedIndex)
    }

    func refreshIconPreview(at index: Int) {
        let iconData = icons[index]
        if iconData.id == "__builtin_line__" {
            let rawThickness = UserDefaults.standard.double(forKey: "lineThickness")
            let thickness = CGFloat(rawThickness > 0 ? rawThickness : 1.0)
            let rawLineHeight = UserDefaults.standard.double(forKey: "lineHeight")
            let lineHeight: CGFloat? = rawLineHeight > 0 ? CGFloat(rawLineHeight) : nil
            let color = UserDefaults.standard.color(forKey: "lineColor")
            iconData.image = BuiltinIconRenderer.lineIcon(thickness: thickness, lineHeight: lineHeight, color: color, height: 22)
        } else if iconData.id == "__builtin_dot__" {
            let rawDiameter = UserDefaults.standard.double(forKey: "dotThickness")
            let diameter = CGFloat(rawDiameter > 0 ? rawDiameter : 4.0)
            let color = UserDefaults.standard.color(forKey: "dotColor")
            iconData.image = BuiltinIconRenderer.dotIcon(diameter: diameter, color: color, height: 22)
        }
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        // Re-select to keep highlight
        collectionView.selectionIndexPaths = [IndexPath(item: index, section: 0)]
    }

    func updateControlVisibility(for iconData: CustomIcon?) {
        guard let iconData = iconData else {
            paddingRow.isHidden = true
            thicknessRow.isHidden = true
            heightRow.isHidden = true
            colorLabel.isHidden = true
            colorWell.isHidden = true
            resetColorButton.isHidden = true
            return
        }

        let isLine = iconData.id == "__builtin_line__"
        let isDot = iconData.id == "__builtin_dot__"
        let isBuiltIn = isLine || isDot

        paddingRow.isHidden = false
        thicknessRow.isHidden = !isBuiltIn
        heightRow.isHidden = !isLine
        colorLabel.isHidden = !isBuiltIn
        colorWell.isHidden = !isBuiltIn
        resetColorButton.isHidden = !isBuiltIn

        if isLine {
            thicknessSlider.minValue = 0.5
            thicknessSlider.maxValue = 10
            let rawVal = UserDefaults.standard.double(forKey: "lineThickness")
            thicknessSlider.doubleValue = rawVal > 0 ? rawVal : 1.0
            let rawHeight = UserDefaults.standard.double(forKey: "lineHeight")
            heightSlider.doubleValue = rawHeight > 0 ? rawHeight : 16.0
            colorWell.color = UserDefaults.standard.color(forKey: "lineColor") ?? .labelColor
        } else if isDot {
            thicknessSlider.minValue = 1
            thicknessSlider.maxValue = 20
            let rawVal = UserDefaults.standard.double(forKey: "dotThickness")
            thicknessSlider.doubleValue = rawVal > 0 ? rawVal : 4.0
            colorWell.color = UserDefaults.standard.color(forKey: "dotColor") ?? .labelColor
        }

        NSColorPanel.shared.showsAlpha = true
    }

    func refreshIcons() {
        self.icons = []

        // Add built-in icons first (rendered programmatically)
        let rawLineThickness = UserDefaults.standard.double(forKey: "lineThickness")
        let lineThickness = CGFloat(rawLineThickness > 0 ? rawLineThickness : 1.0)
        let rawLineHeight = UserDefaults.standard.double(forKey: "lineHeight")
        let lineHeight: CGFloat? = rawLineHeight > 0 ? CGFloat(rawLineHeight) : nil
        let lineColor = UserDefaults.standard.color(forKey: "lineColor")
        let lineImage = BuiltinIconRenderer.lineIcon(thickness: lineThickness, lineHeight: lineHeight, color: lineColor, height: 22)
        let lineIcon = CustomIcon(nickname: "Line", url: URL(fileURLWithPath: ""), image: lineImage, id: "__builtin_line__", padding: UserDefaults.standard.integer(forKey: "linePadding"))
        self.icons.append(lineIcon)

        let rawDotDiameter = UserDefaults.standard.double(forKey: "dotThickness")
        let dotDiameter = CGFloat(rawDotDiameter > 0 ? rawDotDiameter : 4.0)
        let dotColor = UserDefaults.standard.color(forKey: "dotColor")
        let dotImage = BuiltinIconRenderer.dotIcon(diameter: dotDiameter, color: dotColor, height: 22)
        let dotIcon = CustomIcon(nickname: "Dot", url: URL(fileURLWithPath: ""), image: dotImage, id: "__builtin_dot__", padding: UserDefaults.standard.integer(forKey: "dotPadding"))
        self.icons.append(dotIcon)

        // Add custom icons
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sharedGroupIdentifier) {
            let supportURL = containerURL.appendingPathComponent("Library/Application Support/Menu-Bar-Splitter", isDirectory: true)
            let customIconsURL = (supportURL.appendingPathComponent("customIcons", isDirectory: true))
            let customIconsDataURL = customIconsURL.appendingPathComponent("data.json", isDirectory: false)

            do {
                if let data = FileManager.default.contents(atPath: customIconsDataURL.path), let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    for item in object {
                        if let v = item.value as? [String: Any], let nickname = v["nickname"] as? String, let urlStr = v["url"] as? String {
                            let url = NSURL.fileURL(withPath: urlStr)
                            if let imageData = FileManager.default.contents(atPath: urlStr), let image = NSImage(data: imageData) {
                                let padding = (v["padding"] as? Int) ?? 0
                                self.icons.append(CustomIcon(nickname: nickname, url: url, image: image, id: item.key, padding: padding))
                            }
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        // Sort custom icons by name, but keep built-in icons at the top
        let builtInIcons = self.icons.filter { $0.id.hasPrefix("__builtin_") }
        var customIcons = self.icons.filter { !$0.id.hasPrefix("__builtin_") }
        customIcons.sort(by: { $0.nickname < $1.nickname })
        self.icons = builtInIcons + customIcons
    }

    @IBAction func addIcon(_ sender: Any) {
        if let _ = self.appDelegate.addCustomImage() {
            self.refreshIcons()
            self.collectionView.reloadData()
        }
    }
}

extension NSImage {
    var smallBitmap: NSBitmapImageRep? {
        guard let data = self.tiffRepresentation, let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        guard let resized = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
            kCGImageSourceThumbnailMaxPixelSize: 16 as NSObject,
            kCGImageSourceCreateThumbnailFromImageAlways: true as NSObject
        ] as CFDictionary) else { return nil }

        let bitmap = NSBitmapImageRep(cgImage: resized)
        return bitmap

    }

    var hasAlphaChannel: Bool {
        guard let b = self.smallBitmap else { return false }

        for i in 0..<Int(b.size.width) {
            for j in 0..<Int(b.size.height) {
                if(b.colorAt(x: i, y: j)?.alphaComponent != 1.0) {
                    return true
                }
            }
        }

        return false
    }

    var colorDataEqual: Bool {
        guard let b = self.smallBitmap else { return false }

        for i in 0..<Int(b.size.height) {
            for j in 1..<Int(b.size.width) {
                if let b1 = b.colorAt(x: j, y: i), let b2 = b.colorAt(x: j-1, y: i) {
                    if(b1.greenComponent != 0 && b1.blueComponent != 0 && b2.greenComponent != 0 && b2.blueComponent != 0) {
                        let r1 = ((b1.redComponent/b1.greenComponent)+(b1.greenComponent/b1.blueComponent))/2
                        let r2 = ((b2.redComponent/b2.greenComponent)+(b2.greenComponent/b2.blueComponent))/2
                        if(r1 != r2) {
                            return false
                        }
                    }
                }
            }
        }

        return true
    }

    var smallImage: NSImage? {
        guard let b = self.smallBitmap, let image = b.cgImage else { return nil }
        return NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
    }

    var brightness: CGFloat? {
        guard let data = self.tiffRepresentation, let input = CIImage(data: data) else { return nil }
        let extent = CIVector(x: input.extent.origin.x, y: input.extent.origin.y, z: input.extent.size.width, w: input.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: input, kCIInputExtentKey: extent]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var b = [UInt8](repeating: 0, count: 4)
        let c = CIContext(options: [.workingColorSpace: kCFNull as Any])
        c.render(outputImage, toBitmap: &b, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return (CGFloat(b[0])+CGFloat(b[1])+CGFloat(b[2]))/765
    }
}

extension ManageCustomViewController: NSCollectionViewDelegate, NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.icons.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        guard let item = self.collectionView.makeItem(withIdentifier: .init("customIconCollectionViewItem"), for: indexPath) as? ManageCustomCollectionItem else {return NSCollectionViewItem()}
        let iconData = self.icons[indexPath.item]
        item.parentVC = self
        item.iconImageView.image = iconData.image
        item.iconID = iconData.id

        let isBuiltIn = iconData.id.hasPrefix("__builtin_")
        item.isBuiltIn = isBuiltIn

        if isBuiltIn {
            item.iconImageView.image?.isTemplate = true
            item.iconImageView.contentTintColor = NSColor.labelColor
            item.buttonStack.isHidden = false
            for case let button as NSButton in item.buttonStack.arrangedSubviews {
                button.isEnabled = false
            }
        } else {
            if(item.iconImageView.image!.hasAlphaChannel && item.iconImageView.image!.colorDataEqual) {
                item.iconImageView.image!.isTemplate = true
                item.iconImageView.contentTintColor = NSColor.labelColor
            } else {
                item.iconImageView.image!.isTemplate = false
                item.iconImageView.contentTintColor = NSColor.clear
            }
            item.iconImageView.contentTintColor = .none
            item.buttonStack.isHidden = false
        }

        item.titleLabel.stringValue = iconData.nickname
        item.titleLabel.textColor = .labelColor

        item.icon = iconData
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let index = indexPaths.first?.item else { return }
        let iconData = icons[index]
        paddingSlider.integerValue = iconData.padding
        updateControlVisibility(for: iconData)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        if collectionView.selectionIndexPaths.isEmpty {
            updateControlVisibility(for: nil)
        }
    }

    func configureCollectionView() {
        self.collectionView.delegate = self
        self.collectionView.dataSource = self

        self.collectionView.isSelectable = true
        self.collectionView.allowsEmptySelection = true

        self.collectionView.enclosingScrollView?.borderType = .bezelBorder

        let n = NSNib(nibNamed: "ManageCustomCollectionItem", bundle: nil)
        self.collectionView.register(n, forItemWithIdentifier: .init("customIconCollectionViewItem"))

        self.configureFlowLayout()
    }

    func configureFlowLayout() {
        let layout = NSCollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 30.0
        layout.minimumLineSpacing = 30.0
        layout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.itemSize = NSSize(width: 100, height: 150)
        self.collectionView.collectionViewLayout = layout
    }
}
