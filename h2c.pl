#!/usr/bin/perl

sub usage {
    print "h2c.pl [-s] < file \n",
        " -h   Show short help\n";
        " -s   Use short command line options\n";
    exit;
}

my $usesamehttpversion = 1;
my $disableheadersnotseen = 1;
my $shellcompatible = 1; # may not been windows command prompt compat
my $uselongoptions = 1; # instead of short

while($ARGV[0]) {
    if(($ARGV[0] eq "-h") || ($ARGV[0] eq "--help")) {
        usage();
    }
    if($ARGV[0] eq "-s") {
        $uselongoptions = 0;
        shift @ARGV;
    }
}


my $state; # 0 is request-line, 1-headers, 2-body
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
    }
    elsif(2 == $state) {
        push @body, $l;
    }
}

if(!$header{lc('Host')}) {
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
}
else {
    $opt_data = "-d";
    $opt_request = "-X";
    $opt_head = "-I";
    $opt_header = "-H";
    $opt_user_agent = "-A";
    $opt_cookie = "-b";
}

my $httpver="";
my $disabledheaders="";
if(length(join("", @body))) {
    # TODO: escape the body
    my $esc = join("", @body);
    chomp $esc; # trim the final newline
    if($shellcompatible) {
        $esc =~ s/\n/ /g; # turn newlines into space!
        $esc =~ s/\"/\\"/g; # escape double quotes
    }
    $usebody= sprintf("--data-binary \"%s\" ", $esc);
}
if(uc($method) eq "HEAD") {
    $usemethod = "$opt_head ";
}
elsif(uc($method) eq "POST") {
    if(!$usebody) {
        $usebody= sprintf("$opt_data \"\" ");
    }
}
elsif(uc($method) eq "PUT") {
    if(!$usebody) {
        $usebody= sprintf("$opt_data \"\"");
    }
    $usebody .= "$opt_request PUT ";
}
elsif(uc($method) ne "GET") {
    $error = "unsupported HTTP method $method";
    goto error;
}


if($usesamehttpversion) {
    if(uc($http) eq "HTTP/1.1") {
        $httpver = "--http1.1 ";
    }
    elsif(uc($http) eq "HTTP/2") {
        $httpver = "--http2 ";
    }
    else {
        $error = "unsupported HTTP version $http";
        goto error;
    }
}
if($disableheadersnotseen) {
    if(!$header{lc('Accept')}) {
        $disabledheaders .= "$opt_header Accept: ";
    }
    if(!$header{lc('User-Agent')}) {
        $disabledheaders .= "$opt_header User-Agent: ";
    }
}
foreach my $h (keys %header) {
    if(lc($h) eq "host") {
        # We use Host: for the URL creation
    }
    elsif(lc($h) eq "content-length") {
        # we don't set custom size, just usebody
    }
    else {
        my $opt = sprintf("$opt_header \"%s: ", $h);
        if(lc($h) eq "user-agent") {
            $opt = "$opt_user_agent \"";
        }
        elsif(lc($h) eq "cookie") {
            $opt = "$opt_cookie \"";
        }
        $addedheaders .= sprintf("%s%s\" ", $opt, $header{$h});
    }
}

if($path =~ / /) {
    $url = sprintf "\"https://%s%s\"", $header{lc('Host')}, $path;
}
else {
    $url = sprintf "https://%s%s", $header{lc('Host')}, $path;
}

printf "curl ${usemethod}${httpver}${disabledheaders}${addedheaders}${usebody}${url}\n";
