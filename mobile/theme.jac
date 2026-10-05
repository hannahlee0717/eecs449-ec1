import from "@jac/mobui" { StyleSheet }

obj Colors {
    has bg: str = "#ffffff",
        panel: str = "#fdf2f8",
        border: str = "#fce7f3",
        text: str = "#1f2937",
        muted: str = "#9ca3af",
        accent: str = "#f9a8d4",
        accentInk: str = "#9d174d",
        clock: str = "#f472b6",
        danger: str = "#dc2626",
        surface: str = "#f3f4f6";
}

glob:pub C = Colors();

glob:pub styles = StyleSheet.create({
    screen: {flex: 1, backgroundColor: C.bg},
    body: {padding: 16, gap: 14, paddingBottom: 48},
    header: {flexDirection: "row", alignItems: "center", gap: 12, marginTop: 8},
    avatar: {
        width: 48,
        height: 48,
        borderRadius: 24,
        backgroundColor: "#e5e7eb",
        alignItems: "center",
        justifyContent: "center"
    },
    avatarText: {fontSize: 26},
    brand: {color: "#16a34a", fontWeight: "bold", fontStyle: "italic", fontSize: 16},
    name: {fontWeight: "bold", fontSize: 16, color: C.text},
    sub: {fontSize: 13, color: C.muted},
    card: {
        backgroundColor: C.bg,
        borderRadius: 18,
        borderWidth: 4,
        borderColor: C.border,
        padding: 16,
        gap: 10
    },
    timerCard: {
        backgroundColor: C.panel,
        borderRadius: 18,
        padding: 18,
        alignItems: "center",
        gap: 8
    },
    sectionTitle: {fontSize: 15, fontWeight: "bold", color: C.text},
    clock: {fontSize: 56, color: C.clock, fontWeight: "300"},
    small: {fontSize: 12, color: C.muted},
    row: {flexDirection: "row", alignItems: "center", gap: 8},
    between: {flexDirection: "row", alignItems: "center", justifyContent: "space-between"},
    pill: {
        paddingVertical: 10,
        paddingHorizontal: 36,
        borderRadius: 999,
        backgroundColor: C.accent
    },
    pillText: {color: C.accentInk, fontWeight: "bold", fontSize: 16, letterSpacing: 1},
    ghost: {
        paddingVertical: 6,
        paddingHorizontal: 14,
        borderRadius: 999,
        backgroundColor: C.bg
    },
    ghostText: {color: "#6b7280", fontSize: 12},
    taskRow: {
        flexDirection: "row",
        alignItems: "center",
        gap: 10,
        paddingVertical: 10,
        paddingHorizontal: 10,
        borderRadius: 10
    },
    check: {
        width: 24,
        height: 24,
        borderRadius: 12,
        borderWidth: 2,
        borderColor: "#d1d5db",
        alignItems: "center",
        justifyContent: "center"
    },
    taskTitle: {fontSize: 15, color: C.text},
    taskDone: {fontSize: 15, color: C.muted, textDecorationLine: "line-through"},
    chip: {paddingVertical: 4, paddingHorizontal: 10, borderRadius: 8},
    chipText: {fontSize: 12, fontWeight: "bold"},
    input: {
        borderWidth: 1,
        borderColor: "#e5e7eb",
        backgroundColor: "#f9fafb",
        borderRadius: 8,
        paddingVertical: 8,
        paddingHorizontal: 10,
        fontSize: 14,
        color: C.text
    },
    timeInput: {
        flex: 1,
        borderWidth: 1,
        borderColor: "#e5e7eb",
        backgroundColor: "#f9fafb",
        borderRadius: 8,
        paddingVertical: 8,
        paddingHorizontal: 10,
        fontSize: 14,
        color: C.text
    },
    banner: {backgroundColor: "#fef2f2", borderRadius: 8, padding: 10},
    bannerText: {color: C.danger, fontSize: 12}
});
