#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin qw();

use lib qq($FindBin::RealBin);

require_ok 'grep.pl';

# max
is(_max(1, 2, 3), 3, '_max()');

# uniq
is_deeply([_uniq(1, 1, 2, 3)], [1, 2, 3], '_uniq()');
is_deeply([_uniq()], [], '_uniq(zero argument)');

# perlre2grepre
foreach my $d_and_e (
        [q/\d/ => '[0-9]'         ],
        [q/\D/ => '[^0-9]/'       ],
        [q/\w/ => '[0-9a-zA-Z_]'  ],
        [q/\W/ => '[^0-9a-zA-Z_]' ],
        [q/\s/ => '[ ]'           ],
        [q/\S/ => '[^ ]'          ],
                    ) {
    my ($d, $e) = @$d_and_e;
    is_deeply([_perlre2grepre($d)], [$e], '_perlre2grepre');
}

done_testing();
