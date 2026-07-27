//
//  HistoryExporter.swift
//  MoneyProgress
//
//  历史记录导出工具（Feature 10）
//  支持 CSV 格式导出到桌面
//

import AppKit
import Foundation

final class HistoryExporter {
    static let shared = HistoryExporter()
    private init() {}

    /// 导出历史到桌面（CSV）
    func exportToDesktop(menubar: Menubar) {
        guard let records = menubar.snapshotHistory() else {
            showAlert("无可导出的数据".localized, message: "运行一段时间后再试".localized)
            return
        }
        let csv = makeCSV(records: records)
        let url = desktopURL().appendingPathComponent("MoneyProgress-history-\(todayStamp()).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            AppLog.info("Exported \(records.count) records to \(url.path)")
        } catch {
            showAlert("导出失败".localized, message: error.localizedDescription)
        }
    }

    /// 导出历史到 JSON
    func exportJSON(menubar: Menubar) -> URL? {
        guard let records = menubar.snapshotHistory() else { return nil }
        let url = desktopURL().appendingPathComponent("MoneyProgress-history-\(todayStamp()).json")
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(records) {
            try? data.write(to: url)
            return url
        }
        return nil
    }

    /// 静态便捷方法：从 SettingsView 调用
    static func exportCSV() {
        shared.exportFromUserDefaults(format: .csv)
    }

    static func exportJSON() {
        shared.exportFromUserDefaults(format: .json)
    }

    enum ExportFormat { case csv, json }

    /// 直接从 UserDefaults 导出（不依赖 Menubar）
    private func exportFromUserDefaults(format: ExportFormat) {
        let key = "wiki.qaq.history.v1"
        guard let raw = UserDefaults.standard.string(forKey: key),
              let data = raw.data(using: .utf8),
              let records = try? JSONDecoder().decode([DailyEarningRecord].self, from: data),
              !records.isEmpty else {
            showAlert("无可导出的数据".localized, message: "运行一段时间后再试".localized)
            return
        }
        let url: URL
        switch format {
        case .csv:
            url = desktopURL().appendingPathComponent("MoneyProgress-history-\(todayStamp()).csv")
            let csv = makeCSV(records: records)
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        case .json:
            url = desktopURL().appendingPathComponent("MoneyProgress-history-\(todayStamp()).json")
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let d = try? enc.encode(records) {
                try? d.write(to: url)
            }
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        AppLog.info("Exported \(records.count) records to \(url.path)")
    }

    private func makeCSV(records: [DailyEarningRecord]) -> String {
        var lines = ["日期,已赚金额,今日应赚,净工时(秒),加班(秒),是否休息日"]
        for r in records {
            let row = [
                r.dateKey,
                String(format: "%.2f", r.earned),
                String(format: "%.2f", r.dayEarnings),
                String(r.netWorkSeconds),
                String(r.overtimeSeconds),
                r.isRestDay ? "是" : "否",
            ].joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }

    private func todayStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    private func desktopURL() -> URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    private func showAlert(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
