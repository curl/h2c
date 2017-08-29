#!/usr/bin/perl

use MIME::Base64;

sub usage {
    print "h2c.pl [-d][-h][-i][-n][-s][-v] < file \n",
        " -a   Allow curl's default headers\n",
        " -d   Output man page HTML links after command line\n",
        " -h   Show short help\n",
        " -i   Ignore HTTP version\n",
        " -n   Output notes after command line\n",
        " -s   Use short command line options\n",
        " -v   Add a verbose option to the command line";
    exit;
}

sub manpage {
    my ($p, $n, $desc) = @_;
    if(!$n) {
        $n = $p;
    }
    return sprintf("%s;%s;$desc", $p, $n);
}

my $usesamehttpversion = 1;
my $disableheadersnotseen = 1;
my $shellcompatible = 1; # may not been windows command prompt compat
my $uselongoptions = 1; # instead of short

while($ARGV[0]) {
    if(($ARGV[0] eq "-h") || ($ARGV[0] eq "--help")) {
        usage();
    }
    elsif($ARGV[0] eq "-a") {
        $disableheadersnotseen = 0;
        shift @ARGV;
    }
    elsif($ARGV[0] eq "-d") {
        $usedocs = 1;
        shift @ARGV;
    }
    elsif($ARGV[0] eq "-i") {
        $usesamehttpversion = 0;
        shift @ARGV;
    }
    elsif($ARGV[0] eq "-n") {
        $usenotes = 1;
        shift @ARGV;
    }
    elsif($ARGV[0] eq "-s") {
        $uselongoptions = 0;
        shift @ARGV;
    }
    elsif($ARGV[0] eq "-v") {
        $useverbose = 1;
        shift @ARGV;
    }
    else {
        usage();
    }
}


my $state; # 0 is request-line, 1-headers, 2-body
my $line = 1;
while(<STDIN>) {
    my $l = $_;
    # discard CRs completely
    $l =~ s///g;
    if(!$state) {
        chomp $l;
        if($l =~ /([^ ]*) +(.*) +(HTTP\/.*)/) {
            $method = $1;
            $path = $2;
            $http = $3;
        }
        else {
            $error="bad request-line";
            last;
        }
        $state++;
    }
    elsif(1 == $state) {
        chomp $l;
        if($l =~ /([^:]*): *(.*)/) {
            $header{lc($1)}=$2;
        }
        elsif(length($l)<2) {
            # body time
            $state++;
        }
        else {
            $error="illegal HTTP header on line $line";
            last;
        }
    }
    elsif(2 == $state) {
        push @body, $l;
    }
    $line++;
}

if(!$header{'host'}) {
    $error = "No Host: header makes it impossible to tell URL\n";
}

 error:
if($error) {
    print "Error: $error\n";
    exit;
}

if($uselongoptions) {
    $opt_data = "--data";
    $opt_request = "--request";
    $opt_head = "--head";
    $opt_header = "--header";
    $opt_user_agent = "--user-agent";
    $opt_cookie = "--cookie";
    $opt_verbose = "--verbose";
    $opt_form = "--form";
    $opt_user = "--user";
}
else {
    $opt_data = "-d";
    $opt_request = "-X";
    $opt_head = "-I";
    $opt_header = "-H";
    $opt_user_agent = "-A";
    $opt_cookie = "-b";
    $opt_verbose = "-v";
    $opt_form = "-F";
    $opt_user = "-u";
}

my $httpver="";
my $disabledheaders="";
my $addedheaders="";

if($header{"content-type"} =~ /^multipart\/form-data;/) {
    # multipart formpost, this is special
    my $type = $header{"content-type"};
    my $boundary = $type;
    $boundary =~ s/.*boundary=(.*)/$1/;
    my $inbound = $body[0];
    chomp $inbound;
    # a body MUST start with dash-dash-boundary
    if("--$boundary" ne $inbound) {
        $error = "unexpected multipart format";
        goto error;
    }
    my $bline=1;

    my %fheader;
    my $fstate = 0;
    my @fbody;
    while($body[$bline]) {
        my $l = $body[$bline];
        if(0 == $fstate) {
            # headers
            chomp $l;
            if($l =~ /([^:]*): *(.*)/) {
                $fheader{lc($1)}=$2;
            }
            elsif(length($l)<2) {
                # body time
                $fstate++;
            }
        }
        elsif($fstate) {
            if($l =~ /^--$boundary/) {
                # end of this part
                my $cd = $fheader{'content-disposition'};
                if(!$cd) {
                    $error = "multi-part without Content-Disposition: header!";
                    goto error;
                }
                # Content-Disposition: form-data; name="name"
                # Content-Disposition: form-data; name="file"; filename="README.md"
                if($cd =~ /^form-data; name=([^;]*)[;]? *(.*)/i) {
                    my ($n, $f)=($1, $2);
                    # name is with or without quotes
                    $n =~ s/\"//g;
                    if($f =~ /^filename=(.*)/) {
                        # filename is with or without quotes
                        $f = $1;
                        $f =~ s/\"//g;
                    }
                    if(!$multipart) {
                        push @docs, manpage("-F", $opt_form, "send a multipart formpost");
                    }
                    if(!$f) {
                        my $fbody = join("", @fbody);
                        $fbody =~ s/[ \n\r]+\z//g;
                        $multipart .= "$opt_form $n=$fbody ";
                    }
                    else {
                        # file name was present
                        $multipart .= "$opt_form $n=\@$f ";
                    }
                }
                $fstate = 0;
                %fheader = 0;
                $bline++;
                next;
            }
            push @fbody, $l;
        }
        $bline++;
    }
    if($body[$bline-1] !~ /^--$boundary--/) {
        print STDERR "bad last line?";
    }

    $header{"content-type"} = ""; # blank it
    $do_multipart = 1;

}
elsif(length(join("", @body))) {
    # TODO: escape the body
    my $esc = join("", @body);
    chomp $esc; # trim the final newline
    if($shellcompatible) {
        $esc =~ s/\n/ /g; # turn newlines into space!
        $esc =~ s/\"/\\"/g; # escape double quotes
        if(!$unixescaped) {
            push @notes, "uses quotes suitable for *nix command lines";
            $unixescaped++;
        }
    }
    $usebody= sprintf("--data-binary \"%s\" ", $esc);
    push @docs, manpage("--data-binary", "", "send this string as a body with POST");
}
if(uc($method) eq "HEAD") {
    $usemethod = "$opt_head ";
    push @docs, manpage("-I", $opt_head, "send a HEAD request");
}
elsif(uc($method) eq "POST") {
    if(!$usebody && !$do_multipart) {
        $usebody= sprintf("$opt_data \"\" ");
        push @docs, manpage("-d", $opt_data, "send this string as a body with POST");
    }
}
elsif(uc($method) eq "PUT") {
    if(!$usebody) {
        $usebody= sprintf("$opt_data \"\"");
        push @docs, manpage("-d", $opt_data, "send this string as a body with POST");
    }
    $usebody .= "$opt_request PUT ";
    push @docs, manpage("-X", $opt_request, "replace the request method with this string");
}
elsif(uc($method) ne "GET") {
    $error = "unsupported HTTP method $method";
    goto error;
}

