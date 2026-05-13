package com.onda.core

data class AIResponse(
    val type: String,
    val message: String,
    val route: String,
    val modalities: List<String>,
    val reasoning: String? = null,
)
