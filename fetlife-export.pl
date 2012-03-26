#!/usr/bin/perl -w

use strict;
use WWW::Mechanize;
use Term::ReadKey;
use LWP::Simple qw/getstore/;
use File::Basename;
use HTML::TreeBuilder;

$|++;

my $mech = new WWW::Mechanize;
my $username = shift or &usage;
my $dir = shift || ".";
print "Password: ";
ReadMode('noecho');
my $password = ReadLine 0;
ReadMode('normal');
chomp $password;
print "\n";

mkdir "$dir/fetlife";

&login($username, $password);
my $id = &getId();
print "userID: $id\n";

&downloadPics();
&downloadWriting();

sub downloadWriting {
  mkdir "$dir/fetlife/posts";

  print "Loading posts: .";
  $mech->get("https://fetlife.com/users/$id/posts");
  my @links = $mech->find_all_links( url_regex => qr{/users/$id/posts/\d+$} );
  while (my $next = $mech->find_link( url_regex => qr{/posts\?page=(\d)}, text_regex => qr/Next/ )) {
    print ".";
    $mech->get($next);
    push @links, $mech->find_all_links( url_regex => qr{/users/$id/posts/\d+$} );
  }

  my $num = @links;
  my $s = &s($num);
  my $i = 1;
  print " $num posts$s found.\n";
  return unless $num;
  foreach my $page (@links) {
    print "$i/$num\r";

    &getPost($page);

    $i++;
  }
}

sub getPost {
  my $page = shift;
  my $tree;
  $mech->get($page);
  $tree = HTML::TreeBuilder->new();
  $tree->ignore_unknown(0);
  $tree->parse($mech->content());
  my $name = basename($page->url());
  ### return if -f "$dir/fetlife/posts/$name.data";
  open(DATA, "> $dir/fetlife/posts/$name.txt") or die "Can't write $name.txt: $!";
  print DATA $tree->look_down( class => 'h2 bottom' )->as_text(), "\n\n";
  foreach my $p ($tree->look_down( class => 'content mls60 may_contain_youtubes' )->look_down(_tag => "p")) {
    print DATA $p->as_text(), "\n\n";
  }

  print DATA "\n\nComments:\n";

  my @comments = $tree->look_down( class => 'comment clearfix' );
  pop @comments; # ignore the new comment line
  # print "comments: ", scalar @comments, "\n";
  foreach my $comment (@comments) {
    # print "-----\n", $comment->dump();
    print DATA $comment->look_down( class => 'nickname' )->as_text();
    print DATA " - ", $comment->look_down( class => "time_ago" )->attr('datetime'), "\n";
    print DATA $comment->look_down( class => qr/content/ )->as_text();
    print DATA "\n\n";
  }

  close DATA;
  $tree->delete();
}

sub downloadPics {
  mkdir "$dir/fetlife/pics";

  print "Loading pictures: .";
  $mech->get("https://fetlife.com/users/$id/pictures");
  my @links = $mech->find_all_links( url_regex => qr{/users/$id/pictures/\d+$} );
  while (my $next = $mech->find_link( url_regex => qr{/pictures\?page=(\d)}, text_regex => qr/Next/ )) {
    print ".";
    $mech->get($next);
    push @links, $mech->find_all_links( url_regex => qr{/users/$id/pictures/\d+$} );
  }

  my $num = @links;
  my $s = &s($num);
  my $i = 1;
  print " $num picture$s found.\n";
  return unless $num;
  foreach my $page (@links) {
    print "$i/$num\r";

    &getImage($page);

    $i++;
  }
}

sub getImage {
  my $page = shift;
  my $tree;
  $mech->get($page);
  my $image = $mech->find_image( url_regex => qr{flpics.*_720\.jpg} );
  my $name = basename($image->url());
  return if -f "$dir/fetlife/pics/$name.data";
  getstore($image->url(), "$dir/fetlife/pics/$name");
  $tree = HTML::TreeBuilder->new();
  $tree->ignore_unknown(0);
  $tree->parse($mech->content());
  open(DATA, "> $dir/fetlife/pics/$name.data") or die "Can't write $name.data: $!";
  print DATA "Caption: ";
  my $caption = $tree->look_down( class => "caption" );
  if ($caption) {
    print DATA $caption->as_text;
  } else {
    print DATA "N/A";
  }

  print DATA "\n\nComments:\n";

  my @comments = $tree->look_down( class => 'comment clearfix' );
  pop @comments; # ignore the new comment line
  # print "comments: ", scalar @comments, "\n";
  foreach my $comment (@comments) {
    # print "-----\n", $comment->dump();
    print DATA $comment->look_down( class => 'nickname' )->as_text();
    print DATA " - ", $comment->look_down( class => "time_ago" )->attr('datetime'), "\n";
    print DATA $comment->look_down( class => qr/content/ )->as_text();
    print DATA "\n\n";
  }

  close DATA;
  $tree->delete();
}

sub getId {
  my $link = $mech->find_link( text_regex => qr/View Your Profile/i );
  die "Failed to find profile link!" unless $link;
  if ($link->url() =~ m{/(\d+)$}) {
    return $1;
  } else {
    die "Failed to get user ID out of profile link: " . $link->url();
  }
}

sub login {
  my ($username, $password) = @_;

  $mech->get( "https://fetlife.com/login" );
  $mech->form_with_fields( qw/nickname_or_email password/ );
  $mech->field( 'nickname_or_email' => $username );
  $mech->field( 'password' => $password );
  my $res = $mech->submit();
  die "Login failed!" unless $res->is_success;
}

sub usage {
  print "$0 <username> [<directory>]\n";
  exit 1;
}

sub s {
  my $num = shift;
  return $num == 1 ? "" : "s";
}
