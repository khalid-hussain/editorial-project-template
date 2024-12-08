compile-macros:
	cat honorifics.cpp parastyles.cpp > _macros.txt

macros-english:
	gpp tests/testContent.md -DHONORIFICS_ENG > tests/resultEnglish.md

macros-arabic:
	gpp tests/testContent.md > tests/resultArabic.md

macros: compile-macros macros-english macros-arabic