
#mode standard tex

\ifndef{LONG_SURAH_REF}
\define{\surahref{surah}{ayahValue}}{(Q\surah:\ayahValue)}
\else
\define{\surahref{surah}{ayahValue}}{(\SURAH_NAME{\surah}, Q\surah:\ayahValue)}
\endif

\define{quran_ar}{quran-arabic}
\define{quran_trans}{quran-trans}

\define{hadith_ar}{hadith-arabic}
\define{hadith_trans}{hadith-trans}

\define{arabic_text}{arabic-text}
\define{arabic_trans}{arabic-trans}

\mode{standard}{default}
