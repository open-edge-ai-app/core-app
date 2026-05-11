package com.onda.core

data class RuntimeStatus(
    val modelInstalled: Boolean,
    val loaded: Boolean,
    val loading: Boolean,
    val canGenerate: Boolean,
    val localPath: String,
    val error: String?,
)
