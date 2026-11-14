package io.github.kouotou.qoesense.capture

/**
 * Counts serving-cell changes (handovers and idle reselections) between two captures, for the
 * v2 field `cellChangesSinceLastSample` (report alignment, 2026-11-14).
 *
 * It's fed from two places: the CellInfo listener, which sees changes between captures, and
 * each capture's own fresh reading. Every change of the serving-cell key is counted, so a
 * ping-pong A → B → A counts 2. Pure (no Android types), so it's unit-tested on the JVM.
 *
 * [takeForSample] returns null for the first capture after start or [reset]: there is no
 * "previous sample" to count from.
 */
class CellChangeCounter {
    private var lastKey: String? = null
    private var changes = 0
    private var armed = false

    /** A serving-cell key seen now. Null (no serving cell visible) changes nothing. */
    @Synchronized
    fun observe(servingKey: String?) {
        if (servingKey == null) return
        val previous = lastKey
        if (previous != null && previous != servingKey) changes++
        lastKey = servingKey
    }

    /** The changes since the previous call (null on the first), then starts a new interval. */
    @Synchronized
    fun takeForSample(): Int? {
        val result = if (armed) changes else null
        armed = true
        changes = 0
        return result
    }

    /** Permission lost or collection restarted: the next sample has no baseline again. */
    @Synchronized
    fun reset() {
        lastKey = null
        changes = 0
        armed = false
    }

    companion object {
        private const val UNAVAILABLE = Int.MAX_VALUE

        /**
         * One LTE/NR cell: **PCI + channel**, falling back to the cell ID only without a PCI.
         * On the test phone (Infinix X669, 2026-11-14) the modem sometimes reported the same
         * serving cell with its cell ID unavailable (2147483647) but the same PCI, so a key
         * that included the cell ID counted fake changes. Neighbouring cells never share both
         * PCI and channel (that's what PCI planning guarantees). Null when nothing identifies it.
         */
        fun cellKey(rat: String, pci: Int, channel: Int, cellId: Long): String? {
            val ch = if (channel == UNAVAILABLE || channel < 0) "?" else "$channel"
            return when {
                pci != UNAVAILABLE && pci >= 0 -> "$rat:pci=$pci:ch=$ch"
                cellId != UNAVAILABLE.toLong() && cellId != Long.MAX_VALUE && cellId >= 0 -> "$rat:id=$cellId:ch=$ch"
                else -> null
            }
        }

        /**
         * The set of registered cells as one key. A dual-SIM phone has a registered cell per
         * SIM, and the list order can change between readings; a sorted set doesn't. A change
         * on either SIM still counts. Null when no registered cell is identifiable.
         */
        fun servingSetKey(cellKeys: List<String?>): String? =
            cellKeys.filterNotNull().distinct().sorted().takeIf { it.isNotEmpty() }?.joinToString("|")
    }
}
