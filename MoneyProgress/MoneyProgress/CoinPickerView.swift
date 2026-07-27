//
//  CoinPickerView.swift
//  薪辛
//
//  Created by Lakr Aream on 2022/3/22.
//
//  重构：按 Entity（国家/地区）分组 + 多字段搜索（code / name / entity / numeric）
//

import SwiftUI

struct CoinTypePicker: View {
    @Environment(\.presentationMode) var presentationMode

    let onLoad: () -> (String)
    let onComplete: (String) -> Void

    var gridItem = [GridItem(.adaptive(minimum: 50, maximum: 80))]

    @State var unit: String = ""
    @State var search: String = ""

    private var filtered: [CurrencyModel] {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return currencyModels }
        return currencyModels.filter { m in
            m.AlphabeticCode.lowercased().contains(q)
                || m.Currency.lowercased().contains(q)
                || m.Entity.lowercased().contains(q)
                || String(m.NumericCode).contains(q)
        }
    }

    private var groupedByEntity: [(String, [CurrencyModel])] {
        let dict = Dictionary(grouping: filtered) { $0.Entity }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Select Currency Type")
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }
            Divider()
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("search (code/name/country/number)".localized, text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if search.isEmpty {
                        // 未搜索：按 Entity 分组
                        ForEach(groupedByEntity, id: \.0) { entity, models in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entity)
                                    .font(.system(.subheadline, design: .rounded))
                                    .bold()
                                    .foregroundColor(.secondary)
                                LazyVGrid(columns: gridItem, alignment: .center, spacing: 6) {
                                    ForEach(models, id: \.id) { item in
                                        coinButton(item)
                                    }
                                }
                            }
                        }
                    } else {
                        // 搜索结果：扁平展示
                        LazyVGrid(columns: gridItem, alignment: .center, spacing: 6) {
                            ForEach(filtered, id: \.id) { item in
                                coinButton(item)
                            }
                        }
                        if filtered.isEmpty {
                            Text("未找到匹配项".localized)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
            }
            Divider()
            HStack {
                Text("\(filtered.count) / \(currencyModels.count)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Cancel".localized)
                }
            }
        }
        .padding()
        .frame(width: 640, height: 480, alignment: .center)
    }

    @ViewBuilder
    private func coinButton(_ item: CurrencyModel) -> some View {
        VStack(spacing: 1) {
            Text(item.AlphabeticCode)
                .underline()
                .font(.system(.subheadline, design: .rounded))
                .bold()
            Text(item.Currency)
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(4)
        .onTapGesture {
            onComplete(item.AlphabeticCode)
            presentationMode.wrappedValue.dismiss()
        }
        .onHover { h in
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
