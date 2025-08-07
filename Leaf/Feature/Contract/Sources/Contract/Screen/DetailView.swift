//
//  File.swift
//  Contract
//
//  Created by Kihyun on 8/8/25.
//

import SharedInfrastructure
import SharedFoundation
import Foundation
import SwiftUI

struct DetailView: View {
    
    let contractId: String
    
    var body: some View {
        Text("Contract ID: \(contractId)")
            .font(.title)
            .padding()
    }
}
