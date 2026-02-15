//
//  generate_keywords_playground.swift
//  appstore
//
//  Created by Andrew Benson on 9/26/25.
//

import Foundation
import FoundationModels
import Playgrounds // Required for async operations in Playground

@Generable(description: "Keywords that users might enter as a search string for when looking for an this app or an app with similar functionality")
struct Keywords {
    @Guide(description: "Each keyword must be one that a user might enter as a search string when looking for this app or an app with similar functionality")
    var simpleKeywords: [String]
    
    @Guide(description: "Keyword phrases. A keyword phrase is 2 or more keywords separated by whitespace")
    var keywordPhrases: [String]
}

// Set up the Playground to run indefinitely for async operations
#Playground {
    let session = LanguageModelSession()
    
    Task {
        do {
            let response = try await session.respond(to:
            """
            Below are the title and description of an App on the App Store. Generate two lists of keywords that a user would be likely to type when they were looking for an app like the one described. One list will be simple keywords, where each entry in the array is a single word (not a phrase), and a second list will be keyword phrases (two or more whitespace-separated keywords to be used together as a single search term). Include no more than 12 keywords in each array. Remember to consider synonyms and common misspellings, and remember that every response should be something a person is likely to type on their phone into a search field.
            
            App title: 
            Fish Identifier: 96% Accurate
            
            App description:
            Snap a pic and identify that fish!  96% accurate. See fish details, records, fishing tips. Share your catches! Fish photo book logs your catches. Scientific details too.
            Most accurate fish identifier. AI fish identifier scans your photos and identifies the fish for you. On the rare cases when it isn't sure about the fish in your picture, it'll tell you that too!
            
            Fast, accurate, reliable. No ads. No watermarks. Ever.
            
            Quickly get ALL the fishy info you want!
            * Fish species - common name
            * scientific species name
            * full species taxonomy 
            * alternate names (both common and scientific)
            * a typical photo of the identified species
            * handling instructions
            * health warnings
            * physical characteristics (max length, weight, temp
            * value as food (is it good to eat?)
            * habitat - freshwater, saltwater, brackish water and where it can be found
            * environment (is it a bottom dweller?)
            * similar species names and photos
            * IGFA records for weight and length
            * coloration
            * physical description
            * conservation information
            * reproduction details
            
            96% accuracy claim is based on cases where a fish is found in the photo and the AI identifier returns a high confidence match. Low confidence matches and pics where no fish could be found are indicated in the app.
            
            This app offers subscriptions at reasonable prices.
            
            Privacy policy: https://nuclearcyborg.com/privacy
            Terms of use: https://nuclearcyborg.com/terms
            """, generating: Keywords.self)
            
            let keywords = response.content
            print("Simple keywords:")
            for keyword in keywords.simpleKeywords {
                print("- \(keyword)")
            }
            print("\nKeyword phrases:")
            for keyword in keywords.keywordPhrases {
                print("- \(keyword)")
            }
//            print(response.content)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
