import Foundation
import LabelCore

func runGuidedShippingTests() throws {
    func check(_ value: Bool, _ message: String) throws {
        if !value { throw NSError(domain: "GuidedShipping", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    var journey = GuidedShippingJourney()
    journey.advance(); journey.back()
    try check(journey.task == nil && journey.step == nil, "Home navigation must remain bounded")
    journey.choose(.letter)
    journey.advance()
    journey.receivePostage()
    try check(journey.task == .letter && journey.step == .franking, "Letter stock import must preserve letter navigation")
    journey.advance(); journey.advance(); journey.advance()
    try check(journey.step == .review && journey.nextStep == nil, "Letter must end at review")
    journey.goBack(to: .franking)
    try check(journey.step == .franking, "Review must allow correcting a missing stamp directly")
    journey.goBack(to: .review)
    journey.goBack(to: .postageSelection)
    try check(journey.step == .franking, "Correction must not skip ahead or enter a different task")
    journey.advance(); journey.advance(); journey.back()
    try check(journey.step == .format, "Back must return to the previous choice")
    let id = UUID()
    journey.receiveParcel(id)
    try check(journey.task == .parcel && journey.step == .review && journey.parcelJobID == id, "Imported parcel must review the actual job")
    journey.back()
    try check(journey.step == .parcelFile && journey.parcelJobID == id, "Replacing a parcel must retain the previous selection until imported")
    journey.receivePostage()
    try check(journey.task == .postage && journey.step == .postageSelection && journey.parcelJobID == nil, "Postage import must discard unrelated parcel navigation")
    journey.choose(.letter)
    try check(journey.index == 0 && journey.parcelJobID == nil, "Task switch must reset step and parcel reference")
    journey.back()
    try check(journey.task == nil, "Back from first step must return home")
}
