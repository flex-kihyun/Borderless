#!/usr/bin/env swift

import Foundation

// MARK: - Models

struct PackageInfo {
    let path: String
    let name: String
    let dependencies: [String]
    let targets: [TargetInfo]
}

struct TargetInfo {
    let name: String
    let dependencies: [String]
}

// MARK: - Package Parser

class PackageParser {
    static func parsePackage(at path: String) -> PackageInfo? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        
        let lines = content.components(separatedBy: .newlines)
        var name = ""
        var dependencies: [String] = []
        var targets: [TargetInfo] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Extract package name
            if trimmed.hasPrefix("name:") {
                name = trimmed.replacingOccurrences(of: "name:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\"", with: "")
            }
            
            // Extract dependencies
            if trimmed.contains(".package(path:") {
                let dependency = extractPackagePath(from: trimmed)
                if !dependency.isEmpty {
                    dependencies.append(dependency)
                }
            }
            
            // Extract targets
            if trimmed.contains(".target(") {
                let target = extractTarget(from: lines, startingAt: lines.firstIndex(of: line) ?? 0)
                if let target = target {
                    targets.append(target)
                }
            }
        }
        
        return PackageInfo(path: path, name: name, dependencies: dependencies, targets: targets)
    }
    
    private static func extractPackagePath(from line: String) -> String {
        let pattern = #"\.package\(path:\s*"([^"]+)"\)"#
        if let range = line.range(of: pattern, options: .regularExpression) {
            let match = String(line[range])
            if let pathRange = match.range(of: #""([^"]+)""#, options: .regularExpression) {
                let pathMatch = String(match[pathRange])
                return String(pathMatch.dropFirst().dropLast())
            }
        }
        return ""
    }
    
    private static func extractTarget(from lines: [String], startingAt index: Int) -> TargetInfo? {
        var targetName = ""
        var targetDependencies: [String] = []
        
        for i in index..<min(index + 10, lines.count) {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            if line.contains("name:") && line.contains("\"") {
                let pattern = #"name:\s*"([^"]+)""#
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let match = String(line[range])
                    if let nameRange = match.range(of: #""([^"]+)""#, options: .regularExpression) {
                        let nameMatch = String(match[nameRange])
                        targetName = String(nameMatch.dropFirst().dropLast())
                    }
                }
            }
            
            if line.contains("dependencies:") {
                // Look for dependencies in the next few lines
                for j in (i+1)..<min(i+5, lines.count) {
                    let depLine = lines[j].trimmingCharacters(in: .whitespaces)
                    if depLine.contains("]") { break }
                    if depLine.contains("\"") {
                        let pattern = #""([^"]+)""#
                        if let range = depLine.range(of: pattern, options: .regularExpression) {
                            let match = String(depLine[range])
                            let dependency = String(match.dropFirst().dropLast())
                            targetDependencies.append(dependency)
                        }
                    }
                }
            }
            
            if line.contains(")") && targetName.isEmpty == false {
                break
            }
        }
        
        return targetName.isEmpty ? nil : TargetInfo(name: targetName, dependencies: targetDependencies)
    }
}

// MARK: - Package Writer

class PackageWriter {
    static func updatePackage(_ package: PackageInfo, with newDependencies: [String]) -> String {
        guard let content = try? String(contentsOfFile: package.path, encoding: .utf8) else { return "" }
        
        var lines = content.components(separatedBy: .newlines)
        var inDependencies = false
        var dependencyStartIndex = -1
        var dependencyEndIndex = -1
        
        // Find dependencies section
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "dependencies: [" {
                inDependencies = true
                dependencyStartIndex = index
            } else if inDependencies && trimmed == "]," {
                dependencyEndIndex = index
                break
            }
        }
        
        // Generate new dependencies
        let newDependencyLines = newDependencies.map { dependency in
            "        .package(path: \"\(dependency)\")"
        }
        
