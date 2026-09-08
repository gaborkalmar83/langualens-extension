package com.langualens.browser.translate

/** The 59 languages ML Kit translates fully on device. */
object Languages {

    data class Lang(val tag: String, val english: String, val native: String) {
        val label: String get() = if (english == native) english else "$native  ·  $english"
    }

    /** Kept at the top of the picker because these are the ones actually used here. */
    private val PINNED = listOf("nl", "en", "hu", "de", "es", "fr", "mk", "hr", "it", "pl")

    val ALL: List<Lang> = listOf(
        Lang("af", "Afrikaans", "Afrikaans"),
        Lang("ar", "Arabic", "العربية"),
        Lang("be", "Belarusian", "Беларуская"),
        Lang("bg", "Bulgarian", "Български"),
        Lang("bn", "Bengali", "বাংলা"),
        Lang("ca", "Catalan", "Català"),
        Lang("cs", "Czech", "Čeština"),
        Lang("cy", "Welsh", "Cymraeg"),
        Lang("da", "Danish", "Dansk"),
        Lang("de", "German", "Deutsch"),
        Lang("el", "Greek", "Ελληνικά"),
        Lang("en", "English", "English"),
        Lang("eo", "Esperanto", "Esperanto"),
        Lang("es", "Spanish", "Español"),
        Lang("et", "Estonian", "Eesti"),
        Lang("fa", "Persian", "فارسی"),
        Lang("fi", "Finnish", "Suomi"),
        Lang("fr", "French", "Français"),
        Lang("ga", "Irish", "Gaeilge"),
        Lang("gl", "Galician", "Galego"),
        Lang("gu", "Gujarati", "ગુજરાતી"),
        Lang("he", "Hebrew", "עברית"),
        Lang("hi", "Hindi", "हिन्दी"),
        Lang("hr", "Croatian", "Hrvatski"),
        Lang("ht", "Haitian Creole", "Kreyòl ayisyen"),
        Lang("hu", "Hungarian", "Magyar"),
        Lang("id", "Indonesian", "Bahasa Indonesia"),
        Lang("is", "Icelandic", "Íslenska"),
        Lang("it", "Italian", "Italiano"),
        Lang("ja", "Japanese", "日本語"),
        Lang("ka", "Georgian", "ქართული"),
        Lang("kn", "Kannada", "ಕನ್ನಡ"),
        Lang("ko", "Korean", "한국어"),
        Lang("lt", "Lithuanian", "Lietuvių"),
        Lang("lv", "Latvian", "Latviešu"),
        Lang("mk", "Macedonian", "Македонски"),
        Lang("mr", "Marathi", "मराठी"),
        Lang("ms", "Malay", "Bahasa Melayu"),
        Lang("mt", "Maltese", "Malti"),
        Lang("nl", "Dutch", "Nederlands"),
        Lang("no", "Norwegian", "Norsk"),
        Lang("pl", "Polish", "Polski"),
        Lang("pt", "Portuguese", "Português"),
        Lang("ro", "Romanian", "Română"),
        Lang("ru", "Russian", "Русский"),
        Lang("sk", "Slovak", "Slovenčina"),
        Lang("sl", "Slovenian", "Slovenščina"),
        Lang("sq", "Albanian", "Shqip"),
        Lang("sv", "Swedish", "Svenska"),
        Lang("sw", "Swahili", "Kiswahili"),
        Lang("ta", "Tamil", "தமிழ்"),
        Lang("te", "Telugu", "తెలుగు"),
        Lang("th", "Thai", "ไทย"),
        Lang("tl", "Tagalog", "Tagalog"),
        Lang("tr", "Turkish", "Türkçe"),
        Lang("uk", "Ukrainian", "Українська"),
        Lang("ur", "Urdu", "اردو"),
        Lang("vi", "Vietnamese", "Tiếng Việt"),
        Lang("zh", "Chinese", "中文")
    )

    private val byTag: Map<String, Lang> = ALL.associateBy { it.tag }

    val ORDERED: List<Lang> =
        PINNED.mapNotNull { byTag[it] } + ALL.filterNot { PINNED.contains(it.tag) }.sortedBy { it.english }

    fun supports(tag: String): Boolean = byTag.containsKey(tag)

    fun nameOf(tag: String): String = byTag[tag]?.native ?: tag.uppercase()

    fun labelOf(tag: String): String = byTag[tag]?.label ?: tag.uppercase()

    /** "en-GB" and "nl_NL" both mean the base language as far as ML Kit is concerned. */
    fun base(tag: String?): String =
        (tag ?: "").lowercase().substringBefore('-').substringBefore('_')
}
