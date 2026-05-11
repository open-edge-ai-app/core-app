package com.onda.core

object LiteRtLmReflector {
    private const val PACKAGE_NAME = "com.google.ai.edge.litertlm"

    fun createEngine(
        modelPath: String,
        cacheDir: String,
    ): Any {
        val backendClass = Class.forName("$PACKAGE_NAME.Backend")
        val cpuBackendClass = Class.forName("$PACKAGE_NAME.Backend\$CPU")
        val engineConfigClass = Class.forName("$PACKAGE_NAME.EngineConfig")
        val engineClass = Class.forName("$PACKAGE_NAME.Engine")

        val cpuBackend = cpuBackendClass.getConstructor().newInstance()
        val engineConfig = engineConfigClass
            .getConstructor(
                String::class.java,
                backendClass,
                backendClass,
                backendClass,
                Integer::class.java,
                Integer::class.java,
                String::class.java,
            )
            .newInstance(
                modelPath,
                cpuBackend,
                cpuBackend,
                cpuBackend,
                null,
                null,
                cacheDir,
            )

        val engine = engineClass.getConstructor(engineConfigClass).newInstance(engineConfig)
        engineClass.getMethod("initialize").invoke(engine)
        return engine
    }

    fun sendText(
        engine: Any,
        text: String,
    ): String {
        val conversation = createConversation(engine)
        return try {
            val response = conversation.javaClass
                .getMethod("sendMessage", String::class.java, Map::class.java)
                .invoke(conversation, text, emptyMap<String, Any>())
            response?.toString().orEmpty()
        } finally {
            (conversation as? AutoCloseable)?.close()
        }
    }

    fun sendMultimodal(
        engine: Any,
        request: MultimodalRequest,
    ): String {
        val contentParts = buildContentParts(request)
        if (contentParts.isEmpty()) {
            return sendText(engine, request.text)
        }

        val contents = createContents(contentParts)
        val conversation = createConversation(engine)
        return try {
            val response = conversation.javaClass
                .getMethod("sendMessage", contents.javaClass, Map::class.java)
                .invoke(conversation, contents, emptyMap<String, Any>())
            response?.toString().orEmpty()
        } finally {
            (conversation as? AutoCloseable)?.close()
        }
    }

    private fun createConversation(engine: Any): Any {
        val engineClass = Class.forName("$PACKAGE_NAME.Engine")
        val conversationConfigClass = Class.forName("$PACKAGE_NAME.ConversationConfig")
        return requireNotNull(
            engineClass
            .getMethod(
                "createConversation\$default",
                engineClass,
                conversationConfigClass,
                Int::class.javaPrimitiveType,
                Any::class.java,
            )
            .invoke(null, engine, null, 1, null),
        )
    }

    private fun buildContentParts(request: MultimodalRequest): List<Any> {
        val parts = mutableListOf<Any>()
        request.attachments.forEach { attachment ->
            when (attachment.type) {
                "image" -> parts.add(createContent("ImageFile", attachment.uri))
                "audio" -> parts.add(createContent("AudioFile", attachment.uri))
            }
        }

        val text = request.text.trim()
        if (text.isNotEmpty()) {
            parts.add(createContent("Text", text))
        }
        return parts
    }

    private fun createContent(
        type: String,
        value: String,
    ): Any {
        val contentClass = Class.forName("$PACKAGE_NAME.Content\$$type")
        return contentClass.getConstructor(String::class.java).newInstance(value)
    }

    private fun createContents(contentParts: List<Any>): Any {
        val contentsClass = Class.forName("$PACKAGE_NAME.Contents")
        val companion = contentsClass.getField("Companion").get(null)
        return requireNotNull(
            companion.javaClass
            .getMethod("of", List::class.java)
            .invoke(companion, contentParts),
        )
    }
}
