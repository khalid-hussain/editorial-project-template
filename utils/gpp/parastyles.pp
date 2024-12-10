
#mode standard tex

\ifndef{LONG_SURAH_REF}
\define{\surahref{surah}{ayahValue}}{(Q\surah:\ayahValue)}
\else
\define{\surahref{surah}{ayahValue}}{(\SURAH_NAME{\surah}, Q\surah:\ayahValue)}
\endif

\mode{standard}{default}
