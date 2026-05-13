package com.openedgeai.core

data class StartupState(
    val ready: Boolean,
    val nextAction: String,
    val message: String,
    val modelStatus: ModelStatus,
)
