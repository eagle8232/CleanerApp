//
//  SCHomeViewController.swift
//  Cleaner App
//
//  Created by Vusal Nuriyev 2 on 12.09.24.
//

import SwiftUI

struct SCHomeViewController: View {
    
    @ObservedObject var homeVM = SCHomeViewModel()

    var body: some View {
        
        NavigationView {
            
            ZStack {
                
                Color.backgroundPrimary.ignoresSafeArea()
                
                ScrollView(.vertical) {
                    
                    VStack(spacing: 32) {

                        phoneInfosView
                        
                        SCStorageUsageView()
                        
                        utilitiesView
                        
                        Spacer()
                    }
                }
                
                SCInfoView(isShowing: $homeVM.isPresentingInfoView)
            }
            .navigationBarItems(trailing: infoButton)
            .navigationBarTitle("Home", displayMode: .inline)
        }
    }
    
    // MARK: - Info Button for NavBar
    var infoButton: some View {
        
        Button(action: {
            withAnimation(.spring()) {
                homeVM.isPresentingInfoView.toggle()
            }
        }) {
            Image(systemName: "info.circle")
                .foregroundColor(.primary)
                .font(.title2)
        }
    }
    
    // MARK: - PhoneInfosView
    var phoneInfosView: some View {
        
        HStack(spacing: 4) {
            
            SCPhoneInfoView(
                image: .internet,
                status: homeVM.internetConnectionStatus.rawValue,
                isLoading: homeVM.internetConnectionStatus == .loading
            )
            
            SCPhoneInfoView(
                image: .battery,
                status: homeVM.batteryStateDescription(),
                isLoading: false
            )
        }
    }

    // MARK: - UtilitiesView
    var utilitiesView: some View {
        
        LazyHGrid(rows: [.init(.flexible()), .init(.flexible())]) {
            
            ForEach(SCUtility.allCases, id: \.rawValue) { utility in
                utilityView(utility)
            }
        }
    }
    
    // MARK: - UtilityView
    func utilityView(_ utility: SCUtility) -> some View {
        
        NavigationLink {
            
            switch utility {
                
            case .photos:
                SCDuplicatePhotosView()
                
            case .videos:
                EmptyView()
                
            case .contacts:
                EmptyView()
            }
            
        } label: {
            utilityContent(utility)
        }

    }
    
    func utilityContent(_ utility: SCUtility) -> some View {
        
        HStack {
            
            Image(utility.image)
                .resizable()
                .frame(.extraSmall)
                .foregroundStyle(.textPrimary)
            
            Text(utility.rawValue.capitalized)
                .font(.caption.bold())
                .foregroundStyle(.textHelper)
            
            Spacer()
        }
        .padding()
        .background(
            SCRectangle()
                .fill(.backgroundPrimary)
                .shadow(radius: .shadowRadius)
        )
    }
}
