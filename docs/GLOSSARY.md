# Glossary

**Construct**
A named piece of authoring vocabulary that carries editorial meaning beyond plain prose: an honorific, an ayah block, a hadith block, a translation pair, a highlight. Every construct has one canonical spelling in the source; anything that looks like a construct but is not in the vocabulary is an error, not text.
_Avoid_: macro, shortcode (those name the old mechanism, not the concept)

**Ayah reference**
A pointer to Qur'anic text by surah and ayah: a single ayah, a range of ayat, or part of an ayah. The template can resolve it to the Arabic text from the bundled Qur'an data.
_Avoid_: verse ref, Quran ref

**Word slice**
A selection of words from the start or end of an ayah (or range), used when only part of an ayah is quoted. Slices compose.

**Arabic block / translation block**
The two parts a construct like an ayah or hadith can carry: Arabic text, then its English rendering. Either may be absent; when both are present the Arabic always comes first.

**Custom class**
A class an author adds that is not a construct. It is allowed and passed through untouched, but the build mentions it.

**Translation pair**
An Arabic source passage together with its English target rendering, kept side by side during drafting and reduced to the English alone in the final edition.

**Honorific**
A fixed formula of praise or supplication attached to a name (e.g. ṣallā Allāhu ʿalayhi wa sallam), rendered in Arabic or English depending on the edition.

**Edition**
Which state of the book a build represents: a *draft* for translators and editors, or the *final* text for readers. A final edition drops Arabic source passages from translation pairs and tolerates no leftover editorial marks.
_Avoid_: mode, release

**Output format**
A kind of deliverable the template produces from the same source: DOCX, ODT, EPUB, HTML, and later PDF.
