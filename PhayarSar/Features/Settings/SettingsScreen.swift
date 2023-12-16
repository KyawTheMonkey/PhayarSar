//
//  SettingsScreen.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 16/12/2023.
//

import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var preferences: UserPreferences

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(.logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("PhayarSar")
                            .font(.dmSerif(20))
                        
                        Text("V1.0.0")
                            .font(.qsB(14))
                            .foregroundColor(.appGreen)
                    }
                }
            }
            
            Section {
                ChooseLang()
                AppAccentColor()
            }
        }
        .navigationTitle(.settings)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func ChooseLang() -> some View {
        NavigationLink {
            ChooseLanguageScreen(isStandalone: true)
        } label: {
            HStack {
                LocalizedText(.app_language)
                    .font(.qsSb(16))
                Spacer()
                Text(preferences.appLang.title)
                    .font(.qsB(16))
                    .foregroundColor(.appGreen)
                
            }
        }
    }
    
    @ViewBuilder
    private func AppAccentColor() -> some View {
        HStack {
            LocalizedText(.app_accent_color)
                .font(.qsSb(16))
            Spacer()
            Circle()
                .fill(Color.appGreen)
                .frame(width: 28)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 20)
                }
            
        }
    }
}

#Preview {
    NavigationView {
        SettingsScreen()
    }
    .environmentObject(UserPreferences())
}
