<!-- expect: error@9: surah 115 does not exist -->
<!-- expect: error@12: has 7 ayat; there is no ayah 8 -->
<!-- expect: error@15: the range runs backwards -->
<!-- expect: error@18: a range must stay inside one surah -->
<!-- expect: error@21: suffix-50 asks for 50 words -->
<!-- expect: error@24: did you mean "suffix" -->
<!-- expect: error@27: empty reference -->

::: {.ayah ref="115:1"}
:::

::: {.ayah ref="1:8"}
:::

::: {.ayah ref="2:5-3"}
:::

::: {.ayah ref="1:7-2:1"}
:::

::: {.ayah ref="21:107|suffix-50"}
:::

::: {.ayah ref="21:107|sufix-5"}
:::

::: {.ayah ref="2:1-3;"}
:::
