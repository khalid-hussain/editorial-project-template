<!-- expect: warning@5: custom style "Basmalah" is not defined in template.docx -->
<!-- expect: error@9: unknown custom style "quran-arabc" -->
<!-- A style the template defines (left-ragged) passes silently. -->

::: {custom-style="Basmalah"}
بسم الله الرحمن الرحيم
:::

::: {custom-style="quran-arabc"}
Typo of a template style.
:::

::: {custom-style="left-ragged"}
Translator
:::
