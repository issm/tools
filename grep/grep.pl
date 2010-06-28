#!/usr/bin/env perl

# -*- coding: utf-8-unix; -*-

#
# grep.pl -{re1} -{re2} ... {file1} {file2} ...
# find ... | grep.pl -{re1} -{re2} ...
#

#
#  1: bold
#  2: underline
#  3: reverse fg and bg?
#  4: same as 2?
#  5: same as 3?
# 30: fg darkgray
# 31: fg red
# 32: fg green
# 33: fg yellow
# 34: fg blue
# 35: fg purple
# 36: fg lightblue
# 37: fg white?
# 40: fg darkgray
# 41: bg red
# 42: bg green
# 43: bg yellow
# 44: bg blue
# 45: bg purple
# 46: bg lightblue
# 47: bg white?
#
# available like '1;2;31': bold and underline and red-fg.
#

use strict;
use warnings;
use utf8;
use Encode;
use Data::Dumper;
use File::Basename qw();
use Getopt::Long qw();

my $DEBUG = 0;
my $GREP_COMMON = '/usr/bin/grep --color=never';

my @COLOR_MATCHED    = map "1;2;4;" . $_, qw/31 32 34 35 36 37 38/;
my $COLOR_FILENAME   = '1;4;37';
my $COLOR_LINENUMBER = '1;33';

sub _de {
    return decode('utf-8', $_);
}

sub _max {
    return (sort {int($b) <=> int($a)} @_)[0];
}

sub _uniq {
    my $list = \@_;
    my $_h = {};
    return grep {!$_h->{$_}++} @$list;
}

sub _perlre2grepre {
    my @re_table = (
        [qr/\\d/ => '[0-9]'         ],
        [qr/\\D/ => '[^0-9]/'       ],
        [qr/\\w/ => '[0-9a-zA-Z_]'  ],
        [qr/\\W/ => '[^0-9a-zA-Z_]' ],
        [qr/\\s/ => '[ ]'           ],
        [qr/\\S/ => '[^ ]'          ],
    );
    my $translate = sub {
        my ($str) = @_;
        map {$str =~ s/$_->[0]/$_->[1]/g} @re_table;
        $str;
    };

    print "\n**** Regexp translation ****\n"  if $DEBUG;

    return map {
        my $_re_before = $_;
        my $_re_after = $translate->($_re_before);

        print "$_re_before => $_re_after\n"  if $DEBUG;
        $_re_after;
    } @_;
}

sub main {
    my @args = @_;

    my @re;
    Getopt::Long::GetOptionsFromArray(\@args,
        'debug!' => \$DEBUG,
        'regexp=s' => \@re,
    );

    # 正規表現
    unless (@re > 0) {
        print(<<"        EOL");
Usage: $0 [Options] [filename1 [filename2 [..]]]

Options:
  -regexp regexp:
     正規表現を指定する．

  -debug :
     デバッグモードをオンにする．
        EOL
        return 0;
    }

    # 対象ファイル
    my @target = @args;
    unless (@target > 0) {
        # 引数として対象ファイルがない場合，標準入力からの入力を試みる
        chomp(@target = <STDIN>);
    }

    # grepコマンド
    my $_i = 0;
    my @grep = map {
        $_i++
            ? "$GREP_COMMON -E   '$_'"          # $_i > 0
            : "$GREP_COMMON -HnE '$_' @target"  # $_i == 0
        ;
    } _perlre2grepre(@re);


    @re = map {qr/$_/} @re;
    my $cmd = join '|', @grep;

    if ($DEBUG) {
        print "\n**** Command ****\n";
        print $cmd, "\n";
    }

    my $re_line = qr/^([^:]+):(\d+):(.*)/;
    my @result = grep {
        # 頭の「{ファイル名}:{行番号}:」にマッチしてしまっていないか
        my $line = ($_ =~ $re_line)[2];
        my @_m = grep {$line =~ m/$_/} @re;
        @_m == @re;
    } `$cmd`;

    if ($DEBUG) {
        print "\n**** Results ****\n";
    }

    # 結果がなければここで終了
    return 0 unless (@result > 0);

    # 対象ファイル名の最大文字数
    @target = _uniq(map {(m/$re_line/)[0]} @result);
    my $max_name_length = _max(map {length $_} @target);

    # 対象ファイルにおける最大行数
    my $max_lines = _max(map {
        my ($lines) = `wc -l $_` =~ m/(\d+)/;
        int $lines;
    } @target);

    # 出力フォーマット
    (my $fmt_line = sprintf(
        '[0;%sm %%%dd [m : %%s',
        $COLOR_LINENUMBER,  # 行番号の色
        length($max_lines), # 桁数
    )) =~ s/ //g;

    my $file_prev = '';
    for my $l (@result) {
        my ($file, $num, $line) = ($l =~ $re_line);

        # ファイル名の出力
        unless ($file_prev eq $file) {
            printf(
                "\n[%sm${file}[m\n\n",
                $COLOR_FILENAME,
            );
        }
        $file_prev = $file;

        for (
             my ($i, $cl, $_re) = (0, $COLOR_MATCHED[0]);
             defined ($_re = $re[$i]);
             $i++, $cl = $COLOR_MATCHED[$i]
        ) {
            # エスケープシーケンスの特性上，2つめ以降の正規表現が 「\d」「m」のときにバグる
            $line =~ s/($_re)/[${cl}m$1[m/g;
        }

        $l = sprintf $fmt_line, $num, $line;
        print $l, "\n";
    }

    return 0;
}

if (File::Basename::basename(__FILE__) eq File::Basename::basename($0)) {
    my $ret = main(@ARGV);
    exit $ret;
}
1;
__END__
