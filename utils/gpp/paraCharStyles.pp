
#mode standard tex

\ifndef{LONG_SURAH_REF}
\define{\surahref{surah}{ayahValue}}{(Q\surah:\ayahValue)}
\else
\define{\surahref{surah}{ayahValue}}{(\SURAH_NAME{\surah}, Q\surah:\ayahValue)}
\endif

\ifdef{EPUB}
\define{quran_ar}{quran-arabic}
\define{quran_trans}{quran-trans}

\define{hadith_ar}{hadith-arabic}
\define{hadith_trans}{hadith-trans}

\define{arabic_text}{arabic-text}
\define{arabic_trans}{arabic-trans}

\else

\define{quran_ar}{quran-arabic}
\define{quran_trans}{quran-trans}

\define{hadith_ar}{hadith-arabic}
\define{hadith_trans}{hadith-trans}

\define{arabic_text}{arabic-text}
\define{arabic_trans}{arabic-trans}
\endif

\mode{standard}{default}
