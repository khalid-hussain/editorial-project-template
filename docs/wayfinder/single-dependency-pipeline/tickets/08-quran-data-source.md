---
id: 08
title: Qur'an data source
labels: [wayfinder:grilling]
status: closed
assignee: khawarizmus
blocked_by: [01]
---

## Question

In what form does the Qur'an data ship? Keep `hafsData_v18.csv` and parse it at build time, or convert once to a Lua/JSON table committed to the repo? Where does the surah-name transliteration table (currently in `quran-loc.ipynb` and the generated `\SURAH_NAME`) live? Confirm the KFGQPC data's licence allows redistribution in the template.

## Resolution

1. **Data format:** ship `utils/quran/hafsData_v18.csv` **unmodified** and parse it at build time in pure Lua (about 15–30 ms per [Pandoc capability baseline](01-pandoc-capability-baseline.md)). No conversion and no column trimming. That keeps us clear of "modification" concerns and makes updating a matter of replacing the file. The parser must handle quoted fields and CRLF line endings.
2. **Surah names:** move the project's transliterations out of `quran-loc.ipynb` into `utils/quran/surah-names.csv` (`number,name`, 114 rows), which non-developers can edit. Arabic names, if ever needed, come from the main CSV.
3. **Provenance:** add `utils/quran/SOURCE.md` recording where the CSV and fonts came from, their versions, and that redistribution terms are unconfirmed. KFGQPC's font licence bars reproduction and modification without written approval, and no data licence for `hafsData_v18.csv` was found ([ScanCode licence entry](https://scancode-licensedb.aboutcode.org/kfgqpc-uthmanic-script-hafs.LICENSE), [ibnhazm/KFGQPC](https://github.com/ibnhazm/KFGQPC)).
4. **Fixed location:** data paths stay hardcoded under `utils/quran/`. Add a config key when a book needs another riwayah (e.g. Warsh).
5. **Remove Python:** both notebooks and `utils/python/` are deleted once the port is done.
