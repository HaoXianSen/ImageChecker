//
//  ViewController.swift
//  AppBigImageChecker
//
//  Created by 郝玉鸿 on 2023/7/11.
//

import Cocoa
import UniformTypeIdentifiers

class ViewController: NSViewController {

    @IBOutlet weak var projectPathTextView: NSTextField!
    
    @IBOutlet weak var checkButton: NSButton!
    
    @IBOutlet weak var outputTextView: NSTextView!
    
    @IBOutlet weak var conditionTextField: NSTextField!
    
    @IBOutlet weak var browseButton: NSButton!
    
    @IBOutlet weak var exportButton: NSButton!
    
    var projectURL: URL?
    
    var queryData: [[String: Any]]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = NSSize(width: 800, height: 600)
        self.conditionTextField.stringValue = "0"
    }
    
    @IBAction func checkAction(_ sender: NSButton) {
        queryImage()
    }
    
    @IBAction func exportAction(_ sender: Any) {
        guard let queryData = queryData else {
            return
        }
        openSavePanel(with: queryData)
    }
    
    @IBAction func browseAction(_ sender: NSButton) {
        openChooseFilePanel()
    }
}

extension ViewController: NSOpenSavePanelDelegate {
    private func openChooseFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.delegate = self
        panel.begin { modalResponse in
            if modalResponse == NSApplication.ModalResponse.OK {
                let urls = panel.urls
                self.selectedProjectPath(urls)
                print(urls)
            }
        }
    }
    
    private func selectedProjectPath(_ urls: [URL]) {
        guard urls.isEmpty == false, urls.count == 1 else {
            showErrorAlert("请选择一个工程目录，不能选择多个目录~")
            return
        }
        
        let fileUrl = urls.first
        let fileString = fileUrl?.relativePath
        
        projectPathTextView.stringValue = fileString ?? ""
    }
    
    private func openSavePanel(with data:[[String: Any]]) {
        let savePannel = NSSavePanel()
        savePannel.canCreateDirectories = true
        savePannel.title = "保存检索结果"
        savePannel.allowedContentTypes = [UTType(filenameExtension: "plist")!]
        savePannel.begin { modelResponse in
            if modelResponse == NSApplication.ModalResponse.OK {
                guard let url = savePannel.url else {
                    return
                }
                self.saveData(data, savePath: url)
            }
        }
    }
    
    private func saveData(_ data: [[String: Any]], savePath: URL) {
        do {
           let propertyList = try PropertyListSerialization.data(fromPropertyList: data, format: PropertyListSerialization.PropertyListFormat.xml, options: 0)
            try propertyList.write(to: savePath, options: .atomic)
        } catch let error {
            showErrorAlert(error.localizedDescription)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.showInfoAlert("保存成功")
        }
    }
}

extension ViewController {
    private func queryImage() {
        let directory = projectPathTextView.stringValue
        guard let minSize = Int(conditionTextField.stringValue),
                directory .isEmpty == false else {
            showErrorAlert("工程地址不对或者输入最小图片大小限制不对，请检查后再次检索")
            return
        }
        self.updateTextViewText(NSAttributedString(string: "正在检索中...\n"), textView: self.outputTextView)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            let data = self.queryImage(directory, condition: minSize)
            self.queryData = data
            self.updateTextViewText(NSAttributedString(string: "检索结果如下：\n" + self.arrayPrint(data) + "如果需要导出，请选择“导出”"), textView: self.outputTextView)
        }
    }
    
    private func updateTextViewText(_ text: NSAttributedString, textView: NSTextView) {
        guard let textStorage = textView.textStorage else {
            return
        }
        
        textStorage.beginEditing()
        textStorage.setAttributedString(text)
        textStorage.endEditing()
    }
    
    private func queryImage(_ directory: String, condition: Int) -> [[String: Any]] {
        let fileManager = FileManager.default
        guard let fileEnumerator = fileManager.enumerator(atPath: directory)  else {
            showErrorAlert("遍历目录异常")
            return []
        }
        
        var imageFiles: [String] = []
        while let file = fileEnumerator.nextObject() as? String {
            if file.hasSuffix("png") || file.hasSuffix("jpg") || file.hasSuffix("gif") {
                imageFiles.append(file)
            }
        }
        
        var imageDataArray: [[String: Any]] = []
        imageFiles.forEach { file in
            let path = directory + "/" + file
            let attributes = try? fileManager.attributesOfItem(atPath: path)
            let url = NSURL(fileURLWithPath: path)
            var dict: [String: Any] = [:]
            dict["name"] = url.lastPathComponent
            dict["url"] = url.relativePath
            if attributes != nil,
               let size = (attributes![FileAttributeKey.size] as? NSNumber)?.uint64Value,
                size >= condition * 1024 {
                let sizeString = self.convertToFileString(with: size)
                dict["size"] = sizeString
                imageDataArray.append(dict)
            }
        }
        
        return imageDataArray
    }
    
    private func convertToFileString(with size: UInt64) -> String {
        var convertedValue: Double = Double(size)
        var multiplyFactor = 0
        let tokens = ["bytes", "KB", "MB", "GB", "TB", "PB",  "EB",  "ZB", "YB"]
        while convertedValue > 1024 {
            convertedValue /= 1024
            multiplyFactor += 1
        }
        return String(format: "%4.2f %@", convertedValue, tokens[multiplyFactor])
    }
    
    private func arrayPrint(_ array: [[String: Any]]) -> String {
        var stringArray: [String] = []
        array.forEach { dict in
            let string = "\(dict["name"]!)\t\(dict["size"] ?? "0")\t\(dict["url"]!)\t\n"
            stringArray.append(string)
        }
        
        var string = "name\tsize\tpath\t\n"
        stringArray.forEach { aString in
            string += aString
        }
        return string
    }
}

extension ViewController {
    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    private func showInfoAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}