        // Replace dependencies section
        if dependencyStartIndex >= 0 && dependencyEndIndex >= 0 {
            lines.removeSubrange(dependencyStartIndex...dependencyEndIndex)
            lines.insert("    dependencies: [", at: dependencyStartIndex)
            lines.insert(contentsOf: newDependencyLines, at: dependencyStartIndex + 1)
            lines.insert("    ],", at: dependencyStartIndex + 1 + newDependencyLines.count)
        } else {
            // Insert dependencies section after products
            var insertIndex = -1
            for (index, line) in lines.enumerated() {
                if line.trimmingCharacters(in: .whitespaces) == "]," && 
                   index > 0 && lines[index - 1].contains("products") {
                    insertIndex = index + 1
                    break
                }
            }
            
            if insertIndex >= 0 {
                lines.insert("    dependencies: [", at: insertIndex)
                lines.insert(contentsOf: newDependencyLines, at: insertIndex + 1)
                lines.insert("    ],", at: insertIndex + 1 + newDependencyLines.count)
            } else {
                // If we can't find the right place, insert after products section
                for (index, line) in lines.enumerated() {
                    if line.contains("products") && line.contains("[") {
                        let insertIndex = index + 3 // After products section
                        lines.insert("    dependencies: [", at: insertIndex)
                        lines.insert(contentsOf: newDependencyLines, at: insertIndex + 1)
                        lines.insert("    ],", at: insertIndex + 1 + newDependencyLines.count)
                        break
                    }
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    static func updateTargetDependencies(_ package: PackageInfo, with newTargetDependencies: [String: [String]]) -> String {
        guard let content = try? String(contentsOfFile: package.path, encoding: .utf8) else { return "" }
        
        var lines = content.components(separatedBy: .newlines)
        
        for (targetName, dependencies) in newTargetDependencies {
            // Find target and update its dependencies
            for (index, line) in lines.enumerated() {
                if line.contains("name: \"\(targetName)\"") {
                    // Find dependencies section for this target
                    var inTargetDependencies = false
                    var targetDependencyStartIndex = -1
                    var targetDependencyEndIndex = -1
                    
                    for i in index..<lines.count {
                        let currentLine = lines[i].trimmingCharacters(in: .whitespaces)
                        
                        if currentLine.contains("dependencies:") {
                            inTargetDependencies = true
                            targetDependencyStartIndex = i
                        } else if inTargetDependencies && currentLine.contains("]") {
                            targetDependencyEndIndex = i
                            break
                        }
                    }
                    
                    // Update target dependencies
                    if targetDependencyStartIndex >= 0 && targetDependencyEndIndex >= 0 {
                        let newTargetDependencyLines = dependencies.map { dependency in
                            "            \"\(dependency)\""
                        }
                        
                        lines.removeSubrange(targetDependencyStartIndex...targetDependencyEndIndex)
                        lines.insert("            dependencies: [", at: targetDependencyStartIndex)
                        lines.insert(contentsOf: newTargetDependencyLines, at: targetDependencyStartIndex + 1)
                        lines.insert("            ],", at: targetDependencyStartIndex + 1 + newTargetDependencyLines.count)
                    }
                    
                    break
                }
            }
        }
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - File System Helper

class FileSystemHelper {
    static func findPackageFiles(in directory: String) -> [String] {
        let fileManager = FileManager.default
        var packageFiles: [String] = []
        
        func search(in path: String) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                for item in contents {
                    let fullPath = "\(path)/\(item)"
                    if item == "Package.swift" {
                        packageFiles.append(fullPath)
                    } else if item.hasSuffix(".xcworkspace") == false && 
                              item.hasSuffix(".xcodeproj") == false &&
                              item != ".DS_Store" {
                        var isDirectory: ObjCBool = false
                        if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                            search(in: fullPath)
                        }
                    }
                }
            } catch {
                print("Error reading directory \(path): \(error)")
            }
        }
        
        search(in: directory)
        return packageFiles
    }
    
    static func getRelativePath(from basePath: String, to targetPath: String) -> String {
        let baseComponents = basePath.components(separatedBy: "/")
        let targetComponents = targetPath.components(separatedBy: "/")
        
        var commonPrefixLength = 0
        for (base, target) in zip(baseComponents, targetComponents) {
            if base == target {
                commonPrefixLength += 1
            } else {
                break
            }
        }
        
        let upLevels = baseComponents.count - commonPrefixLength
        let relativeComponents = targetComponents.dropFirst(commonPrefixLength)
        
        var relativePath = String(repeating: "../", count: upLevels)
        relativePath += relativeComponents.joined(separator: "/")
        
        return relativePath
    }
}

// MARK: - Main Logic

class DependencyUpdater {
    let workspacePath: String
    
    init(workspacePath: String) {
        self.workspacePath = workspacePath
    }
    
    func updateAllDependencies() {
        print("🔧 Starting dependency update...")
        
        // 1. Update Infrastructure/SharedInfrastructure
        updateSharedInfrastructure()
        
        // 2. Update */Foundation/SharedFoundation
        updateSharedFoundation()
        
        // 3. Update */Foundation/* (except SharedFoundation)
        updateFoundationModules()
        
        // 4. Update all Feature modules
        updateFeatureModules()
        
        print("✅ Dependency update completed!")
    }
    
    private func updateSharedInfrastructure() {
        print("📦 Updating Infrastructure/SharedInfrastructure...")
        
        let sharedInfraPath = "\(workspacePath)/Infrastructure/SharedInfrastructure/Package.swift"
        guard let package = PackageParser.parsePackage(at: sharedInfraPath) else {
            print("❌ Could not parse SharedInfrastructure package")
            return
        }
        
        // Find all Infrastructure modules
        let infrastructureModules = findInfrastructureModules()
        let dependencyPaths = infrastructureModules.map { module in
            let relativePath = FileSystemHelper.getRelativePath(from: "\(workspacePath)/Infrastructure/SharedInfrastructure", to: module)
            return relativePath.replacingOccurrences(of: "/Package.swift", with: "")
        }
        
        let newContent = PackageWriter.updatePackage(package, with: dependencyPaths)
        try? newContent.write(toFile: sharedInfraPath, atomically: true, encoding: .utf8)
        
        print("✅ Updated SharedInfrastructure with \(dependencyPaths.count) dependencies")
    }
    
    private func updateSharedFoundation() {
        print("📦 Updating */Foundation/SharedFoundation...")
        
        let sharedFoundationPaths = findSharedFoundationModules()
        
        for path in sharedFoundationPaths {
            guard let package = PackageParser.parsePackage(at: path) else { continue }
            
            // Find all Foundation modules in the same workspace
            let workspacePath = getWorkspacePath(from: path)
            let foundationModules = findFoundationModules(in: workspacePath)
            let dependencyPaths = foundationModules.map { module in
                let relativePath = FileSystemHelper.getRelativePath(from: path.replacingOccurrences(of: "/Package.swift", with: ""), to: module)
                return relativePath.replacingOccurrences(of: "/Package.swift", with: "")
            }
            
            let newContent = PackageWriter.updatePackage(package, with: dependencyPaths)
            try? newContent.write(toFile: path, atomically: true, encoding: .utf8)
            
            print("✅ Updated \(package.name) with \(dependencyPaths.count) dependencies")
        }
    }
    
    private func updateFoundationModules() {
        print("📦 Updating */Foundation/* (except SharedFoundation)...")
        
        let foundationModules = findFoundationModules()
        
        for path in foundationModules {
            // Skip SharedFoundation
            if path.contains("SharedFoundation") { continue }
            
            guard let package = PackageParser.parsePackage(at: path) else { continue }
            
            // Add SharedInfrastructure dependency
            let sharedInfraPath = FileSystemHelper.getRelativePath(
                from: path.replacingOccurrences(of: "/Package.swift", with: ""),
                to: "\(workspacePath)/Infrastructure/SharedInfrastructure"
            ).replacingOccurrences(of: "/Package.swift", with: "")
            
            let newContent = PackageWriter.updatePackage(package, with: [sharedInfraPath])
            try? newContent.write(toFile: path, atomically: true, encoding: .utf8)
            
            // Update target dependencies
            let targetDependencies = [package.name: ["SharedInfrastructure"]]
            let updatedContent = PackageWriter.updateTargetDependencies(package, with: targetDependencies)
            try? updatedContent.write(toFile: path, atomically: true, encoding: .utf8)
            
            // Also update test target dependencies if needed
            let testTargetDependencies = ["\(package.name)Tests": ["SharedInfrastructure"]]
            let finalContent = PackageWriter.updateTargetDependencies(package, with: testTargetDependencies)
            try? finalContent.write(toFile: path, atomically: true, encoding: .utf8)
            
            print("✅ Updated \(package.name) with SharedInfrastructure dependency")
        }
    }
    
    private func updateFeatureModules() {
        print("📦 Updating Feature modules...")
        
        let featureModules = findFeatureModules()
        
        for path in featureModules {
            guard let package = PackageParser.parsePackage(at: path) else { continue }
            
            // Find SharedFoundation in the same workspace
            let workspacePath = getWorkspacePath(from: path)
            let sharedFoundationPath = findSharedFoundationInWorkspace(workspacePath)
            
            if let sharedFoundationPath = sharedFoundationPath {
                let relativePath = FileSystemHelper.getRelativePath(
                    from: path.replacingOccurrences(of: "/Package.swift", with: ""),
                    to: sharedFoundationPath
                ).replacingOccurrences(of: "/Package.swift", with: "")
                
                let newContent = PackageWriter.updatePackage(package, with: [relativePath])
                try? newContent.write(toFile: path, atomically: true, encoding: .utf8)
                
                // Update target dependencies
                let targetDependencies = [package.name: ["SharedFoundation"]]
                let updatedContent = PackageWriter.updateTargetDependencies(package, with: targetDependencies)
                try? updatedContent.write(toFile: path, atomically: true, encoding: .utf8)
                
                // Also update test target dependencies if needed
                let testTargetDependencies = ["\(package.name)Tests": ["SharedFoundation"]]
                let finalContent = PackageWriter.updateTargetDependencies(package, with: testTargetDependencies)
                try? finalContent.write(toFile: path, atomically: true, encoding: .utf8)
                
                print("✅ Updated \(package.name) with SharedFoundation dependency")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func findInfrastructureModules() -> [String] {
        let infrastructurePath = "\(workspacePath)/Infrastructure"
        let packageFiles = FileSystemHelper.findPackageFiles(in: infrastructurePath)
        return packageFiles.filter { $0 != "\(workspacePath)/Infrastructure/SharedInfrastructure/Package.swift" }
    }
    
    private func findSharedFoundationModules() -> [String] {
        let packageFiles = FileSystemHelper.findPackageFiles(in: workspacePath)
        return packageFiles.filter { $0.contains("SharedFoundation") && $0.contains("Foundation") }
    }
    
    private func findFoundationModules() -> [String] {
        let packageFiles = FileSystemHelper.findPackageFiles(in: workspacePath)
        return packageFiles.filter { $0.contains("Foundation") && !$0.contains("SharedFoundation") }
    }
    
    private func findFoundationModules(in workspacePath: String) -> [String] {
        let packageFiles = FileSystemHelper.findPackageFiles(in: workspacePath)
        return packageFiles.filter { $0.contains("Foundation") && !$0.contains("SharedFoundation") }
    }
    
    private func findFeatureModules() -> [String] {
        let packageFiles = FileSystemHelper.findPackageFiles(in: workspacePath)
        return packageFiles.filter { $0.contains("Feature") }
    }
    
    private func getWorkspacePath(from packagePath: String) -> String {
        let components = packagePath.components(separatedBy: "/")
        if let flexIndex = components.firstIndex(of: "Flex") {
            return components.prefix(through: flexIndex).joined(separator: "/")
        } else if let leafIndex = components.firstIndex(of: "Leaf") {
            return components.prefix(through: leafIndex).joined(separator: "/")
        }
        return workspacePath
    }
    
    private func findSharedFoundationInWorkspace(_ workspacePath: String) -> String? {
        let packageFiles = FileSystemHelper.findPackageFiles(in: workspacePath)
        return packageFiles.first { $0.contains("SharedFoundation") && $0.contains("Foundation") }
    }
}

// MARK: - Main Execution

let workspacePath = FileManager.default.currentDirectoryPath
let updater = DependencyUpdater(workspacePath: workspacePath)
updater.updateAllDependencies()
