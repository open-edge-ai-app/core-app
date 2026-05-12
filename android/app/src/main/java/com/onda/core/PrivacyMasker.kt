package com.onda.core

data class PrivacyMaskResult(
    val original: String,
    val masked: String,
    val changed: Boolean,
    val findings: List<String>,
)

object PrivacyMasker {
    fun maskForExternalSearch(text: String): PrivacyMaskResult {
        var masked = text
        val findings = mutableSetOf<String>()

        MASKING_RULES.forEach { rule ->
            if (rule.regex.containsMatchIn(masked)) {
                findings.add(rule.type)
                masked = rule.regex.replace(masked, rule.replacement)
            }
        }

        return PrivacyMaskResult(
            original = text,
            masked = masked.replace(Regex("\\s+"), " ").trim(),
            changed = masked != text,
            findings = findings.toList().sorted(),
        )
    }

    private data class MaskingRule(
        val type: String,
        val regex: Regex,
        val replacement: String,
    )

    private val MASKING_RULES = listOf(
        MaskingRule(
            type = "local_uri",
            regex = Regex("""(?i)\b(?:content|file)://\S+"""),
            replacement = "[local-uri]",
        ),
        MaskingRule(
            type = "local_path",
            regex = Regex("""(?i)(?:/storage|/sdcard|/data/user|[A-Z]:\\)[^\s]+"""),
            replacement = "[local-path]",
        ),
        MaskingRule(
            type = "email",
            regex = Regex("""\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b""", RegexOption.IGNORE_CASE),
            replacement = "[email]",
        ),
        MaskingRule(
            type = "korean_resident_id",
            regex = Regex("""\b\d{6}[-\s]?[1-4]\d{6}\b"""),
            replacement = "[national-id]",
        ),
        MaskingRule(
            type = "phone",
            regex = Regex("""(?<!\d)(?:\+?82[-.\s]?)?(?:0?1[016789]|0[2-6][1-5]?|070)[-.\s]?\d{3,4}[-.\s]?\d{4}(?!\d)"""),
            replacement = "[phone]",
        ),
        MaskingRule(
            type = "credit_card",
            regex = Regex("""(?<!\d)(?:\d[ -]*?){13,19}(?!\d)"""),
            replacement = "[card-number]",
        ),
        MaskingRule(
            type = "bank_account",
            regex = Regex("""(?i)(계좌|account)\s*[:=]?\s*[0-9 -]{8,24}"""),
            replacement = "\$1 [account-number]",
        ),
        MaskingRule(
            type = "api_key",
            regex = Regex("""(?i)\b(?:api[_-]?key|token|secret|password)\s*[:=]\s*['"]?[^'"\s]{8,}"""),
            replacement = "[secret]",
        ),
        MaskingRule(
            type = "gps",
            regex = Regex("""(?i)\b(?:lat|latitude|lng|lon|longitude)\s*[:=]\s*-?\d{1,3}\.\d+"""),
            replacement = "[coordinate]",
        ),
        MaskingRule(
            type = "detailed_address",
            regex = Regex("""(?:[가-힣]+(?:시|도)\s*)?[가-힣]+(?:시|군|구)\s+[가-힣0-9]+(?:로|길)\s*\d+(?:-\d+)?(?:\s*\d+동|\s*\d+호)?"""),
            replacement = "[address]",
        ),
        MaskingRule(
            type = "named_person",
            regex = Regex("""(?i)(이름|성명|name)\s*[:=]?\s*[가-힣A-Za-z]{2,30}"""),
            replacement = "\$1 [name]",
        ),
    )
}
