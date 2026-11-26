import QtQuick
import "../journal"
import "SectionLogos.js" as Logos

// A rail logo: a journal Glyph whose path comes from the section id.
Glyph {
    required property string sectionId
    size: 20
    path: Logos.pathFor(sectionId)
}
