#!/usr/bin/perl
use strict;
use warnings;
use YAML::Syck;
use XML::LibXML;
use File::Find;
use File::Basename qw/fileparse/;
use Path::Class;
use Encode;
use utf8;

our $c = YAML::Syck::LoadFile('data.yaml');
find(\&process, $c->{top_dir});

sub process(){
  my $file = $File::Find::name;

  ## htmlファイルのみ処理を行う
  my ($base, $dir, $ext) = fileparse($file, '.html');
  return unless $ext eq ".html";

  ## ファイル内容を変数に一気に入れ込む
  open my $fh, "<", $file or die "cannot open: $!";
  my $all_lines;
  {
    local $/ = undef;
    $all_lines = readline $fh;
  }
  close $fh;

  ## ファイル毎のディレクトリを作成
  my $chdir = $File::Find::dir;
  $chdir =~ s/$c->{exic_dir}//;
  my $write_path = $c->{write_dir} . $chdir;
  mkpath $write_path or warn $! unless -d $write_path;

  ## htmlの文字コードを取得
  my $enc = getCharaSet($all_lines);

  ## パス変換して出力
  open my $ofh, ">", file($write_path, $_) or die $!;
  my $data = fixlinx( $all_lines, $c->{prefix}, $File::Find::dir);
  ### charsetによってdecodeを変更する
  if(length($enc) > 0){
    print $ofh Encode::encode_utf8(decode($enc, $data));
  }else{
    print $ofh $data;
  }
  close $ofh;
}

sub getCharaSet {
    my $html = shift;
    my $charset = "";

    local $SIG{__WARN__} = sub { }; # to keep LibXML quiet
    my $parser = XML::LibXML->new(
    suppress_errors   => 1,
    suppress_warnings => 1,
    recover           => 2,
    );
    my $dom = $parser->parse_html_string($html);
    for my $node ( $dom->getElementsByTagName('meta') ) {
        next unless my $content = $node->getAttribute('content');
        if($content =~ /.*charset=(.+)/){
            $charset = $1;
        }
    }

    return $charset;
}

sub fixlinx {
    my ( $html, $base, $cwd_dir ) = @_;
    local $SIG{__WARN__} = sub { }; # to keep LibXML quiet
    my $parser = XML::LibXML->new(
        suppress_errors   => 1,
        suppress_warnings => 1,
        recover           => 2,
    );
    my $dom = $parser->parse_html_string($html);
    for my $node ( $dom->getElementsByTagName('a') ) {
        next unless my $href = $node->getAttribute('href');
        $node->setAttribute( 'href' => dirReplace( $href, $base, $cwd_dir ) );
      }
    for my $node ( $dom->getElementsByTagName('img') ) {
        next unless my $src = $node->getAttribute('src');
        $node->setAttribute( 'src' => dirReplace( $src, $base, $cwd_dir ) );
      }
    for my $node ( $dom->getElementsByTagName('script') ) {
      next unless my $src = $node->getAttribute('src');
      $node->setAttribute( 'src' => dirReplace( $src, $base, $cwd_dir ) );
    }
    for my $node ( $dom->getElementsByTagName('link') ) {
      next unless my $href = $node->getAttribute('href');
      $node->setAttribute( 'href' => dirReplace( $href, $base, $cwd_dir ) );
    }
    return $dom->toStringHTML;
}

sub dirReplace {
  my ( $src, $base, $cwd_dir ) = @_;

  my $path = $src;
  if( $path =~ /^\#/ ){
      # 変換しない
  }elsif( $path =~ /^javascript:/ || $path =~ /^http[s]?:/ ){
      # 変換しない
  }elsif( $path =~ /^\// ){
      $path = file($base, $path);
  }else{
    my $tmp_dir = $cwd_dir;
    $tmp_dir =~ s/$c->{top_dir}//;
    $tmp_dir =~ s/pc//;
    $path = pathJoin($base.$tmp_dir."/".$path);
  }

  return $path;
}

sub pathJoin(){
    my ($top, $second, $third) = @_;

    my @list= split /\//, $top;
    push(@list, split(/\//, $second));
    push(@list, split(/\//, $third));

    my @path;
    foreach my $name(@list){
        next if $name =~ /^$/;
        next if $name =~ /^\.$/;
        if($name =~ /^\.\.$/){
            pop @path;
            next;
        }
        push @path, $name;
    }

    return '/'. join('/', @path);
}
