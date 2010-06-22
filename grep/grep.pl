#!/usr/bin/env perl

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


my $DEBUG = 1;
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
    return grep !$_h->{$_}++, @$list;
    #return grep $_h->{$_}++ ? 0 : 1, @$list;
}


sub _re_4_shell {
    my $re = {
        enslash => qr/[{}]/,
        d       => qr/\\d/,
        D       => qr/\\D/,
        w       => qr/\\w/,
        W       => qr/\\W/,
        s       => qr/\\s/,
        S       => qr/\\S/,
    };

    print "\n**** Regexp translation ****\n"  if $DEBUG;

    return map {
        my $_re_before = $_;
        my $_re_after  = $_;
        $_re_after =~ s/$re->{d}/[0-9]/g;
        $_re_after =~ s/$re->{D}/[^0-9]/g;
        $_re_after =~ s/$re->{w}/[0-9a-zA-Z_]/g;
        $_re_after =~ s/$re->{W}/[^0-9a-zA-Z_]/g;
        $_re_after =~ s/$re->{s}/[ ]/g;
        $_re_after =~ s/$re->{S}/[^ ]/g;

        print "$_re_before => $_re_after\n"  if $DEBUG;
        $_re_after;
    } @_;
}



sub main {
    my @args = @_;
    my $re_re = qr/^-(.+)/;

    # 正規表現
    my @re = map { (/$re_re/)[0]; } grep $_ =~ $re_re, @args;
    # 対象ファイル
    my @target = grep $_ !~ $re_re, @args;
    unless (@target) {
        # 引数として対象ファイルがない場合，標準入力からの入力を試みる
        @target = map { chomp; $_; } <STDIN>;
    }


    # grepコマンド
    my $_i = 0;
    my @grep = map {
        $_i++
            ? "$GREP_COMMON -E   '$_'"          # $_i > 0
            : "$GREP_COMMON -HnE '$_' @target"  # $_i == 0
        ;
    } _re_4_shell @re;


    @re = map qr/$_/, @re;
    my $cmd = join '|', @grep;

    if ($DEBUG) {
        print "\n**** Command ****\n";
        print $cmd, "\n";
    }

    my $re_line = qr/^([^:]+):(\d+):(.*)$/;
    my @result = grep {
        # 頭の「{ファイル名}:{行番号}:」にマッチしてしまっていないか
        my $line = ($_ =~ $re_line)[2];
        my @_m = grep $line =~ /$_/, @re;
        $#_m == $#re ? 1 : 0;
    } `$cmd`;

    if ($DEBUG) {
        print "\n**** Results ****\n";
    }

    # 結果がなければここで終了
    return  unless defined $result[0];

    # 対象ファイル名の最大文字数
    @target = _uniq map { (/$re_line/)[0]; } @result;
    my $max_name_length = _max map length $_, @target;

    # 対象ファイルにおける最大行数
    my $max_lines = _max map {
        my ($lines) = `wc -l $_` =~ /(\d+)/;
        int $lines;
    } @target;

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
        if ($file_prev ne $file) {
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

    return;
}


main(@ARGV);
__END__
