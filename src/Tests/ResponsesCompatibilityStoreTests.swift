import XCTest
@testable import CLIProxyMenuBar

final class ResponsesCompatibilityStoreTests: XCTestCase {
    func testNormalizePathRemovesApiPrefixForV1Requests() {
        let store = ResponsesCompatibilityStore()

        XCTAssertEqual(store.normalizePath("/api/v1/responses"), "/v1/responses")
        XCTAssertEqual(store.normalizePath("/api/v1/responses?foo=bar"), "/v1/responses?foo=bar")
        XCTAssertEqual(store.normalizePath("/v1/responses"), "/v1/responses")
    }

    func testPrepareRequestExpandsStoredPreviousResponseIntoTranscript() {
        let store = ResponsesCompatibilityStore()

        let firstPreparation = store.prepareRequest(
            path: "/v1/responses",
            body: #"{"model":"gpt-5.2-codex","input":"Remember this codeword exactly: LIME-ROCKET-731.","store":true}"#
        )
        let firstTransformer = try XCTUnwrap(store.jsonResponseTransformer(for: firstPreparation.pendingResponse))
        let firstResponse = firstTransformer(
            #"{"id":"resp_1","object":"response","store":false,"previous_response_id":null,"output":[{"type":"message","content":[{"type":"output_text","text":"LIME-ROCKET-731"}]}]}"#
        )

        XCTAssertTrue(firstResponse.contains(#""store":true"#))

        let secondPreparation = store.prepareRequest(
            path: "/v1/responses",
            body: #"{"model":"gpt-5.2-codex","input":"What was the codeword? Reply with exactly the codeword.","previous_response_id":"resp_1","store":true}"#
        )

        XCTAssertEqual(secondPreparation.path, "/v1/responses")
        XCTAssertFalse(secondPreparation.body.contains(#""previous_response_id":"resp_1""#))
        XCTAssertTrue(secondPreparation.body.contains("User: Remember this codeword exactly: LIME-ROCKET-731."))
        XCTAssertTrue(secondPreparation.body.contains("Assistant: LIME-ROCKET-731"))
        XCTAssertTrue(secondPreparation.body.contains("User: What was the codeword? Reply with exactly the codeword."))
    }

    func testResponseTransformerRestoresRequestedMetadata() throws {
        let store = ResponsesCompatibilityStore()
        let preparation = store.prepareRequest(
            path: "/v1/responses",
            body: #"{"model":"gpt-5.2-codex","input":"Hello","previous_response_id":"resp_prev","store":true}"#
        )

        let transformer = try XCTUnwrap(store.jsonResponseTransformer(for: preparation.pendingResponse))
        let rewritten = transformer(
            #"{"id":"resp_new","object":"response","store":false,"previous_response_id":null,"output":[{"type":"message","content":[{"type":"output_text","text":"Hi there"}]}]}"#
        )

        XCTAssertTrue(rewritten.contains(#""store":true"#))
        XCTAssertTrue(rewritten.contains(#""previous_response_id":"resp_prev""#))
        XCTAssertEqual(
            store.transcript(for: "resp_new"),
            "User: Hello\nAssistant: Hi there"
        )
    }
}
