//
//  CustomItems.swift
//  Menu Bar Splitter
//
//  Created by Justin Hamilton on 3/5/21.
//  Copyright © 2021 Justin Hamilton. All rights reserved.
//

import Foundation
import AppKit

func customIconsBaseURL() -> URL? {
    guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
    return appSupport.appendingPathComponent("Menu-Bar-Splitter", isDirectory: true)
}

func migrateFromGroupContainerIfNeeded() {
    let key = "migratedFromGroupContainer"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    defer { UserDefaults.standard.set(true, forKey: key) }

    guard let newBase = customIconsBaseURL() else { return }
    let newCustomIcons = newBase.appendingPathComponent("customIcons", isDirectory: true)

    // Skip if new location already has data
    if FileManager.default.fileExists(atPath: newCustomIcons.appendingPathComponent("data.json").path) { return }

    let groupID = "group.com.justinhamilton.Menu-Bar-Splitter.sharedData"
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return }
    let oldCustomIcons = containerURL
        .appendingPathComponent("Library/Application Support/Menu-Bar-Splitter/customIcons", isDirectory: true)

    guard FileManager.default.fileExists(atPath: oldCustomIcons.path) else { return }

    do {
        try FileManager.default.createDirectory(at: newBase, withIntermediateDirectories: true, attributes: nil)
        // Copy the entire customIcons directory tree
        if !FileManager.default.fileExists(atPath: newCustomIcons.path) {
            try FileManager.default.copyItem(at: oldCustomIcons, to: newCustomIcons)
        }

        // Update stored URLs in data.json to point to the new location
        let dataURL = newCustomIcons.appendingPathComponent("data.json", isDirectory: false)
        if let data = FileManager.default.contents(atPath: dataURL.path),
           var json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            let oldPrefix = oldCustomIcons.path
            let newPrefix = newCustomIcons.path
            for (id, value) in json {
                if var entry = value as? [String: Any], let url = entry["url"] as? String, url.hasPrefix(oldPrefix) {
                    entry["url"] = url.replacingOccurrences(of: oldPrefix, with: newPrefix)
                    json[id] = entry
                }
            }
            let updated = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            try updated.write(to: dataURL)
        }
        print("Migration from group container succeeded")
    } catch {
        print("Migration from group container failed: \(error.localizedDescription)")
    }
}

class CustomIcon: NSObject {
    var nickname: String!
    var url: URL!
    var image: NSImage!
    var id: String!
    
    init(nickname: String, url: URL, image: NSImage, id: String) {
        self.nickname = nickname
        self.url = url
        self.image = image
        self.id = id
    }
}

func getCustomItem(for uuid: String) -> NSImage? {
    if let items = getCustomItems() {
        return items[uuid]
    }
    return nil
}

