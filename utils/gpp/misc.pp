
#mode standard tex


\define{\QUESTION{no}{no_in_part}{part}{text}}{
::: {custom-style="QUESTION"}
Question No. \no (\no_in_part/\part)
:::

::: {custom-style="QUESTION-DETAIL"}
\text
:::
}

\define{\ANSWER}{
::: {custom-style="ANSWER"}
Answer
:::
}

\define{\SC{term}}{[\term]{.smallcaps}}

\mode{standard}{cpp}
/* ======================
        Translation related
   ======================*/
#mode standard tex

\define{\trans{arabic}{english}}{

\ifndef{FINAL}
::: {custom-style="Arabic Source" dir="rtl"}
\arabic
:::

::: {custom-style="English Target"}
\english
:::
\else
\english
\endif
}

\define{\note{text}}{[NOTE: \text]{custom-style="Highlight C1"}}

\define{\c1{text}}{[\text]{custom-style="Highlight C1"}}
\define{\c2{text}}{[\text]{custom-style="Highlight C2"}}
\define{\c3{text}}{[\text]{custom-style="Highlight C3"}}
\define{\c4{text}}{[\text]{custom-style="Highlight C4"}}
\define{\warn{text}}{[\text]{custom-style="Highlight Warn"}}

\define{\trans{arabic}{english}}{

\ifndef{FINAL}
::: {custom-style="Arabic Source" lang="ar" dir="rtl"}
\arabic
:::

::: {custom-style="English Target"}
\english
:::
\else
\english
\endif
}

\mode{standard}{default}
