// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SharedFoundation

public struct Contract: View {
    
    let route: ContractRoute
    
    public init(route: ContractRoute) {
        self.route = route
    }
    
    public var body: some View {
        switch route {
        case .list: ListView()
        case .detail(let contractId): DetailView(contractId: contractId)
        }
    }
}
