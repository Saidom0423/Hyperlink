package com.example.hyperlink

import java.util.Collections

object AppDeviceRegistry {
    val verifiedNames: MutableSet<String> = Collections.synchronizedSet(HashSet())
    val macToName: MutableMap<String, String> = Collections.synchronizedMap(HashMap())
}
