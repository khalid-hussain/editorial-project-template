# Qur'an data and fonts: provenance

| File | What it is | Source | Version |
|---|---|---|---|
| `hafsData_v18.csv` | Qur'an text, Ḥafṣ ʿan ʿĀṣim, Uthmani script, one row per ayah (6,236 rows) | King Fahd Glorious Qur'an Printing Complex (KFGQPC); the same data is mirrored at [ibnhazm/KFGQPC](https://github.com/ibnhazm/KFGQPC) | v18 |
| `surah-names.csv` | The project's own transliterations of the 114 surah names | This project | — |
| `../fonts/UthmanicHafs_V22.ttf` | KFGQPC Uthmanic Script Hafs font (Qur'an text) | KFGQPC, [fonts.qurancomplex.gov.sa](https://fonts.qurancomplex.gov.sa/) | v22 |
| `../fonts/UthmanTN1Ver20.ttf` | KFGQPC Uthman Taha Naskh font (other Arabic text) | KFGQPC | v20 |

## Rules

- `hafsData_v18.csv` ships **unmodified**. The build parses it as it is: no conversion, no trimmed columns. To update, replace the file and change the file name in `utils/lua/quran.lua`.
- Each `aya_text` value has an optional `۞` plus a no-break space, then the words separated by ordinary spaces, then a no-break space and the ayah number in Arabic-Indic digits.
- The data stores combining marks in non-normalised order (e.g. shadda before kasra). The build compares Arabic text by canonical equivalence, so text typed in an editor that normalises Unicode still matches.

## Licence: unconfirmed

No licence for `hafsData_v18.csv` itself was found. KFGQPC's font licence ([ScanCode entry](https://scancode-licensedb.aboutcode.org/kfgqpc-uthmanic-script-hafs.LICENSE)) bars reproduction and modification without the Complex's written approval. Confirm redistribution terms with KFGQPC before publishing the template outside the project.
