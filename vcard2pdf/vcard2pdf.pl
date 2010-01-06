#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/lib";

use Text::vCard::Addressbook;
use PDF::API2::Wrapper;
use Encode;
use Data::Dumper;


#### 位置設定 ここから ####

# 宛先郵便番号枠の位置
my $A = 8;
my $B = 6;
my $C = 12;
my $D = [44, 51, 58, 65.5, 72.5, 79.5, 86.5];  # 左から順に

# 住所の位置
my $E = 20;
my $F = 60;

# 宛名の位置
my $G = 20;
my $H = 75;

# 差出人郵便番号枠の位置（今のところ未使用）
my $I = 6;
my $J = 3.8;
my $K = 122.5;
my $L = [5.5, 9.5, 13.5, 18.5, 22.5, 26.5, 30.5];  # 左から順に

#### 位置設定 ここまで ####


sub usage {
    print << "...";
Usage:
  vcard2pdf.pl <source_file>
...
    exit;
}


sub d {
    Dumper @_;
}

sub de { decode('utf-8', $_[0]); }
sub en { encode('utf-8', $_[0]); }


sub data_from_vcard {
    my $v = shift;
    my $data = {};

    # 名前
    my $name = $v->get('N')->[0];
    if ($name->{family}) {
        $data->{name1} = de $name->family;
        $data->{name2} = de $name->given;
    }

    # 所属
    my $org = $v->get('ORG');
    if (defined $org) {
        $data->{org} = de $org->[0]->name;
    }


    # 住所
    my $address = $v->get('ADR')->[0] || '';
    $data->{post_code} = de($address->post_code || '');
    my $address_tmp =
        de $address->region . $address->city . $address->street;
    $data->{address} = [split /\\n/, $address_tmp];


    sub get_item_value {
        my ($v, $name) = @_;

        my $items = [
            map {
                {
                    name =>
                        $v->get_group($_, 'X-ABLabel')->[0],
                    value =>
                        $v->get_group($_, 'X-ABRELATEDNAMES')->[0],
                }
            }
            map { 'item' . $_; } 1 .. 10
        ];

        [
            map { de $_->{value}->value; }
            grep {
                my $n = $_->{name};
                defined $n  &&  de($n->value) eq $name;
            }
            @$items
        ];
    }

    # 連名 (arrayref)
    $data->{joint} = get_item_value($v, '連名');
    $data->{joint} = join ' ', @{$data->{joint}};
    $data->{joint} = [split /\s+/, $data->{joint}];

    # 肩書付加？ (1 or 0)
    $data->{with_position} =
        int(get_item_value($v, '肩書付加？')->[0] || 0);

    $data;
}


sub pdf_from_data {
    my $data     = shift;
    my $pdf_file = shift;

    my $pdf = PDF::API2::Wrapper->new({
        measure     => 'mm',
        dpi         => 300,
        width       => 100,
        height      => 148,
        ttfont      => "$FindBin::Bin/font/ipag.otf",
        fontsize    => '10pt',
        strokecolor => '#000000',
        fillcolor   => '#000000',
    })->init;


    for my $dest (@$data) {
        $pdf->page if $dest != $data->[0];

        # 郵便番号
        (my $post_code = $dest->{post_code}) =~ s/-//g;
        $post_code = [grep /[0-9a-zA-Z０-９]/, split '', $post_code];

        for (my $i = 0; $i < 7; $i++) {
            $post_code->[$i] =~ tr/0-9a-zA-Z/０-９ａ-ｚＡ-Ｚ/;  # 半角 → 全角
            $pdf->text(
                x    => $D->[$i],
                y    => $C,
                text => $post_code->[$i],
                size => ($B - 1),
            );
        }

        # 住所
        my $address = join "\n", @{$dest->{address}};
        $address =~ tr/0-9a-zA-Z/０-９ａ-ｚＡ-Ｚ/;  # 半角 → 全角
        $pdf->text(
            x    => $E,
            y    => $F,
            text => $address,
            line_height => '150%',
        );

        # 宛名
        my %opts_name = (
            x    => $G,
            y    => $H,
            size => '12pt',
            line_height => '133%',
        );

        if (defined $dest->{name1}) {
            # 組織名もある
            if (defined $dest->{org}  &&  $dest->{with_position}) {
                $pdf->text(
                    %opts_name,
                    text => $dest->{org},
                    size => '10pt',
                );
                $opts_name{y} += 6;
            }

            # 個人名・連名
            my $title = ' 様';
            my $len_name1 = length $dest->{name1}; # 姓の文字数
            my $spc_name1 = '　' x $len_name1;     # 姓の文字数分だけ全角スペース
            my @name_out = (
                $dest->{name1} . ' ' . $dest->{name2} . $title
            );
            for (@{$dest->{joint}}) {
                push(
                    @name_out,
                    $spc_name1 . ' ' . $_ . $title
                );
            }

            $pdf->text(
                %opts_name,
                text => join("\n", @name_out),
            );
        }
        elsif (defined $dest->{org}) {
            # 組織名
            $pdf->text(
                %opts_name,
                text => $dest->{org} . ' 御中',
                size => '11pt',
            );
        }

    }

    $pdf->save(file => $pdf_file);
    1;
}



sub main {
    my $source_file = $ARGV[0];
    my $pdf_file    = $ARGV[1] || "$FindBin::Bin/addresses.pdf";

    usage  unless defined $source_file;

    my $ab = Text::vCard::Addressbook->new({
        source_file => $source_file,
    });

    my $data = [];

    foreach my $v ($ab->vcards) {
        push(
            @$data,
            data_from_vcard($v),
        );
    }

    pdf_from_data $data, $pdf_file;
}

main;



__END__
