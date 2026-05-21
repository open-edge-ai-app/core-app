package com.openedgeai.core

data class AIResponse(
    val type: String,
    val message: String,
    val route: String,
    val modalities: List<String>,
    val reasoning: String? = null,
    val modelId: String = ModelFileManager.MODEL_ID,
    val modelName: String = ModelFileManager.MODEL_NAME,
    val provider: String = "google",
    val requestedModelId: String? = null,
)
