package com.openedgeai.core

private const val MIN_RUNAWAY_RUN_LENGTH = 16
private const val MIN_RUNAWAY_REPEATS = 6
private const val MAX_RUNAWAY_UNIT_LENGTH = 32

private val RUNAWAY_REPEAT_REGEX =
    Regex(
        "(.{1,$MAX_RUNAWAY_UNIT_LENGTH}?)\\1{${MIN_RUNAWAY_REPEATS - 1},}",
        RegexOption.DOT_MATCHES_ALL,
    )

/**
 * Collapses runaway repetition such as "0,0,0,0,..." that small on-device models fall into when
 * they degenerate. collapseRepeatedText() only catches whole-string N-way duplication and
 * sentence-level repeats, so a long run of a short comma-separated unit slips through untouched.
 * A run only collapses when it is both long and repeated many times, so ordinary prose, ellipses,
 * and grouped numbers are left intact.
 */
internal fun collapseRunawayRepetition(text: String): String {
    if (text.length < MIN_RUNAWAY_RUN_LENGTH) {
        return text
    }
    return RUNAWAY_REPEAT_REGEX.replace(text) { match ->
        val unit = match.groupValues[1]
        val runLength = match.value.length
        val repeats = if (unit.isEmpty()) 0 else runLength / unit.length
        // Single-character units (e.g. "ㅋㅋㅋ", "!!!") need a much longer run before they count as
        // degeneration, so ordinary emphatic repetition in user text survives.
        val minRepeats = if (unit.length == 1) MIN_RUNAWAY_REPEATS * 4 else MIN_RUNAWAY_REPEATS
        if (unit.isNotBlank() && runLength >= MIN_RUNAWAY_RUN_LENGTH && repeats >= minRepeats) {
            unit
        } else {
            match.value
        }
    }
}
