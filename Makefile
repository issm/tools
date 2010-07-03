PROVE = prove
PERL = perl
TESTS = */test.pl

test:
	$(PROVE) $(TESTS)
