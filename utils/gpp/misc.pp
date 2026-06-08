
#mode standard tex

\ifdef{IBN}
\define{BIN}{ibn}
\define{BINT}{bint}
\else
\define{BIN}{b.}
\define{BINT}{bt.}
\endif

\define{\SC{term}}{[\term]{.smallcaps}}

\mode{standard}{default}

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