func getCustomItems() -> [String:NSImage]? {
    var images: [String:NSImage] = [:]
    if let supportURL = customIconsBaseURL() {
        let customIconsURL = (supportURL.appendingPathComponent("customIcons/images", isDirectory: true))
        do {
            if(FileManager.default.fileExists(atPath: customIconsURL.path)) {
                let contents = try FileManager.default.contentsOfDirectory(atPath: customIconsURL.path)
                for file in contents {
                    let url = (customIconsURL.appendingPathComponent(file, isDirectory: false))
                    if let data = FileManager.default.contents(atPath: url.path), let image = NSImage(data: data) {
                        var height: CGFloat = 20
                        
                        if let mb = NSApplication.shared.mainMenu {
                            height = mb.menuBarHeight
                        }
                        
                        image.size.width = (height/image.size.height)*image.size.width
                        image.size.height = height
                        
                        let idImage = url.lastPathComponent
                        let id = idImage.split(separator: ".")[0]
                        images[String(id)] = image
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    return (images == [:]) ? nil : images
}

func getNickname(for id: String) -> String? {
    if let nicknames = getNicknames(), let nickname = nicknames[id] {
        return nickname
    }
    return nil
}

func getNicknames() -> [String: String]? {
    var nicknames: [String: String] = [:]
    if let supportURL = customIconsBaseURL() {
        let customIconsURL = (supportURL.appendingPathComponent("customIcons", isDirectory: true))
        do {
            let customIconsDataURL = customIconsURL.appendingPathComponent("data.json", isDirectory: false)
            if(FileManager.default.fileExists(atPath: customIconsDataURL.path)) {
                if let contents = FileManager.default.contents(atPath: customIconsDataURL.path), let newJSONObject = try JSONSerialization.jsonObject(with: contents, options: []) as? [String: Any] {
                    for obj in newJSONObject {
                        if let o = obj.value as? [String: Any], let nickname = o["nickname"] as? String {
                            nicknames[obj.key] = nickname
                        }
                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return nicknames
    }
    return (nicknames == [:]) ? nil : nicknames
}

func renameItem(id: String, _ newName: String) {
    if let supportURL = customIconsBaseURL() {
        let customIconsURL = (supportURL.appendingPathComponent("customIcons", isDirectory: true))
        do {
            let customIconsDataURL = customIconsURL.appendingPathComponent("data.json", isDirectory: false)
            if let contents = FileManager.default.contents(atPath: customIconsDataURL.path), var newJSONObject = try JSONSerialization.jsonObject(with: contents, options: []) as? [String: Any] {
                if var obj = newJSONObject[id] as? [String: Any] {
                    obj["nickname"] = newName;
                    newJSONObject[id] = obj
                    guard let s = String(data: try JSONSerialization.data(withJSONObject: newJSONObject, options: [.prettyPrinted]), encoding: .utf8) else {return}
                    try s.write(to: customIconsDataURL, atomically: true, encoding: .utf8)
                }
                
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

func deleteItem(id: String) {
    if let supportURL = customIconsBaseURL() {
        let customIconsURL = (supportURL.appendingPathComponent("customIcons", isDirectory: true))
        do {
            let customIconsDataURL = customIconsURL.appendingPathComponent("data.json", isDirectory: false)
            if let contents = FileManager.default.contents(atPath: customIconsDataURL.path), var newJSONObject = try JSONSerialization.jsonObject(with: contents, options: []) as? [String: Any] {
                if let obj = newJSONObject[id] as? [String: Any], let urlToRemove = obj["url"] as? String {
                    try FileManager.default.removeItem(atPath: urlToRemove)
                    newJSONObject[id] = nil
                    guard let s = String(data: try JSONSerialization.data(withJSONObject: newJSONObject, options: [.prettyPrinted]), encoding: .utf8) else {return}
                    try s.write(to: customIconsDataURL, atomically: true, encoding: .utf8)
                }

            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

func selectCustomItem() -> String? {
    let dialog = NSOpenPanel()
    dialog.prompt = "Choose Icon"
    dialog.showsResizeIndicator = true
    dialog.showsHiddenFiles = false
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = false
    dialog.allowedFileTypes = ["public.image"]
    dialog.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
    
    if(dialog.runModal() == NSApplication.ModalResponse.OK) {
        if let result = dialog.url {
            if let supportURL = customIconsBaseURL() {
                let customIconsURL = (supportURL.appendingPathComponent("customIcons", isDirectory: true))
                do {
                    if(!FileManager.default.fileExists(atPath:customIconsURL.path)) {
                        try FileManager.default.createDirectory(at: customIconsURL, withIntermediateDirectories: true, attributes: nil)
                    }
                    let customIconsDataURL = customIconsURL.appendingPathComponent("data.json", isDirectory: false)
                    let customIconsImageURL = customIconsURL.appendingPathComponent("images", isDirectory: true)
                    if(!FileManager.default.fileExists(atPath:customIconsImageURL.path)) {
                        try FileManager.default.createDirectory(at: customIconsImageURL, withIntermediateDirectories: true, attributes: nil)
                    }
                    
                    print(1)
                    
                    if let data = FileManager.default.contents(atPath: customIconsDataURL.path), var newJSONObject: [String: Any] = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print(2)
                        
                        if let items = getCustomItems() {
                            print(3)
                            let c = items.count
                            let ext = result.pathExtension
                            let uuid = UUID().uuidString
                            let newFileURL = customIconsImageURL.appendingPathComponent("\(uuid).\(ext)", isDirectory: false)
                            try FileManager.default.copyItem(at: result, to: newFileURL)
                            let newIcon: [String: Any] = [
                                "url":newFileURL.path,
                                "nickname":"Icon \(c+1)"
                            ]
                            newJSONObject[uuid] = newIcon
                            guard let s = String(data: try JSONSerialization.data(withJSONObject: newJSONObject, options: [.prettyPrinted]), encoding: .utf8) else {
                                return nil
                            }
                            try s.write(to: customIconsDataURL, atomically: true, encoding: .utf8)
                            return uuid
                        } else {
                            let ext = result.pathExtension
                            let uuid = UUID().uuidString
                            let newFileURL = customIconsImageURL.appendingPathComponent("\(uuid).\(ext)", isDirectory: false)
                            try FileManager.default.copyItem(at: result, to: newFileURL)
                            
                            let newIcon: [String: Any] = [
                                "url":newFileURL.path,
                                "nickname":"Icon \(1)"
                            ]
                            newJSONObject[uuid] = newIcon
                            
                            guard let s = String(data: try JSONSerialization.data(withJSONObject: newJSONObject, options: [.prettyPrinted]), encoding: .utf8) else {
                                return nil
                            }
                            
                            try s.write(to: customIconsDataURL, atomically: true, encoding: .utf8)
                            return uuid
                        }
                    } else {
                        var newJSONObject: [String: Any] = [:]
                        
                        let ext = result.pathExtension
                        let uuid = UUID().uuidString
                        let newFileURL = customIconsImageURL.appendingPathComponent("\(uuid).\(ext)", isDirectory: false)
                        try FileManager.default.copyItem(at: result, to: newFileURL)
                        
                        let newIcon: [String: Any] = [
                            "url":newFileURL.path,
                            "nickname":"Icon \(1)"
                        ]
                        newJSONObject[uuid] = newIcon
                        
                        guard let s = String(data: try JSONSerialization.data(withJSONObject: newJSONObject, options: [.prettyPrinted]), encoding: .utf8) else {
                            return nil
                        }
                        
                        try s.write(to: customIconsDataURL, atomically: true, encoding: .utf8)
                        return uuid
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    return nil
}