if($usebody) {
    # body is set, handle the content-type
    if(!$header{"content-type"}) {
        $disabledheaders .= "$opt_header Content-Type: ";
    }
    elsif(lc($header{"content-type"}) ne
          "application/x-www-form-urlencoded") {
        # custom
        $set_contenttype = 1;
        $addedheaders .= sprintf("$opt_header \"Content-Type: %s\" ",
                                 $header{"content-type"});
    }
}

if($usesamehttpversion) {
    if(uc($http) eq "HTTP/1.1") {
        $httpver = "--http1.1 ";
        push @docs, manpage("--http1.1", "", "use HTTP protocol version 1.1");
    }
    elsif(uc($http) eq "HTTP/2") {
        $httpver = "--http2 ";
        push @docs, manpage("--http2", "", "use HTTP protocol version 2");
    }
    else {
        $error = "unsupported HTTP version $http";
        goto error;
    }
}
if($disableheadersnotseen) {
    if(!$header{'accept'}) {
        $disabledheaders .= "$opt_header Accept: ";
    }
    if(!$header{'user-agent'}) {
        $disabledheaders .= "$opt_header User-Agent: ";
    }
}

if($do_multipart) {
    if(!$header{lc("expect")}) {
        # no expect header, disable it for us too since curl -F defaults to
        # Expect: 100-continue
        $disabledheaders .= "$opt_header Expect: ";
    }
}

# go through the headers alphabetically just to make the order fixed
foreach my $h (sort keys %header) {
    if(lc($h) eq "host") {
        # We use Host: for the URL creation
    }
    elsif((lc($h) eq "authorization") &&
          ($header{'authorization'} =~ /^Basic (.*)/)) {
        my $decoded = decode_base64($1);
        $addedheaders .= sprintf("%s \"%s\" ", $opt_user, $decoded);
        push @docs, manpage("-u", $opt_user, "use this user and password for Basic auth");
    }
    elsif(lc($h) eq "expect") {
        # let curl do expect on its own
    }
    elsif(lc($h) eq "content-type" &&
          ($do_multipart || $set_contenttype)) {
        # skip this for multipart
    }
    elsif((lc($h) eq "accept") &&
          ($header{"accept"} eq "*/*")) {
        # ignore if set to */* as that's a curl default
    }
    elsif(lc($h) eq "content-length") {
        # we don't set custom size, just usebody
    }
    else {
        my $opt = sprintf("$opt_header \"%s: ", $h);
        if(lc($h) eq "user-agent") {
            $opt = "$opt_user_agent \"";
            push @docs, manpage("-A", $opt_user_agent, "use this custom User-Agent request header");
        }
        elsif(lc($h) eq "cookie") {
            $opt = "$opt_cookie \"";
            push @docs, manpage("-b", $opt_cookie, "pass on this custom Cookie: request header");
        }
        $addedheaders .= sprintf("%s%s\" ", $opt, $header{$h});
    }
}

if($path =~ / /) {
    $url = sprintf "\"https://%s%s\"", $header{'host'}, $path;
}
else {
    $url = sprintf "https://%s%s", $header{'host'}, $path;
}

if($disabledheaders || $addedheaders) {
    push @docs, manpage("-H", $opt_header, "add, replace or remove HTTP headers from the request");
}

if($useverbose) {
    $useverbose = "$opt_verbose ";
    push @docs, manpage("-v", $opt_verbose, "show verbose output");
}

printf "curl ${useverbose}${usemethod}${httpver}${disabledheaders}${addedheaders}${usebody}${multipart}${url}\n";

if($usenotes) {
    print "---\n";
    foreach my $n (@notes) {
        print "$n\n";
    }
}

if($usedocs) {
    print "---\n";
   foreach my $d (@docs) {
       print "$d\n";
   }
}
