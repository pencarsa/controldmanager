#!/usr/bin/env swift

import Foundation

// Test script to debug ControlD profiles API
// This will help us understand the exact API response structure

struct Profile: Codable {
    let PK: String
    let name: String
    let updated: Int
    let disable_ttl: Int?
    let profile: ProfileData?
}

struct ProfileData: Codable {
    let flt: FilterCount?
    let cflt: FilterCount?
    let ipflt: FilterCount?
    let rule: FilterCount?
    let svc: FilterCount?
    let grp: FilterCount?
    let opt: OptionData?
    let da: DataAccessInfo?
}

struct FilterCount: Codable {
    let count: Int
}

struct OptionData: Codable {
    let count: Int
    let data: [OptionItem]?
}

struct OptionItem: Codable {
    let PK: String
    let value: Double
}

struct DataAccessInfo: Codable {
    let `do`: Int
    let status: Int
}

struct ProfilesResponse: Codable {
    let body: ProfilesBody
    let success: Bool
}

struct ProfilesBody: Codable {
    let profiles: [Profile]
}

// Test the API directly
func testProfilesAPI() {
    // You'll need to replace this with your actual API token
    let apiToken = "YOUR_API_TOKEN_HERE"
    let baseURL = "https://api.controld.com"
    
    guard let url = URL(string: "\(baseURL)/profiles") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    print("🔍 Testing API endpoint: \(url)")
    print("🔑 Using token: \(String(apiToken.prefix(10)))...")
    
    let semaphore = DispatchSemaphore(value: 0)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        
        if let error = error {
            print("❌ Network error: \(error)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response")
            return
        }
        
        print("📡 Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data ?? Data(), encoding: .utf8) ?? "No response body"
            print("❌ API Error Response: \(responseString)")
            return
        }
        
        guard let data = data else {
            print("❌ No data received")
            return
        }
        
        // Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Raw API Response:")
            print(responseString)
            print("---")
        }
        
        // Try to decode
        do {
            let profilesResponse = try JSONDecoder().decode(ProfilesResponse.self, from: data)
            print("✅ Successfully decoded \(profilesResponse.body.profiles.count) profiles")
            
            for profile in profilesResponse.body.profiles {
                print("  📋 Profile: \(profile.name) (ID: \(profile.PK))")
            }
        } catch {
            print("❌ Decoding error: \(error)")
            
            // Try to decode as a simpler structure
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📄 JSON structure:")
                    print(json)
                }
            } catch {
                print("❌ Failed to parse as JSON: \(error)")
            }
        }
    }.resume()
    
    semaphore.wait()
}

// Run the test
print("🧪 ControlD Profiles API Test")
print("==============================")
print("")
print("⚠️  IMPORTANT: Replace 'YOUR_API_TOKEN_HERE' with your actual API token")
print("⚠️  This script will make a real API call to ControlD")
print("")
print("To run this test:")
print("1. Edit this file and replace YOUR_API_TOKEN_HERE with your actual token")
print("2. Run: swift test_profiles_api.swift")
print("")
print("This will help us understand the exact API response structure.")
