#!/usr/bin/perl

my $state; # 0 is request-line, 1-headers, 2-body
while(<STDIN>) {
    my $l = $_;
    if(!$state) {
        chomp $_;
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
            $header{$1}=$2;
        }
        elsif(length($l)<2) {
            # body time
            $state++;
        }
    }
    elsif(2 == $state) {
        chomp $l;
        print STDERR "body!\n";
        push @body, $l;
    }
}

my $usesamehttpversion = 1;
my $disableheadersnotseen = 1;

if(!$header{'Host'}) {
    $error = "No Host: header makes it impossible to tell URL\n";
}

if($error) {
    print "Error: $error\n";
    exit;
}

my $httpver="";
my $disabledheaders="";
if(length(join("", @body))) {
    # TODO: escape the body
    $usebody= sprintf("--data-binary \"%s\" ", join("", @body));
}
if($method eq "HEAD") {
    $usemethod = "--head ";
}
elsif($method eq "POST") {
    if(!$usebody) {
        $usebody= sprintf("--data \"\" ");
    }
}
if($usesamehttpversion) {
    if($http eq "HTTP/1.1") {
        $httpver = "--http1.1 ";
    }
}
if($disableheadersnotseen) {
    if(!$header{'Accept'}) {
        $disabledheaders .= "--header Accept: ";
    }
    if(!$header{'User-Agent'}) {
        $disabledheaders .= "--header User-Agent: ";
    }
}
foreach my $h (keys %header) {
    if($h eq "Host") {
        # We use Host: for the URL creation
    }
    elsif($h eq "Content-Length") {
        # we don't set custom size, just usebody
    }
    else {
        my $opt = sprintf("--header \"%s: ", $h);
        if($h eq "User-Agent") {
            $opt = "--user-agent \"";
        }
        $addedheaders .= sprintf("%s%s\" ", $opt, $header{$h});
    }
}
printf "curl %s%s%s%s%shttps://%s%s\n",
    $usemethod,
    $httpver,
    $disabledheaders,
    $addedheaders,
    $usebody,
    $header{'Host'}, $path;
