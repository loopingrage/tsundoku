import CoreImage
import Foundation
import MLX
import MLXLMCommon
import MLXVLM

/// Reads book spine text using SmolVLM2-500M via MLX Swift.
/// Requires Metal GPU — will not work in iOS Simulator.
final class VLMSpineRecognizer: SpineRecognizer, @unchecked Sendable {

    private static let modelId = "HuggingFaceTB/SmolVLM2-500M-Video-Instruct-mlx"
    private static let maxTokens = 100

    private static let prompt = """
        Read the text on this book spine. Return only the title and author \
        in the format: Title by Author. If you can't read the author, return just the title.
        """

    private var container: ModelContainer?

    func loadModel(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        let config = ModelConfiguration(
            id: Self.modelId,
            defaultPrompt: Self.prompt
        )

        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        container = try await VLMModelFactory.shared.loadContainer(
            configuration: config
        ) { p in
            progress?(p.fractionCompleted)
        }
    }

    func recognize(in image: CGImage) async throws -> SpineRecognition? {
        if container == nil {
            try await loadModel()
        }
        guard let container else { return nil }

        let ciImage = CIImage(cgImage: image)

        let result = try await container.perform { context in
            let messages: [[String: Any]] = [
                [
                    "role": "user",
                    "content": [
                        ["type": "image"],
                        ["type": "text", "text": Self.prompt]
                    ]
                ]
            ]

            let userInput = UserInput(
                messages: messages,
                images: [.ciImage(ciImage)],
                videos: []
            )
            let input = try await context.processor.prepare(input: userInput)

            let parameters = GenerateParameters(temperature: 0.1)

            return try MLXLMCommon.generate(
                input: input,
                parameters: parameters,
                context: context
            ) { tokens in
                tokens.count >= Self.maxTokens ? .stop : .more
            }
        }

        let text = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return SpineRecognition(
            searchQuery: text,
            fullText: text,
            observations: []
        )
    }
}
